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

**같은 프론트엔드**를 두 백엔드가 각각 서빙합니다. 두 스택은 **DB를 공유하지 않고** 완전히 독립입니다.

```
                프론트엔드 SPA (index.html / app.js / styles.css)
                   ↑ 두 벌이 완전히 동일 — /api/... 상대경로 호출 ↑
   ┌──────────────────────────────┐   ┌──────────────────────────────┐
   │  :8092  ASIS (현행·정본)      │   │  :8081  TOBE (이식본)        │
   │  nginx + fcgiwrap (CGI)      │   │  Spring Boot (내장 Tomcat)   │
   │        ↓                     │   │        ↓                     │
   │  COBOL (GnuCOBOL + GixSQL)   │   │  Java 21 (JdbcTemplate)      │
   │        ↓                     │   │        ↓                     │
   │  Oracle XE  XEPDB1  :1522    │   │  PostgreSQL 16      :5434    │
   │  JA16SJISTILDE (Shift-JIS)   │   │  UTF-8                       │
   │  컨테이너 oracle_sjis         │   │  컨테이너 mbj-postgres        │
   └──────────────────────────────┘   └──────────────────────────────┘
     컨테이너 mb-cobol-sjis              컨테이너 mbj-app
```

- 프론트엔드는 SPA(바닐라 JS)이며 `/api/...` **상대경로**로 호출하므로, 어느 오리진에 올려도 그대로 동작합니다.
  즉 **화면은 양쪽이 동일하고, 다른 것은 백엔드와 DB뿐**입니다.
- 백엔드는 **ASIS(레거시) COBOL**이 정본. nginx가 프론트 정적파일과 `/api`를 **같은 오리진**으로 서빙합니다.
- **마이그레이션 목표** = 같은 입력을 넣었을 때 두 DB에 **같은 값**이 들어가는 것.
  그 증명이 `sh tools/parity/compare.sh` → `PARITY OK` 입니다 (§4.2).
- COBOL은 정상 컬럼을 그대로 읽고 씁니다(호스트변수 직접 바인딩, VARCHAR2 등가비교는 `RTRIM(:hv)`).
- **(2026-07-30 시점, 지금은 아래로 대체)** 당시엔 GixSQL/OCI 드라이버가 NLS_LANG과 무관하게
  클라이언트 문자셋을 UTF-8로 강제(Instant Client Basic Lite에 문자셋 변환기가 없음)했어서,
  일본어 컬럼이 앱에 UTF-8로 도착하고 HTTP 응답도 UTF-8이었습니다.
- **📌 2026-08 갱신 — 배치/온라인 앱 레벨도 Shift-JIS로 재전환.** Instant Client를 Basic(비-Lite)으로
  바꿔 `NLS_LANG=JAPANESE_JAPAN.JA16SJISTILDE`가 실제로 적용되게 했습니다. 지금은 **DB·배치파일·
  온라인 HTTP 응답 전부 Shift-JIS**입니다(단, 회원가입/공지 등록처럼 브라우저가 새로 보내는 일본어
  텍스트는 `UTF2SJIS.c`로 UTF-8→Shift-JIS 변환 후 저장 — 브라우저의 `encodeURIComponent`가 항상
  UTF-8만 만들기 때문). 상세는 `backend-cobol/README.md`의 "③ 2026-08 Shift-JIS 앱/파일 레벨
  재전환" 참조. **`backend-java`(TOBE)는 이 변경과 무관하게 계속 UTF-8입니다.**

---

## 2. 디렉터리 구성 (최상위)

| 경로 | 내용 | 상태 |
|------|------|------|
| `frontend/` | SPA (index.html / app.js / styles.css). `/api/...` 호출 | 사용 중 |
| `backend-cobol/` | **ASIS 정본 백엔드** — COBOL 소스·카피북·SQL·Docker | 사용 중 (배포됨) |
| `db/` | app.js 인메모리 모델을 정규화한 UTF-8 Oracle 스키마 | **참조용** (ASIS와 별개) |
| `backend-java/` | **Java 이식본** — Spring Boot + PostgreSQL(UTF-8). 온라인 9종 + 야간배치 | 사용 중 |
| `claude readme/` | ASIS 백엔드 설계 프롬프트 원문 | 참고 문서 |

`backend-cobol/` 안 주요 폴더: `cobol/`(COBOL 소스), `cobol/copy/`(카피북 — 레코드/CGI/DB/절차), `sql/`, `docker/`(`Dockerfile.asis` + `compose.asis.yml` + `oracle-sjis/setup/`), `cgi/`, `build/`.

> `db/`와 `backend-cobol/sql/`은 **서로 다른 스키마**입니다. 실제 구동 정본은 `backend-cobol/sql/`(Oracle JA16SJIS, 정상 타입), `db/`는 UTF-8 정규화 참조본으로 보존만 합니다.

