# ONBOARDING — 미니뱅크 프로젝트 인수인계

> 담당자 교체용 문서. 후임자가 이 문서 하나로 **접속 → 실행 → 운영 → 개발 이어가기**까지 할 수 있도록 정리했습니다.
> 시연만 할 사람은 [`DEMO.md`](./DEMO.md), 전체 구조는 [`README.md`](./README.md) 참고.

---

## 1. 프로젝트 개요 (먼저 이것만)

일본 은행 **인터넷뱅킹**을 흉내 낸 웹 데모. 로그인·잔액·이체·명세·대출/상환·공지·개설 기능.

**핵심 철학 (반드시 이해)**: 화면은 평범한 뱅킹 앱이고, DB는 **정상 타입 컬럼**으로 저장하되 문자셋을 메인프레임 관례에 맞춰 이원화한다 (사장님 지시: **Oracle = Shift-JIS, PostgreSQL = UTF-8**).
- **Oracle(COBOL)** = **JA16SJIS(Shift-JIS) 문자셋 DB**. 키·금액 = `NUMBER`, 일본어 텍스트 = `VARCHAR2`(디스크에 Shift-JIS 바이트), 코드·일자 = `CHAR`.
- **PostgreSQL(Java)** = **UTF-8**. 키·금액 = `integer/bigint/numeric`, 일본어 텍스트 = UTF-8 `varchar`.
- 앱/HTTP/프론트는 전부 **UTF-8**. (COBOL측은 GixSQL/OCI 드라이버가 클라이언트 문자셋을 UTF-8로 강제 → DB는 Shift-JIS 저장, 앱은 UTF-8 수신.)

> ⚠️ **2026-07-30 마이그레이션 완료.** 이전에는 전 컬럼을 메인프레임 바이트(RAW)로 저장하고(JEF EBCDIC 텍스트 + COMP-3 금액 + 존10진 키), 앱측 코덱으로 왕복했습니다. 그 RAW/코덱 설계는 **전부 제거**되었습니다. 지금은 위의 정상 타입 구조이니, DB 컬럼은 정상 값(山田太郎 / 523400 등)으로 그대로 보이는 게 정상입니다.

**두 개의 백엔드** (프론트는 공용):
- `backend-cobol/` — **정본**. GnuCOBOL + Oracle(JA16SJIS). 사내 서버에 **라이브 구동 중**.
- `backend-java/` — COBOL을 Spring Boot + PostgreSQL(UTF-8)로 이식(온라인 9종 + 배치 완료). 사내 서버에도 **라이브 구동 중**(`mbj-app`).

---

## 2. 인수인계 체크리스트 — 받아야 할 것 (★안전한 경로로★)

> ⚠️ 이 저장소는 **공개(public)**. 아래 비밀정보는 **문서/깃에 절대 넣지 말고**, 떠나는 담당자에게 **비밀번호 관리자·1:1 등 안전한 경로**로 받으세요.

- [ ] **GitHub 저장소 권한** — `Hoax0606/KS-Bank-mockup` collaborator 등록 (소유자 계정에 요청). ※ 리포 소유자가 떠나는 사람이 아니면 소유권/권한 이관도 함께 정리.
- [ ] **서버 접속 정보**: ①서버 주소(Tailscale IP) ②SSH 계정명 ③SSH 개인키 파일 ④**sudo 비밀번호**
- [ ] **Tailscale** 망 접속 권한 (사내 Tailscale에 후임자 계정 추가)
- [ ] (참고) DB 계정 `minibank / minibank` 는 **데모 더미값** — 소스에 있음, 비밀 아님.
- [ ] (참고) `vendor` 서드파티(Oracle Instant Client·GixSQL)는 깃에 없음 → `backend-cobol/docker/vendor/README.md` 보고 직접 다운로드.

> 이 4가지(서버주소·SSH계정·키·sudo비번)만 있으면 서버 운영을 전부 이어받을 수 있습니다.

---

## 3. 저장소 구조

