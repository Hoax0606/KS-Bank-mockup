# ONBOARDING — 미니뱅크 프로젝트 인수인계

> 담당자 교체용 문서. 후임자가 이 문서 하나로 **접속 → 실행 → 운영 → 개발 이어가기**까지 할 수 있도록 정리했습니다.
> 시연만 할 사람은 [`DEMO.md`](./DEMO.md), 전체 구조는 [`README.md`](./README.md) 참고.

---

## 1. 프로젝트 개요 (먼저 이것만)

일본 은행 **인터넷뱅킹**을 흉내 낸 웹 데모. 로그인·잔액·이체·명세·대출/상환·공지·개설 기능.

**핵심 철학 (반드시 이해)**: 화면은 평범한 뱅킹 앱이지만, DB에는 **메인프레임 레거시 바이트 원본** 그대로 저장한다.
- 텍스트(일본어 명의 등) = 후지쯔 **JEF EBCDIC**
- 금액 = **COMP-3(팩10진)**
- 키(계좌번호 등) = **존10진 EBCDIC**
- 저장은 RAW 바이트, 화면/조회 시 디코드. **이게 프로젝트의 존재 이유다. "이상해 보인다"고 일반 타입으로 바꾸면 안 됨.**

**두 개의 백엔드** (프론트는 공용):
- `backend-cobol/` — **정본**. GnuCOBOL + Oracle. 사내 서버에 **라이브 구동 중**.
- `backend-java/` — COBOL을 Spring Boot + PostgreSQL로 이식(온라인 9종 + 배치 완료). **아직 서버 배포 안 함(로컬만)**.

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
| `backend-cobol/` | **정본 백엔드**: `cobol/`(+`JEFCONV.c`), `cobol/copy/`(코덱 카피북), `jef/`(jef4j), `sql/`, `docker/`, `build/` |
| `backend-java/` | Java 이식: `src/main/java/com/ksbank/minibank/`(web/service/repository/codec/domain/batch), `resources/db/`(schema·seed), `resources/static/`(프론트), `DESIGN.md` |
| `db/` | 참조용 UTF-8 스키마(ASIS와 별개, 보존만) |
| `README.md` / `DEMO.md` / `backend-cobol/README.md` / `backend-java/DESIGN.md` | 문서 |

---

## 4. 로컬에서 돌려보기

**둘 다 리포지토리 루트에서 동일한 방식(`docker compose -f <경로>`)으로 실행합니다.**
```bash
# Java판 (가장 간단 · 준비물 없음) → http://localhost:8081/   (프로젝트명: minibank-java)
docker compose -f backend-java/compose.java.yml up -d --build

# COBOL판 (정본) → http://localhost:8080/   (프로젝트명: minibank-cobol)
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
| **Java** (로컬) | `http://localhost:8081/` | `localhost:8081/api/...` | PostgreSQL `localhost:5433` / `minibank` (minibank/minibank) |
| **COBOL** (로컬) | `http://localhost:8080/` | `localhost:8080/api/...` | Oracle `localhost:1521/FREEPDB1` (minibank/minibank) |
| **COBOL** (라이브 서버) | `http://<서버주소>:8090/` | `<서버주소>:8090/api/...` | Oracle `<서버주소>:1521/FREEPDB1` (minibank/minibank) |

- **포트 분리**: 8080=COBOL 화면 · 8081=Java 화면 · 1521=Oracle · 5433=PostgreSQL (서로 안 겹침, 동시에 켜도 됨)
- 두 백엔드는 **서로 다른 DB**를 봄(COBOL→Oracle, Java→PostgreSQL) → 한쪽에서 이체해도 다른 쪽엔 반영 안 됨(정상)
- 화면·기능·로그인 계정은 두 백엔드 동일. DB는 원본=RAW, 조회는 `V_*` 뷰(§5)

---

## 5. 라이브 서버 운영 (COBOL, 사내 서버)

절차는 `README.md` §4에 명령까지 정리돼 있음. 요약:
- **코드 관리**: 서버 `~/minibank-demo`는 **GitHub의 git clone**(코드는 git, 데이터만 서버 고유). 갱신 = `cd ~/minibank-demo && git pull` → 재빌드(§4.4). ※vendor 파일은 깃에 없으니 유지/재배치 주의. (구 scp 사본 백업은 `~/minibank-demo.bak`, 검증 후 삭제 가능)
- **접속**: Tailscale 켜고 `ssh -i <키> <계정>@<서버주소>`
- **웹**: `http://<서버주소>:8090/` , **DB**: `<서버주소>:1521/FREEPDB1`
- **배치 실행**: `sudo docker exec ... mb-asis-backend sh -c 'sh run_batch.sh'` (env 주입 필요 — README §4.2)
- **재배포**(소스 변경 시): 백엔드 이미지만 재빌드(§4.4). ★**oracle 컨테이너는 절대 건드리지 말 것**(라이브 데이터).
- **데이터 초기화**: `sql/01_ddl`+`02_seed` 재적용(§4.5)

### DB 직접 조회 (DBeaver 등)

> 원본 테이블은 **RAW 바이트(bytea/RAW)** 라 사람이 못 읽습니다. 사람이 읽으려면 **디코드 뷰 `V_*`** 를 보세요.

| 대상 | Type | Host | Port | DB/Service | 계정 |
|------|------|------|------|-----------|------|
| COBOL판 (라이브 서버) | Oracle | `<서버주소>` | `1521` | `FREEPDB1` | `minibank` / `minibank` |
| Java판 (로컬 compose) | PostgreSQL | `localhost` | **`5433`** ⚠️ | `minibank` | `minibank` / `minibank` |