---

## 3. 실행 방법 (Docker)

> 📌 **컨테이너명·포트·PDB명·문자셋은 `SERVER-SETUP.md`(기밀 폴더) §3-1/§3-2 의 서버 구성과 동일하게
> 맞춰져 있습니다.** clone 후 `docker compose up` 하면 로컬에 서버와 같은 구성이 뜨므로, 서버 운영
> 절차서를 로컬에도 그대로 쓸 수 있습니다.

```bash
# 리포지토리 루트에서
docker compose -f backend-cobol/docker/compose.asis.yml up -d --build   # COBOL 스택
docker compose -f backend-java/compose.java.yml       up -d --build   # Java 스택
# → COBOL: http://localhost:8092/   (프론트 + API 동일 오리진)
# → Java : http://localhost:8081/   (프론트 + API 동일 오리진)
```

| 서비스 | 컨테이너 | 포트(host→cont) | 연결 DB |
|---|---|---|---|
| COBOL 백엔드 (Shift-JIS) | `mb-cobol-sjis` | `8092→80` (화면+API) | `oracle_sjis` **XEPDB1**, `minibank/minibank` |
| Oracle XE 21c (Shift-JIS) | `oracle_sjis` | `1522→1521` | PDB **XEPDB1**, 문자셋 **JA16SJISTILDE** |
| Java 백엔드 (UTF-8) | `mbj-app` | `8081→8080` (화면+API) | `mbj-postgres` |
| Java용 PostgreSQL (UTF-8) | `mbj-postgres` | `5434→5432` | DB `minibank`, `minibank/minibank` |

- **Oracle은 빌드하지 않습니다** — `limslee/oracle-database-xe:21.3.0`(서버와 동일 이미지)를 그대로 씁니다.
  ⚠️ 이 이미지는 기본이 `AL32UTF8`이므로 compose가 **`ORACLE_CHARACTERSET: JA16SJISTILDE`를 명시**합니다.
  스키마·시드는 `oracle-sjis/setup/00_mkuser.sql` → `sql/01_ddl.sql` → `sql/02_seed.sql` 순으로
  DB 생성 직후 1회 자동 적재됩니다(`/opt/oracle/scripts/setup` 훅).
- ⏱ **최초 기동은 10~20분** 걸립니다(XE가 Shift-JIS DB를 새로 만들고 스키마까지 적재). 이후 기동은 수십 초.
  진행 확인: `docker logs -f oracle_sjis`
- 예전에 쓰던 커스텀 Oracle 이미지(`Dockerfile.oracle-sjis` + `build-sjis-db.sh`의 `dbca` 재생성,
  18.6GB·빌드 40분)는 **서버와 구성을 맞추면서 폐지**했습니다.

### ⚠️ 사전 준비물 (필수 — 깃에 없음)

`backend-cobol/docker/vendor/`에 **재배포 불가 서드파티 3개**를 직접 내려받아 넣어야 빌드됩니다:

| 파일 | 입수처 |
|------|--------|
| `instantclient-basiclite-linux.x64.zip` | Oracle Instant Client (Linux x86-64) |
| `instantclient-sdk-linux.x64.zip` | 같은 페이지 SDK Package |
| `gixsql-1.0.20b.tar.gz` | GitHub `mridoni/gixsql` Releases (1.0.18+) |

자세한 입수·버전 대응은 **`backend-cobol/docker/vendor/README.md`** 참조.

> `sql/01_ddl.sql`·`02_seed.sql`은 JA16SJIS DB에 맞춘 **정상 타입(NUMBER/VARCHAR2/CHAR) + 일본어 리터럴**
> 정본입니다. `oracle_sjis` 최초 기동 시 `/opt/oracle/scripts/setup` 훅으로 자동 적재됩니다.
> 조회 시 컬럼이 사람이 읽는 값(예: 山田太郎 / 523400)으로 그대로 보입니다(RAW/디코드 뷰 불필요).

---

## 4. 배포된 데모 서버 (라이브)

사내 리눅스 서버(Ubuntu)에 **COBOL(Shift-JIS)·Java(UTF-8) 두 스택이 함께** 구동 중입니다.
구성 정본은 기밀 폴더의 `SERVER-SETUP.md` — 이 리포의 compose 도 그 구성과 동일하게 맞춰져 있습니다.

### 4.1 접속

> 🔒 **서버 IP·포트·SSH 계정·SSH 키·sudo 비밀번호는 공개 리포에 적지 않습니다.**
> 아래 값은 담당자(seoyeong 님, seoyeong.jeong@ks-infosys.com)에게 요청하세요.

