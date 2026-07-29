# KS銀行 ミニバンク・デモ (KS-Bank mockup)

메인프레임 레거시(COBOL + EBCDIC + Oracle)를 재현한 **인터넷뱅킹 데모**입니다.
DB에 들어가는 값을 전부 **메인프레임 바이트(RAW)로 저장하고 조회 시 디코드**하는 것이 핵심 기술 포인트입니다:
일본어 명의 등 텍스트 = **후지쯔 JEF EBCDIC**, 금액 = **COMP-3 팩10진**, 키 = **존10진 EBCDIC**.

> **인수인계 문서입니다.** 처음 받는 분은 이 파일부터 읽고, 세부는 각 폴더의 README/문서를 참고하세요.
>
> 🎬 **처음 접속해서 시연만 하실 분은 [`DEMO.md`](./DEMO.md)** — 접속·로그인·시연 시나리오를 순서대로 정리해뒀습니다.

---

## 1. 전체 구조

```
브라우저 (frontend/)  ──/api/...──▶  CGI (nginx + fcgiwrap)
                                        │
                                   COBOL (GnuCOBOL + GixSQL EXEC SQL)
                                    │        │
              CALL "JEFCONV" ───────┘        └────── Oracle
                    │                        (전 컬럼 RAW: JEF/COMP-3/존10진)
             JEFCONV.c (C 브리지)
                    │
             JefServer (Java 상주 서비스, 127.0.0.1:9099, jef4j.jar)
```

- 프론트엔드는 SPA(바닐라 JS)이며 `/api/...` 상대경로로 백엔드를 호출합니다.
- 백엔드는 **ASIS(레거시) COBOL**이 정본. nginx가 프론트 정적파일과 `/api`를 **같은 오리진**으로 서빙합니다.
- COBOL이 텍스트를 JEF로 변환할 때 `CALL "JEFCONV"` → C 브리지 → 상주 Java 서비스(jef4j)를 경유합니다. 금액(COMP-3)·키(존10진)는 COBOL 코덱 카피북에서 직접 처리합니다.

---

## 2. 디렉터리 구성 (최상위)

| 경로 | 내용 | 상태 |
|------|------|------|
| `frontend/` | SPA (index.html / app.js / styles.css). `/api/...` 호출 | 사용 중 |
| `backend-cobol/` | **ASIS 정본 백엔드** — COBOL 소스·카피북·JEF·SQL·Docker | 사용 중 (배포됨) |
| `db/` | app.js 인메모리 모델을 정규화한 UTF-8 Oracle 스키마 | **참조용** (ASIS와 별개) |
| `backend-java/` | Java 전환용 자리(빈 폴더) | 예정 (§7) |
| `claude readme/` | ASIS 백엔드 설계 프롬프트 원문 | 참고 문서 |

`backend-cobol/` 안 주요 폴더: `cobol/`(COBOL 소스 + `JEFCONV.c` C 브리지), `cobol/copy/`(카피북 — 코덱 `WTXT/PTXT`=텍스트 JEF, `WPACK/PPACK`=금액·키), `jef/`(jef4j.jar + `JefServer.java` 등 JEF 변환 서비스), `sql/`, `docker/`, `cgi/`, `build/`.

> `db/`와 `backend-cobol/sql/`은 **서로 다른 스키마**입니다. 실제 구동 정본은 `backend-cobol/`(RAW), `db/`는 UTF-8 정규화 참조본으로 보존만 합니다.

---

## 3. 실행 방법 (Docker)

```bash
# 리포지토리 루트에서
docker compose -f backend-cobol/docker/compose.asis.yml up -d --build
# → http://localhost:8080/  (프론트 + API 동일 오리진)
```

- `oracle` (gvenzl/oracle-free 23, :1521): 최초 기동 시 `sql/01_ddl.sql` → `02_seed.sql` 자동 적용
- `asis-backend` (nginx + fcgiwrap + CGI + JEF 서비스, 8080→80): 프론트 `/`, API `/api/...`

### ⚠️ 사전 준비물 (필수 — 깃에 없음)

`backend-cobol/docker/vendor/`에 **재배포 불가 서드파티 3개**를 직접 내려받아 넣어야 빌드됩니다:

| 파일 | 입수처 |
|------|--------|
| `instantclient-basiclite-linux.x64.zip` | Oracle Instant Client (Linux x86-64) |
| `instantclient-sdk-linux.x64.zip` | 같은 페이지 SDK Package |
| `gixsql-1.0.20b.tar.gz` | GitHub `mridoni/gixsql` Releases (1.0.18+) |

자세한 입수·버전 대응은 **`backend-cobol/docker/vendor/README.md`** 참조.

> `sql/01_ddl.sql`·`02_seed.sql`은 라이브 서버 DB(전 컬럼 RAW)에서 재생성한 정본이라, 프레시 컨테이너
> 초기화가 코드(RAW)와 정합됩니다. 프레시 `gvenzl/oracle-free` 컨테이너에 init으로 물려 기동 검증 완료
> (에러 0 / INVALID 오브젝트 0 / 디코드 뷰 정상). 조회 시 원본 RAW는 사람이 못 읽으니 `V_*` 뷰를 사용하세요.

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
- DB 조회 시 원본은 RAW라 사람이 못 읽으므로, DBeaver 등에서는 디코드 뷰
  `V_KOUZA / V_TORIHIKI / V_LOAN / V_REPAY / V_NOTICE` 사용 (함수 `FN_UNZONE`=키, `FN_UNPACK`=금액, `FN_EBC`=단바이트 EBCDIC).

