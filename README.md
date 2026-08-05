# KS銀行 ミニバンク・デモ (KS-Bank mockup)

메인프레임 레거시(COBOL + Oracle)를 재현한 **인터넷뱅킹 데모**입니다.
DB는 **정상 타입 컬럼**으로 저장하되, 문자셋을 메인프레임 관례에 맞춰 이원화한 것이 핵심입니다:
**Oracle(COBOL 백엔드) = JA16SJIS(Shift-JIS) 문자셋 DB**, **PostgreSQL(Java 백엔드) = UTF-8**.
일본어 명의 등 텍스트는 `VARCHAR2`(Shift-JIS 바이트) / UTF-8 텍스트로, 키·금액은 `NUMBER`로 저장합니다.

> 📌 **2026-07-30 인코딩 마이그레이션 완료.** 이전에는 전 컬럼을 메인프레임 바이트(RAW)로
> 저장했습니다(후지쯔 JEF EBCDIC 텍스트 + COMP-3 팩10진 금액 + 존10진 EBCDIC 키 + 앱측 코덱).
> 이 RAW/코덱 설계는 **전부 제거**되었고, 위의 Shift-JIS(Oracle)/UTF-8(PostgreSQL) 정상 타입 구조로 대체되었습니다.

> **인수인계 문서입니다.** 처음 받는 분은 이 파일부터 읽고, 세부는 각 폴더의 README/문서를 참고하세요.
>
> 🎬 **처음 접속해서 시연만 하실 분은 [`DEMO.md`](./DEMO.md)** — 접속·로그인·시연 시나리오를 순서대로 정리해뒀습니다.
>
> 🔑 **담당자 인수인계는 [`ONBOARDING.md`](./ONBOARDING.md)** — 접속·실행·운영·개발 이어가기 + 받아야 할 것 체크리스트 + 암묵지(함정).

---

## 1. 전체 구조

```
브라우저 (frontend/)  ──/api/...──▶  CGI (nginx + fcgiwrap)
                                        │
                                   COBOL (GnuCOBOL + GixSQL EXEC SQL)
                                             │
                                             └────── Oracle
                                        (JA16SJIS DB · 정상 타입 컬럼:
                                         NUMBER / VARCHAR2 / CHAR)
```

- 프론트엔드는 SPA(바닐라 JS)이며 `/api/...` 상대경로로 백엔드를 호출합니다. 프론트는 UTF-8.
- 백엔드는 **ASIS(레거시) COBOL**이 정본. nginx가 프론트 정적파일과 `/api`를 **같은 오리진**으로 서빙합니다.
- COBOL은 정상 컬럼을 그대로 읽고 씁니다(호스트변수 직접 바인딩, VARCHAR2 등가비교는 `RTRIM(:hv)`). GixSQL/OCI 드라이버가 NLS_LANG과 무관하게 **클라이언트 문자셋을 UTF-8로 강제**(Instant Client basiclite에 문자셋 변환기가 없음)하므로, 일본어 컬럼은 앱에 **UTF-8**로 도착하고 HTTP 응답도 UTF-8입니다.
- 결과: **DB는 디스크에 Shift-JIS로 저장, 앱/HTTP는 UTF-8로 통신, 브라우저는 일본어 정상 표시.**

---

## 2. 디렉터리 구성 (최상위)

| 경로 | 내용 | 상태 |
|------|------|------|
| `frontend/` | SPA (index.html / app.js / styles.css). `/api/...` 호출 | 사용 중 |
| `backend-cobol/` | **ASIS 정본 백엔드** — COBOL 소스·카피북·SQL·Docker | 사용 중 (배포됨) |
| `db/` | app.js 인메모리 모델을 정규화한 UTF-8 Oracle 스키마 | **참조용** (ASIS와 별개) |
| `backend-java/` | Java 전환용 자리(빈 폴더) | 예정 (§7) |
| `claude readme/` | ASIS 백엔드 설계 프롬프트 원문 | 참고 문서 |