- **망**: 사내 **Tailscale** 망 안에서만 접속됩니다 (먼저 Tailscale 로그인 필요).
- **SSH**: 키 기반 로그인. 담당자에게 ①서버 주소 ②SSH 계정 ③SSH 개인키(또는 본인 공개키 등록)를 받으세요.
  ```bash
  ssh -i <SSH키> <계정>@<서버주소>
  ```
- **웹/DB 포트** (Tailscale 망 또는 사내 LAN):
  - COBOL 프론트+API: `http://<서버주소>:8092/`  (컨테이너 `mb-cobol-sjis`)
  - Java API+프론트: `http://<서버주소>:8081/`   (컨테이너 `mbj-app`)
  - Oracle(Shift-JIS): `<서버주소>:1522` / 서비스 **`XEPDB1`** / `minibank`(데모 비번, §8) — 컨테이너 `oracle_sjis`
  - Java용 PostgreSQL: `<서버주소>:5434` / DB `minibank`
  > ⚠️ 서버에는 **다른 프로젝트용 DB도 함께** 있습니다 — `oracle`(1521/`FREEPDB1`), `postgres`(5433/`bank_postgres`),
  > `db2`(50000). 우리 것은 **1522/`XEPDB1`** 과 **5434/`minibank`** 입니다. 헷갈리지 마세요.
  > 자세한 서버 구성·접속정보는 기밀 폴더의 `SERVER-SETUP.md`(공개 리포에 없음) 참조.
- DB 조회 시 컬럼은 정상 타입(NUMBER/VARCHAR2/CHAR)이고, DBeaver 등에서 일본어가 **읽는 값 그대로** 표시됩니다(JDBC 드라이버가 JA16SJIS→클라이언트 변환 처리). 별도 디코드 뷰·함수는 없습니다.

### 4.2 배치 실행 (10단계 야간배치)

컨테이너 안에서 `run_batch.sh`를 실행합니다. **exec 셸에는 entrypoint의 `ORA_*`/`NLS_LANG`이
상속되지 않으므로 주입 필수**입니다(2026-08부터 배치도 Shift-JIS 응답이라 `NLS_LANG` 누락 시
UTF-8로 전환됨).

```bash
# 서버(SSH 접속 후). 로컬 Docker Desktop이면 'sudo' 빼고 동일.
sudo docker exec -w /app/build \
  -e ORA_CONN=oracle://oracle:1521/XEPDB1 -e ORA_USER=minibank -e ORA_PASS=minibank \
  -e NLS_LANG=JAPANESE_JAPAN.JA16SJISTILDE \
  mb-cobol-sjis \
  sh -c 'mkdir -p data && sh run_batch.sh'
# => [batch] all 10 steps done.
```

- 산출물은 컨테이너 내 `/app/build/data/` (예: `MEISAI.RPT`, `NIPPO.RPT`, `ZANDAKA.RPT`,
  `TESURYO.RPT`, `KYUMIN.RPT`, `KOUZA.LST`, `TOKEI.RPT`). 10단계 상세는 `backend-cobol/README.md` §5.
- 5~10(帳票)은 읽기 전용. 3(YAKANBAT)은 당일거래가 있을 때만 이자를 가산(거래 0건이면 잔액 불변).
- 리포트 확인 예: `sudo docker exec mb-cobol-sjis cat /app/build/data/TOKEI.RPT`
- **Java 백엔드도 같은 帳票 7종을 파일로 냅니다** — `POST /api/batch/run` → `backend-java/data/`
  (`MEISAI.TXT` + 6종. 6종은 COBOL 서식 그대로).
- **COBOL ↔ Java 1:1 값 대조**: `sh tools/parity/compare.sh` → `PARITY OK`.
  고정 픽스처(`sql/90_parity_fixture.sql`)를 양쪽에 적용해 배치를 돌리고 帳票 7종을 `diff` 합니다.
  ⚠️ 온라인 이체로 대조 데이터를 만들면 `TORIHIKI_DT`(삽입 시각)가 양쪽에서 달라져 明細이 전부
  불일치합니다 — 반드시 픽스처를 쓰세요. 상세는 `backend-java/DESIGN.md` §8.

### 4.3 상태 확인 / 재기동

```bash
sudo docker ps                                   # 컨테이너 상태
sudo docker logs --tail 20 mb-cobol-sjis       # 백엔드 로그
sudo docker restart mb-cobol-sjis              # 백엔드만 재기동(데이터 보존)
```

### 4.4 소스 갱신 후 재배포 (백엔드 이미지 재빌드)

Oracle 컨테이너(라이브 데이터)는 건드리지 않고 **백엔드 이미지만** 재빌드/교체합니다.
서버 `~/minibank-demo`는 **git clone**이므로 코드 갱신은 `git pull`로 합니다(코드는 git, 데이터만 서버 볼륨).