### 4.2 배치 실행 (10단계 야간배치)

컨테이너 안에서 `run_batch.sh`를 실행합니다. **exec 셸에는 entrypoint의 `ORA_*`/`JEF_PORT`가
상속되지 않으므로 주입 필수**입니다.

```bash
# 서버(SSH 접속 후). 로컬 Docker Desktop이면 'sudo' 빼고 동일.
sudo docker exec -w /app/build \
  -e ORA_CONN=oracle://oracle:1521/FREEPDB1 -e ORA_USER=minibank -e ORA_PASS=minibank \
  -e JEF_PORT=9099 mb-asis-backend \
  sh -c 'mkdir -p data && sh run_batch.sh'
# => [batch] all 10 steps done.
```

- 산출물은 컨테이너 내 `/app/build/data/` (예: `MEISAI.RPT`, `NIPPO.RPT`, `ZANDAKA.RPT`,
  `TESURYO.RPT`, `KYUMIN.RPT`, `KOUZA.LST`, `TOKEI.RPT`). 10단계 상세는 `backend-cobol/README.md` §5.
- 5~10(帳票)은 읽기 전용. 3(YAKANBAT)은 당일거래가 있을 때만 이자를 가산(거래 0건이면 잔액 불변).
- 리포트 확인 예: `sudo docker exec mb-asis-backend cat /app/build/data/TOKEI.RPT`

### 4.3 상태 확인 / 재기동

```bash
sudo docker ps                                   # 컨테이너 상태
sudo docker logs --tail 20 mb-asis-backend       # 백엔드 로그(JEF 서비스 기동 등)
sudo docker restart mb-asis-backend              # 백엔드만 재기동(데이터 보존)
```

### 4.4 소스 갱신 후 재배포 (백엔드 이미지 재빌드)

Oracle 컨테이너(라이브 데이터)는 건드리지 않고 **백엔드 이미지만** 재빌드/교체합니다.

```bash
# 1) 최신 소스 반영: 이 리포를 서버에 clone/pull 하거나 변경 파일을 scp
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

> 계좌번호는 **7자리 `KOUZA_NO`**(프론트 표시와 일치). DB에는 존10진 EBCDIC RAW로 저장됩니다(예 `1000123` → `F1F0F0F0F1F2F3`).

---

## 6. 더 깊은 문서

| 문서 | 내용 |
|------|------|
| `backend-cobol/README.md` | **백엔드 정본 문서** — API 계약, 데이터모델, 빌드/야간배치, 인코딩 구현 현황(상단), 검증 체크리스트 |
| `backend-cobol/docker/vendor/README.md` | vendor 서드파티 입수 방법 |
| `db/README.md` | 참조용 UTF-8 스키마·시드·ER 개요 |
| `claude readme/ClaudeCode_Prompt_ASIS_COBOL_Backend.md` | ASIS 설계 지시서 원문 |

---

## 7. 알려진 한계 · 다음 작업

1. **문자 인코딩 — JEF 구현 완료** ✅ (초기 데모의 `TEAMENC` 스텁은 삭제됨). 텍스트는 후지쯔 JEF EBCDIC
   (`net.arnx:jef4j` 라이브러리, charset `x-Fujitsu-JEF-EBCDIC`)로 왕복합니다. COBOL `CALL "JEFCONV"`
   → `JEFCONV.c`(C 브리지) → `JefServer`(상주 Java 서비스). 화면 표시는 RAW 디코드가 정본이며,
   `KOUZA_EXT.KANJI_UTF8/KANA_UTF8`는 조회·폴백용 UTF-8 미러로만 유지합니다.
2. **금액·키 인코딩 완료** ✅ — 금액/이율/원장금액 = COMP-3 RAW, 키(계좌·거래·대출 ID 등) = 존10진 EBCDIC RAW.
   코덱은 카피북 `WPACK/PPACK`(금액·키), `WTXT/PTXT`(텍스트)로 온라인 CGI 11개 + 배치 전부 적용됨.
3. **계좌번호 자릿수** — 프론트·DB 모두 7자리(`KOUZA_NO`)로 정합됨.
4. **DDL/시드 소스 정합 완료** ✅ (2026-07-29) — `sql/01_ddl.sql`·`02_seed.sql`을 라이브 DB에서
   DBMS_METADATA로 재생성(전 컬럼 RAW + HEXTORAW 시드 + 디코드 함수/뷰). 프레시 컨테이너 기동 검증 완료.
   ※ 라이브 DB의 마이그레이션 이력만 있고 RAW 생성 스크립트는 남아있지 않으므로, 향후 스키마 변경 시엔
   라이브 DB → DBMS_METADATA 재추출 방식으로 소스를 갱신하세요.
5. **Java 전환 예정** — `backend-java/`는 자리만 잡힌 상태. 방침: `JEFCONV.c`/CGI 배관을 버리고
   jef4j 직접 사용 + 웹프레임워크 + JDBC. COMP-3/존10진은 Java 직접 구현, JEF는 jef4j 재사용.
   (실사용 백엔드 = `.cbl` 18개 + `.cpy` 14개)

---

## 8. 기타

- DB 비밀번호(`compose.asis.yml`의 `oracle`/`minibank`)는 **데모 더미값**입니다. 실운영 시 반드시 교체·해시 저장.
- `.gitignore`로 vendor 대용량 다운로드·빌드 로그·`*.class` 산출물은 추적 제외됩니다.
- `jef/jef4j.jar`(약 472KB, Apache-2.0)는 빌드 안정성을 위해 리포에 포함합니다.