| 경로 | 내용 |
|------|------|
| `frontend/` | 공용 SPA (바닐라 JS). `/api/...` 호출 |
| `backend-cobol/` | **정본 백엔드**: `cobol/`, `cobol/copy/`(카피북), `sql/`(JA16SJIS DDL·시드), `docker/`(`Dockerfile.asis` + `compose.asis.yml` + `oracle-sjis/setup/`), `build/` |
| `backend-java/` | Java 이식: `src/main/java/com/ksbank/minibank/`(web/service/repository/domain/batch), `resources/db/`(schema·seed, UTF-8), `resources/static/`(프론트), `DESIGN.md` |
| `db/` | 참조용 UTF-8 스키마(ASIS와 별개, 보존만) |
| `README.md` / `DEMO.md` / `backend-cobol/README.md` / `backend-java/DESIGN.md` | 문서 |

---

## 4. 로컬에서 돌려보기

**둘 다 리포지토리 루트에서 동일한 방식(`docker compose -f <경로>`)으로 실행합니다.**
```bash
# Java판 (가장 간단 · 준비물 없음) → http://localhost:8081/   (프로젝트명: minibank-java)
docker compose -f backend-java/compose.java.yml up -d --build

# COBOL판 (정본) → http://localhost:8092/   (프로젝트명: minibank-cobol)
#   ※ 최초 기동은 Oracle XE 가 Shift-JIS DB를 새로 만들어 10~20분 걸림 (docker logs -f oracle_sjis)
#   ※ 먼저 backend-cobol/docker/vendor/README.md 보고 vendor 3개 다운로드
docker compose -f backend-cobol/docker/compose.asis.yml up -d --build

# 종료: 위 명령의 up -d --build 를 down 으로 바꾸면 됨 (-v 붙이면 DB 볼륨까지 삭제)
```
> 빌드 컨텍스트 차이(COBOL=리포 루트: 프론트까지 번들 / Java=자족형)로 compose 위치는 다르지만,
> **실행은 위처럼 루트에서 `-f 경로`로 동일**합니다. Docker Desktop엔 `minibank-cobol` / `minibank-java`로 표시됩니다.

로그인 계정은 `DEMO.md` §2 (기본: `001 / 1000123 / ks1234`).

### 접속 주소 한눈에 (테스트용)

| 대상 | 화면(브라우저) | API | DB(DBeaver) |
|------|----------------|-----|-------------|
| **Java** (로컬) | `http://localhost:8081/` | `localhost:8081/api/...` | PostgreSQL `localhost:5434` / `minibank` (minibank/minibank) |
| **COBOL** (로컬) | `http://localhost:8092/` | `localhost:8092/api/...` | Oracle `localhost:1522/XEPDB1` (minibank/minibank) |
| **COBOL** (라이브 서버) | `http://<서버주소>:8092/` | `<서버주소>:8092/api/...` | Oracle `<서버주소>:1522/XEPDB1` (minibank/minibank) |
| **Java** (라이브 서버) | `http://<서버주소>:8081/` | `<서버주소>:8081/api/...` | PostgreSQL `<서버주소>:5434` / `minibank` |

- **포트**(로컬·서버 동일, `SERVER-SETUP.md` §3 기준): **8092**=COBOL 화면 · **8081**=Java 화면 · **1522**=Oracle(XEPDB1) · **5434**=PostgreSQL
- ⚠️ **1521 / 5433 은 우리 것이 아닙니다** — 서버의 다른 프로젝트용 `oracle`(FREEPDB1) / `postgres`(bank_postgres). 헷갈리면 빈 DB를 보게 됩니다.
- 두 백엔드는 **서로 다른 DB**를 봄(COBOL→Oracle JA16SJIS, Java→PostgreSQL UTF-8) → 한쪽에서 이체해도 다른 쪽엔 반영 안 됨(정상)
- 화면·기능·로그인 계정은 두 백엔드 동일. DB 컬럼은 **정상 타입**이라 일본어가 읽는 값 그대로 표시됨(디코드 뷰 불필요, §5)

---

## 5. 라이브 서버 운영 (COBOL, 사내 서버)