```bash
# 1) 최신 소스 반영
cd ~/minibank-demo && git pull
#    ※ vendor 파일(깃에 없음)은 그대로 유지됨. 없으면 vendor/README.md 참고해 재배치.
# 2) 이미지 재빌드 (★ 빌드 컨텍스트는 반드시 절대경로 — sudo 아래 ~ 는 /root)
sudo docker build -f backend-cobol/docker/Dockerfile.asis -t minibank-cobol-sjis:latest /home/<계정>/minibank-demo
# 3) 컨테이너 교체
#    ★서버는 oracle_sjis 의 '컨테이너 IP'로 직결한다★ 호스트 포워딩(1522) 경유는
#      리스너 리다이렉트 때문에 멈춘다. oracle_sjis 재시작으로 IP가 바뀌면 이 절차를 다시 실행.
IP=$(sudo docker inspect oracle_sjis --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
sudo docker rm -f mb-cobol-sjis
sudo docker run -d --name mb-cobol-sjis --restart unless-stopped --add-host oracle:$IP -p 8092:80 \
  -e ORA_CONN=oracle://$IP:1521/XEPDB1 -e ORA_USER=minibank -e ORA_PASS=minibank \
  -e NLS_LANG=JAPANESE_JAPAN.JA16SJISTILDE -e TZ=Asia/Tokyo \
  minibank-cobol-sjis:latest
```

> 🩺 **`{"ok":false,"error":"db_connect_failed"}` 가 나오면** 거의 항상 이 문제입니다 —
> `oracle_sjis` 가 재시작되며 컨테이너 IP가 바뀌었는데 `mb-cobol-sjis` 가 옛 IP를 붙들고 있는 것.
> 위 3) 을 다시 실행하면 복구됩니다. (Oracle 자체는 정상이므로 DBeaver 로는 조회가 됩니다.)

**Java 스택 재배포**
```bash
cd ~/minibank-demo && sudo docker compose -f backend-java/compose.java.yml up -d --build
```

### 4.5 데이터 초기화 (시드 상태로 리셋)

라이브 Oracle을 깨끗한 시드로 되돌립니다 (거래 삭제·잔액 원복).
⚠️ `NLS_LANG` 주입 필수 — 없으면 시드의 일본어가 깨져 들어갑니다.

```bash
sudo docker cp backend-cobol/sql/01_ddl.sql  oracle_sjis:/tmp/01_ddl.sql
sudo docker cp backend-cobol/sql/02_seed.sql oracle_sjis:/tmp/02_seed.sql
sudo docker exec -i -e NLS_LANG=AMERICAN_AMERICA.AL32UTF8 oracle_sjis sqlplus -s /nolog @/tmp/01_ddl.sql  </dev/null   # 드롭/재생성
sudo docker exec -i -e NLS_LANG=AMERICAN_AMERICA.AL32UTF8 oracle_sjis sqlplus -s /nolog @/tmp/02_seed.sql </dev/null   # 재적재
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
2. **앱↔DB 문자셋 — Shift-JIS 앱 레벨 재전환 완료** ✅ (2026-08). COBOL은 정상 컬럼을 직접
   바인딩(VARCHAR2 등가비교는 `RTRIM(:hv)`). Instant Client를 Basic(비-Lite)으로 바꿔 클라이언트
   문자셋이 실제로 JA16SJIS를 따라가게 했다 — DB·배치파일·온라인 HTTP 응답 전부 Shift-JIS. 쓰기
   경로(회원가입/공지)는 `UTF2SJIS.c`로 브라우저의 UTF-8을 명시 변환 후 저장(§1 참조).
3. **계좌번호 자릿수** — 프론트·DB 모두 7자리(`KOUZA_NO`)로 정합됨.
4. **DDL/시드 정본** ✅ — `sql/01_ddl.sql`·`02_seed.sql`은 JA16SJIS DB용 정상 타입 스키마 + 일본어 리터럴 시드.
   `oracle_sjis` 최초 기동 시 `/opt/oracle/scripts/setup` 훅으로 자동 적재됩니다.
5. **Java 전환 예정** — `backend-java/`는 온라인 9종 + 배치 이식 완료(PostgreSQL, UTF-8). 스키마는 전부
   정상 타입(integer/bigint/numeric/varchar/char/date), 일본어는 UTF-8 텍스트. (구 `codec` 패키지·jef4j
   의존성·디코드 뷰/함수·UTF-8 미러 컬럼은 제거됨.)

---

## 8. 기타

- DB 비밀번호(`compose.asis.yml`의 `oracle`/`minibank`)는 **데모 더미값**입니다. 실운영 시 반드시 교체·해시 저장.
- `.gitignore`로 vendor 대용량 다운로드·빌드 로그 산출물은 추적 제외됩니다.