`backend-cobol/` 안 주요 폴더: `cobol/`(COBOL 소스), `cobol/copy/`(카피북 — 레코드/CGI/DB/절차), `sql/`, `docker/`(`Dockerfile.asis` + `Dockerfile.oracle-sjis` + `oracle-sjis/`), `cgi/`, `build/`.

> `db/`와 `backend-cobol/sql/`은 **서로 다른 스키마**입니다. 실제 구동 정본은 `backend-cobol/sql/`(Oracle JA16SJIS, 정상 타입), `db/`는 UTF-8 정규화 참조본으로 보존만 합니다.

---

## 3. 실행 방법 (Docker)

```bash
# 리포지토리 루트에서
docker compose -f backend-cobol/docker/compose.asis.yml up -d --build
# → http://localhost:8080/  (프론트 + API 동일 오리진)
```

- `oracle` (**JA16SJIS 커스텀 이미지**, :1521): `docker/Dockerfile.oracle-sjis`가 공식 Oracle Free 이미지를 받아 빌드 시점에 `dbca -characterSet JA16SJIS`로 DB를 재생성하고 스키마+시드(`sql/01_ddl.sql`·`02_seed.sql`)를 구워 넣습니다(재기동 시 SAVE STATE로 자동 오픈). `compose.asis.yml`의 `oracle` 서비스가 이 이미지를 빌드합니다.
- `asis-backend` (nginx + fcgiwrap + CGI, 8080→80): 프론트 `/`, API `/api/...`

### ⚠️ 사전 준비물 (필수 — 깃에 없음)

`backend-cobol/docker/vendor/`에 **재배포 불가 서드파티 3개**를 직접 내려받아 넣어야 빌드됩니다:

| 파일 | 입수처 |
|------|--------|
| `instantclient-basiclite-linux.x64.zip` | Oracle Instant Client (Linux x86-64) |
| `instantclient-sdk-linux.x64.zip` | 같은 페이지 SDK Package |
| `gixsql-1.0.20b.tar.gz` | GitHub `mridoni/gixsql` Releases (1.0.18+) |

자세한 입수·버전 대응은 **`backend-cobol/docker/vendor/README.md`** 참조.

> `sql/01_ddl.sql`·`02_seed.sql`은 JA16SJIS DB에 맞춘 **정상 타입(NUMBER/VARCHAR2/CHAR) + 일본어 리터럴**
> 정본입니다. 커스텀 Oracle 이미지 빌드 시점에 구워지므로 컨테이너 기동 즉시 스키마·시드가 반영됩니다.
> 조회 시 컬럼이 사람이 읽는 값(예: 山田太郎 / 523400)으로 그대로 보입니다(RAW/디코드 뷰 불필요).

---

## 4. 배포된 데모 서버 (라이브)

COBOL 백엔드가 사내 리눅스 서버(Ubuntu)에 빌드·구동 중입니다 (온라인·10단계 배치 E2E 검증 완료).

### 4.1 접속

> 🔒 **서버 IP·포트·SSH 계정·SSH 키·sudo 비밀번호는 공개 리포에 적지 않습니다.**
> 아래 값은 담당자(seoyeong 님, seoyeong.jeong@ks-infosys.com)에게 요청하세요.

- **망**: 사내 **Tailscale** 망 안에서만 접속됩니다 (먼저 Tailscale 로그인 필요).
- **SSH**: 키 기반 로그인. 담당자에게 ①서버 주소 ②SSH 계정 ③SSH 개인키(또는 본인 공개키 등록)를 받으세요.
  ```bash
  ssh -i <SSH키> <계정>@<서버주소>
  ```
- **웹/DB 포트** (Tailscale 망 내):
  - 프론트+API: `http://<서버주소>:8090/`
  - Oracle: `<서버주소>:1521` / 서비스 `FREEPDB1` / `minibank`(데모 비번, §8)
- DB 조회 시 컬럼은 정상 타입(NUMBER/VARCHAR2/CHAR)이고, DBeaver 등에서 일본어가 **읽는 값 그대로** 표시됩니다(JDBC 드라이버가 JA16SJIS→클라이언트 변환 처리). 별도 디코드 뷰·함수는 없습니다.