절차는 `README.md` §4에 명령까지 정리돼 있음. 요약:
- **코드 관리**: 서버 `~/minibank-demo`는 **GitHub의 git clone**(코드는 git, 데이터만 서버 고유). 갱신 = `cd ~/minibank-demo && git pull` → 재빌드(§4.4). ※vendor 파일은 깃에 없으니 유지/재배치 주의. (구 scp 사본 백업은 `~/minibank-demo.bak`, 검증 후 삭제 가능)
- **접속**: Tailscale 켜고 `ssh -i <키> <계정>@<서버주소>`
- **웹**: COBOL `http://<서버주소>:8092/` · Java `http://<서버주소>:8081/`
- **DB**: Oracle `<서버주소>:1522/XEPDB1` · PostgreSQL `<서버주소>:5434/minibank
- **배치 실행**: `sudo docker exec ... mb-cobol-sjis sh -c 'sh run_batch.sh'` (env 주입 필요 — README §4.2)
- **재배포**(소스 변경 시): 백엔드 이미지만 재빌드(§4.4). ★**oracle 컨테이너는 절대 건드리지 말 것**(라이브 데이터).
- **데이터 초기화**: `sql/01_ddl`+`02_seed` 재적용(§4.5)

### 컨테이너 / 프로젝트 이름 (docker 명령용)

`docker exec` / `docker logs` / `docker restart` 등에 쓰는 실제 이름:

| 환경 | compose 프로젝트 | 컨테이너 (앱 / DB) | 포트 | 비고 |
|------|------------------|--------------------|------|------|
| 로컬 COBOL | `minibank-cobol` | `mb-cobol-sjis` / `oracle_sjis` | 8092 / 1522 | compose 기본 네트워크 |
| 로컬 Java | `minibank-java` | `mbj-app` / `mbj-postgres` | 8081 / 5434 | |
| **서버(라이브) Java** | `minibank-java` (compose) | `mbj-app` / `mbj-postgres` | 8081 / 5434 | |
| **서버(라이브) COBOL** | (compose 아닌 `docker run`) | `mb-cobol-sjis` / `oracle_sjis` | 8092 / 1522 | 기본 bridge, `--add-host oracle:<IP>` |

- ✅ **컨테이너명·포트가 로컬/서버 동일**하게 정렬됐습니다(`SERVER-SETUP.md` §3 기준) — `oracle_sjis` / `mb-cobol-sjis`,
  8092 / 1522 / 5434. 예전처럼 환경마다 이름을 바꿔 쓸 필요가 없습니다.
- ⚠️ 단 **서버는 `sudo` 필요**하고, COBOL→Oracle 연결은 서버에서 **컨테이너 IP 직결**입니다(README §4.4).
- 로컬은 `docker`가 그냥 되지만, **서버는 `sudo docker`** 로 실행.
- Java도 서버에 배포돼 있음(`mbj-app` 8081 / `mbj-postgres` 5434).

### DB 직접 조회 (DBeaver 등)

> 컬럼이 **정상 타입**(NUMBER/VARCHAR2/CHAR · integer/varchar/bigint)이라 일본어가 **읽는 값 그대로** 보입니다. 디코드 뷰·함수 없음.

| 대상 | Type | Host | Port | DB/Service | 계정 | 문자셋 |
|------|------|------|------|-----------|------|--------|
| COBOL판 (로컬) | Oracle | `localhost` | **`1522`** | `XEPDB1` | `minibank` / `minibank` | JA16SJISTILDE |
| COBOL판 (라이브 서버) | Oracle | `<서버주소>` | **`1522`** | `XEPDB1` | `minibank` / `minibank` | JA16SJISTILDE |
| Java판 (로컬/서버) | PostgreSQL | `localhost` 또는 `<서버주소>` | **`5434`** | `minibank` | `minibank` / `minibank` | UTF-8 |

- **Oracle(Shift-JIS)**: 컬럼은 NUMBER/VARCHAR2/CHAR. 일본어는 RAW hex가 아니라 읽는 텍스트로 표시(JDBC 드라이버가 JA16SJISTILDE→클라이언트 변환). Service Name 에 **`XEPDB1`** (SID 아님).
  ⚠️ **CLI(sqlplus)로 볼 때는 `NLS_LANG=AMERICAN_AMERICA.AL32UTF8` 주입 필수** — 없으면 일본어가 `????` 로 보입니다(데이터는 정상). DBeaver(JDBC)는 불필요.
- **PostgreSQL(UTF-8)**: 컬럼은 integer/varchar/bigint, 일본어는 평문 UTF-8. ⚠️ 포트 **5434**. 옛 DBeaver 연결이 아직 `bytea`로 보이면 캐시된 메타데이터이니 **재접속 + 새로고침**.
  ```sql
  SELECT * FROM kouza ORDER BY kouza_no;   -- 사람이 읽는 값 그대로 (양쪽 DB 동일)
  ```

---

## 6. 개발 이어가기

- **COBOL 정본**: 온라인 CGI 9 + 배치 10 (`backend-cobol/README.md` 상단 "현재 구현 현황" + §5 배치).
- **Java 이식 현황**: 온라인 **9/9 완료** + 배치 완료(`/api/batch/run` — posting + **明細(D/T)** + 帳票 6종,
  파일 7종을 `backend-java/data/`에 출력). 상세·로드맵은 `backend-java/DESIGN.md`.
- **배치 파리티 검증**: `sh tools/parity/compare.sh` → `PARITY OK`(帳票 7종 `diff` 무차이).
  ⚠️ 대조 데이터는 **반드시 픽스처**(`90_parity_fixture.sql`)로 만들 것 — 온라인 이체로 만들면
  `TORIHIKI_DT`(삽입 시각)가 양쪽에서 달라져 明細이 전부 불일치한다. 배치는 멱등이 아니므로
  대조 전에 매번 픽스처를 재적용한다.
- **Java 남은 것(운영화)**: 서버 배포(`compose.java.yml`로), 인증/PW 해시, 프로필 컬럼 확장.
- **개발 패턴(Java)**: `web(REST) → service(@Transactional) → repository(JdbcTemplate, 정상 타입 컬럼 직접 바인딩)`. 컬럼이 모두 정상 타입(integer/bigint/numeric/varchar/char/date, 일본어=UTF-8)이라 별도 코덱 없이 값을 그대로 다룹니다. (구 `codec` 패키지는 제거됨.)

---

## 7. ★꼭 알아야 할 함정 (암묵지 — 이게 제일 중요)★

이 프로젝트를 처음 만지는 사람이 반드시 밟는 지뢰들. 몰라서 삽질하지 않도록:

**전반**
- **문자셋 이원화**: Oracle=JA16SJIS(Shift-JIS), PostgreSQL=UTF-8. 컬럼은 양쪽 다 정상 타입이라 DBeaver에서 일본어가 읽는 값 그대로 보임(디코드 뷰·함수 없음). 예전 RAW/JEF/COMP-3/존10진 + `V_*`/`FN_*` 구조는 2026-07-30에 전부 제거됨 — 옛 스크립트/뷰를 찾지 말 것.
- COBOL측은 GixSQL/OCI 드라이버가 클라이언트 문자셋을 UTF-8로 강제(Instant Client basiclite에 변환기 없음). 그래서 NLS_LANG과 무관하게 DB는 Shift-JIS 저장, 앱/HTTP는 UTF-8. VARCHAR2 등가비교는 `RTRIM(:hv)`로.

**COBOL 빌드/배포**
- `gixpp`(EXEC SQL 프리컴파일) 함정: SORT 못 다룸 → `SORTDAT/SORTRPT` 별 프로세스. 코덱 카피북은 **한 줄에 한 문장**(마침표 72칸 넘으면 무시됨). COPY는 `expand_copy.sh`로 평탄화 후 넘김. 긴 EXEC SQL 줄은 72칸 초과 시 호스트변수명 잘림.
- vendor(Oracle Instant Client·GixSQL)는 재배포 불가라 깃에 없음 → 직접 다운로드(`vendor/README.md`).
- **sudo 함정**: 서버에서 `sudo docker build` 시 `~`가 `/root`로 잡힘 → 빌드 컨텍스트는 **절대경로**로.
- **Oracle은 빌드하지 않음**: 서버와 같은 `limslee/oracle-database-xe:21.3.0`(PDB `XEPDB1`)을 그대로 쓰고, compose가 `ORACLE_CHARACTERSET: JA16SJISTILDE`를 **명시**함(미지정 시 AL32UTF8 로 만들어져 버림 — 함정). 스키마·시드는 `/opt/oracle/scripts/setup` 훅으로 최초 기동 시 1회 자동 적재(`00_mkuser.sql`→`01_ddl.sql`→`02_seed.sql`). 스키마를 바꾸면 **`docker compose down -v` 후 재기동**해야 다시 적재됨(이미지 재빌드는 불필요).

**Java**
- **DB 포트 혼동이 최대 함정**: 우리 것은 **1522/XEPDB1** 과 **5434/minibank**. 서버의 **1521/FREEPDB1**·**5433/bank_postgres** 는 다른 프로젝트이고, 호스트 네이티브 PG는 5432. DBeaver 연결 이름에 환경을 적어두면(예: `로컬-COBOL-Oracle`) 실수를 막을 수 있습니다.
- **charset 강제**: `application.yml`이 서블릿 인코딩을 UTF-8로 강제. 컬럼은 전부 정상 타입이라 예전 codec/jef4j 관련 함정(fat jar에서 커스텀 charset SPI 미탐지 등)은 더 이상 없음(해당 코드 삭제됨).

---

## 8. 문서 인덱스

- `README.md` — 전체 구조·실행·서버 운영(§4에 배치/재배포/초기화 명령)
- `DEMO.md` — 처음 접속해 시연하는 법
- `backend-cobol/README.md` — COBOL 정본(문자셋 현황·API 계약·배치 10스텝·검증)
- `backend-java/DESIGN.md` — Java 이식 설계·로드맵·함정 체크리스트
- `backend-cobol/docker/vendor/README.md` — vendor 다운로드

---

## 8.5 현재 라이브 배포 현황 (2026-07-31)

**두 스택 모두 마이그레이션 서버에 배포·가동 중.** 서버 주소·SSH·비밀번호는 공개 리포에 넣지 않음 → `minibank-handover/HANDOVER-CONFIDENTIAL.md`(기밀 폴더)의 **배포 런북** 참조.

| 스택 | 포트 | DB | 컨테이너 |
|---|---|---|---|
| **COBOL (Shift-JIS)** | `:8092` (UI+API) | 공유 오라클 `oracle_sjis`(XEPDB1)에 `minibank` 스키마 적재 | `mb-cobol-sjis` (이미지 `minibank-cobol-sjis:latest`) |
| **Java (UTF-8)** | `:8081`(API) / `:5434`(PG) | 신규 PostgreSQL(UTF-8) | `mbj-app` / `mbj-postgres` |

- **오라클은 새로 올리지 않음**: 서버에 이미 있던 공유 Shift-JIS 오라클(`oracle_sjis`, charset `JA16SJISTILDE`, PDB `XEPDB1`)에 `minibank` 유저+스키마+시드만 적재(18GB 이미지 배포 회피). `山田太郎`=`8e52…` Shift-JIS 저장 확인.
- **⚠️ 컨테이너 IP 주의**: COBOL 백엔드는 `ORA_CONN=oracle://<oracle_sjis 컨테이너IP>:1521/XEPDB1`로 **직접 연결**(호스트 포워딩 1522 경유는 Oracle 리스너 리다이렉트로 hang). `oracle_sjis` 재시작으로 IP가 바뀌면 `mb-cobol-sjis`를 새 IP로 재기동 필요. IP 확인: `sudo docker inspect oracle_sjis --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'`.
- **⚠️ 공유 서버**: 동료 컨테이너(`oracle_sjis`=limslee, `db2`, `tk4-hercules`)는 불가침. 디스크·RAM 여유가 적으니 무거운 이미지 배포 지양.

---

## 9. 인수인계 마무리

- [ ] 후임자가 위 §2 4가지 받고 **서버 SSH 접속 성공** 확인
- [ ] 후임자가 **로컬에서 Java판 기동**(`compose.java.yml`) 성공 확인
- [ ] 후임자가 **라이브 서버 배치 1회 실행** 성공 확인
- [ ] 인수인계 기간(예: 2주) 동안 질문 받을 **연락처 공유** (떠나는 담당자)

> 문의(전환 기간): (떠나는 담당자 연락처를 여기 대신 1:1로 전달)