- ⚠️ Java판 포트는 **5433**. 호스트에 native PostgreSQL(5432)이 있으면 겹치므로 compose는 5433으로 공개.
- 볼 것: 원본 테이블 `KOUZA`/`TORIHIKI`(RAW) ↔ 디코드 뷰 `V_KOUZA`/`V_TORIHIKI`/`V_LOAN`/`V_REPAY`/`V_NOTICE`.
  ```sql
  SELECT * FROM v_kouza ORDER BY kouza_no;        -- 사람이 읽는 값
  SELECT encode(meigi_kanji,'hex') FROM kouza;    -- (PG) 원본 RAW 바이트 확인
  ```
- 디코드 함수: `FN_UNZONE`(키)·`FN_UNPACK`(금액)·`FN_EBC`(단바이트 EBCDIC, PG는 미보강). 일본어(JEF)는 DB만으론 디코드 불가 → `V_KOUZA` 명의는 UTF-8 미러 사용.

---

## 6. 개발 이어가기

- **COBOL 정본**: 온라인 CGI 9 + 배치 10 (`backend-cobol/README.md` 상단 "현재 구현 현황" + §5 배치).
- **Java 이식 현황**: 온라인 **9/9 완료** + 배치 완료(`/api/batch/run`). 기능 파리티 달성. 상세·로드맵은 `backend-java/DESIGN.md`.
- **Java 남은 것(운영화)**: 서버 배포(`compose.java.yml`로), 인증/PW 해시, 프로필 컬럼 확장, PG `fn_ebc`(단바이트 EBCDIC) 디코드 뷰 보강.
- **개발 패턴(Java)**: `web(REST) → service(codec 인코/디코 + @Transactional) → repository(JdbcTemplate, bytea는 명시적 setBytes/getBytes, null은 setNull(Types.BINARY))`. 인코드=`codec/Enc`, 디코드=`codec/Fields`.

---

## 7. ★꼭 알아야 할 함정 (암묵지 — 이게 제일 중요)★

이 프로젝트를 처음 만지는 사람이 반드시 밟는 지뢰들. 몰라서 삽질하지 않도록:

**전반**
- **RAW 철학**: DB 값이 사람이 못 읽는 바이트인 건 정상(설계). DBeaver로 볼 땐 디코드 뷰 `V_KOUZA`/`V_TORIHIKI`/`V_LOAN`/`V_REPAY`/`V_NOTICE` 사용. 함수 `FN_UNZONE`(키)·`FN_UNPACK`(금액)·`FN_EBC`(단바이트 EBCDIC).
- 일본어(JEF)는 **DB만으로 디코드 불가** → `V_KOUZA` 명의는 `KOUZA_EXT.KANJI_UTF8` 미러를 씀.

**COBOL 빌드/배포**
- `gixpp`(EXEC SQL 프리컴파일) 함정: SORT 못 다룸 → `SORTDAT/SORTRPT` 별 프로세스. 코덱 카피북은 **한 줄에 한 문장**(마침표 72칸 넘으면 무시됨). COPY는 `expand_copy.sh`로 평탄화 후 넘김. 긴 EXEC SQL 줄은 72칸 초과 시 호스트변수명 잘림.
- vendor(Oracle Instant Client·GixSQL)는 재배포 불가라 깃에 없음 → 직접 다운로드(`vendor/README.md`).
- **sudo 함정**: 서버에서 `sudo docker build` 시 `~`가 `/root`로 잡힘 → 빌드 컨텍스트는 **절대경로**로.
- **DDL/시드는 라이브 DB에서 재생성한 것**: 라이브 Oracle이 전 컬럼 RAW로 마이그레이션된 상태이고, `sql/01_ddl.sql`·`02_seed.sql`은 거기서 `DBMS_METADATA`로 추출한 정본. **스키마 바꾸면 라이브 DB → 재추출로 소스 갱신**(생성 스크립트는 안 남아있음).

**Java**
- **Spring Boot fat jar에서 커스텀 charset(jef4j)이 SPI로 안 잡힘** → `Charset.forName("x-Fujitsu-JEF-EBCDIC")` 실패. `JefCodec`이 `Jef4jCharsetProvider`를 **직접 인스턴스화**해 우회함(이미 적용). 단위테스트는 통과하고 **jar 실행에서만 터지는** 부류라 주의.
- **로컬 PostgreSQL(5432) 충돌**: 호스트에 네이티브 PG가 있으면 겹침 → `compose.java.yml`은 PG를 **5433**으로 공개(앱 8081). COBOL 로컬(8080/1521)과도 분리.

---

## 8. 문서 인덱스

- `README.md` — 전체 구조·실행·서버 운영(§4에 배치/재배포/초기화 명령)
- `DEMO.md` — 처음 접속해 시연하는 법
- `backend-cobol/README.md` — COBOL 정본(인코딩 현황·API 계약·배치 10스텝·검증)
- `backend-java/DESIGN.md` — Java 이식 설계·로드맵·함정 체크리스트
- `backend-cobol/docker/vendor/README.md` — vendor 다운로드

---

## 9. 인수인계 마무리

- [ ] 후임자가 위 §2 4가지 받고 **서버 SSH 접속 성공** 확인
- [ ] 후임자가 **로컬에서 Java판 기동**(`compose.java.yml`) 성공 확인
- [ ] 후임자가 **라이브 서버 배치 1회 실행** 성공 확인
- [ ] 인수인계 기간(예: 2주) 동안 질문 받을 **연락처 공유** (떠나는 담당자)

> 문의(전환 기간): (떠나는 담당자 연락처를 여기 대신 1:1로 전달)