### 4.2 배치 실행 (10단계 야간배치)

컨테이너 안에서 `run_batch.sh`를 실행합니다. **exec 셸에는 entrypoint의 `ORA_*`가
상속되지 않으므로 주입 필수**입니다.

```bash
# 서버(SSH 접속 후). 로컬 Docker Desktop이면 'sudo' 빼고 동일.
sudo docker exec -w /app/build \
  -e ORA_CONN=oracle://oracle:1521/FREEPDB1 -e ORA_USER=minibank -e ORA_PASS=minibank \
  mb-asis-backend \
  sh -c 'mkdir -p data && sh run_batch.sh'
# => [batch] all 10 steps done.
```

- 산출물은 컨테이너 내 `/app/build/data/` (예: `MEISAI.RPT`, `NIPPO.RPT`, `ZANDAKA.RPT`,
  `TESURYO.RPT`, `KYUMIN.RPT`, `KOUZA.LST`, `TOKEI.RPT`). 10단계 상세는 `backend-cobol/README.md` §5.
- 5~10(帳票)은 읽기 전용. 3(YAKANBAT)은 당일거래가 있을 때만 이자를 가산(거래 0건이면 잔액 불변).
- 리포트 확인 예: `sudo docker exec mb-asis-backend cat /app/build/data/TOKEI.RPT`
- **Java 백엔드도 같은 帳票 7종을 파일로 냅니다** — `POST /api/batch/run` → `backend-java/data/`
  (`MEISAI.TXT` + 6종. 6종은 COBOL 서식 그대로).
- **COBOL ↔ Java 1:1 값 대조**: `sh tools/parity/compare.sh` → `PARITY OK`.
  고정 픽스처(`sql/90_parity_fixture.sql`)를 양쪽에 적용해 배치를 돌리고 帳票 7종을 `diff` 합니다.
  ⚠️ 온라인 이체로 대조 데이터를 만들면 `TORIHIKI_DT`(삽입 시각)가 양쪽에서 달라져 明細이 전부
  불일치합니다 — 반드시 픽스처를 쓰세요. 상세는 `backend-java/DESIGN.md` §8.

### 4.3 상태 확인 / 재기동

```bash
sudo docker ps                                   # 컨테이너 상태
sudo docker logs --tail 20 mb-asis-backend       # 백엔드 로그
sudo docker restart mb-asis-backend              # 백엔드만 재기동(데이터 보존)
```

### 4.4 소스 갱신 후 재배포 (백엔드 이미지 재빌드)

Oracle 컨테이너(라이브 데이터)는 건드리지 않고 **백엔드 이미지만** 재빌드/교체합니다.
서버 `~/minibank-demo`는 **git clone**이므로 코드 갱신은 `git pull`로 합니다(코드는 git, 데이터만 서버 볼륨).

```bash
# 1) 최신 소스 반영
cd ~/minibank-demo && git pull
#    ※ vendor 파일(깃에 없음)은 그대로 유지됨. 없으면 vendor/README.md 참고해 재배치.
# 2) 이미지 재빌드 (★ 빌드 컨텍스트는 반드시 절대경로 — sudo 아래 ~ 는 /root)
sudo docker build -f backend-cobol/docker/Dockerfile.asis -t mb-asis-backend:latest /home/<계정>/minibank-demo
# 3) 컨테이너 교체 (기존 네트워크/포트/환경 유지)
sudo docker rm -f mb-asis-backend
sudo docker run -d --name mb-asis-backend --network mbnet -p 8090:80 \
  -e ORA_USER=minibank -e ORA_PASS=minibank -e TZ=Asia/Tokyo \
  --restart unless-stopped mb-asis-backend:latest
```

### 4.5 데이터 초기화 (시드 상태로 리셋)

라이브 Oracle을 깨끗한 시드로 되돌립니다 (거래 삭제·잔액 원복). Oracle 컨테이너 내 sqlplus로 재적용:

```bash
sudo docker cp backend-cobol/sql/01_ddl.sql  oracle:/tmp/01_ddl.sql
sudo docker cp backend-cobol/sql/02_seed.sql oracle:/tmp/02_seed.sql
sudo docker exec -i oracle sqlplus -s /nolog @/tmp/01_ddl.sql  </dev/null   # 드롭/재생성
sudo docker exec -i oracle sqlplus -s /nolog @/tmp/02_seed.sql </dev/null   # 재적재
# 확인: TORIHIKI=0, KOUZA=8
```

---

## 5. 데모 / 테스트 계정

| 구분 | 점번 | 계좌번호 | PW | 비고 |
|------|------|----------|-----|------|
| 시연용 | 001 | 1000123 | `ks1234` | 山田太郎, 프로필·거래 있음(대표 계좌) |
| 테스트용 | 001 | 2000456 | `1111` | 별도 계좌 |

> 계좌번호는 **7자리 `KOUZA_NO`**(프론트 표시와 일치). DB에는 정상 `NUMBER` 컬럼으로 저장됩니다.

---

## 6. 더 깊은 문서

| 문서 | 내용 |
|------|------|
| `backend-cobol/README.md` | **백엔드 정본 문서** — API 계약, 데이터모델, 빌드/야간배치, 문자셋 현황(상단), 검증 체크리스트 |
| `backend-cobol/docker/vendor/README.md` | vendor 서드파티 입수 방법 |
| `db/README.md` | 참조용 UTF-8 스키마·시드·ER 개요 |
| `claude readme/ClaudeCode_Prompt_ASIS_COBOL_Backend.md` | ASIS 설계 지시서 원문 |

---

## 7. 알려진 한계 · 다음 작업

1. **문자셋 마이그레이션 완료** ✅ (2026-07-30). 이전의 전 컬럼 RAW/코덱 설계(JEF EBCDIC 텍스트,
   COMP-3 금액, 존10진 키 + 앱측 코덱)를 **전부 제거**하고, Oracle을 **JA16SJIS(Shift-JIS) 문자셋 DB**로
   재생성해 **정상 타입 컬럼**(NUMBER/VARCHAR2/CHAR)으로 전환했습니다. 삭제된 것: `cobol/JEFCONV.c`,
   `RAWUTF8.cbl`, `EBCDIG.cbl`, `jef/` 디렉터리 전체(JefServer/jef4j.jar 등), 코덱 카피북
   `WPACK/PPACK/WTXT/PTXT/WENCODE.cpy`, 그리고 **127.0.0.1:9099 JEF 상주 서비스**.
2. **앱↔DB 문자셋** — COBOL은 정상 컬럼을 직접 바인딩(VARCHAR2 등가비교는 `RTRIM(:hv)`). GixSQL/OCI
   드라이버가 클라이언트 문자셋을 UTF-8로 강제하므로 DB는 디스크에 Shift-JIS, 앱/HTTP는 UTF-8입니다.
3. **계좌번호 자릿수** — 프론트·DB 모두 7자리(`KOUZA_NO`)로 정합됨.
4. **DDL/시드 정본** ✅ — `sql/01_ddl.sql`·`02_seed.sql`은 JA16SJIS DB용 정상 타입 스키마 + 일본어 리터럴 시드.
   커스텀 Oracle 이미지(`docker/Dockerfile.oracle-sjis` + `oracle-sjis/`)가 빌드 시점에 구워 넣습니다.
5. **Java 전환 예정** — `backend-java/`는 온라인 9종 + 배치 이식 완료(PostgreSQL, UTF-8). 스키마는 전부
   정상 타입(integer/bigint/numeric/varchar/char/date), 일본어는 UTF-8 텍스트. (구 `codec` 패키지·jef4j
   의존성·디코드 뷰/함수·UTF-8 미러 컬럼은 제거됨.)

---

## 8. 기타

- DB 비밀번호(`compose.asis.yml`의 `oracle`/`minibank`)는 **데모 더미값**입니다. 실운영 시 반드시 교체·해시 저장.
- `.gitignore`로 vendor 대용량 다운로드·빌드 로그 산출물은 추적 제외됩니다.
