# backend-java 구성안 — COBOL 백엔드의 Java(Spring Boot) 이식

COBOL(GnuCOBOL + GixSQL + Oracle) ASIS 백엔드를 **Spring Boot + PostgreSQL**로 재구현하기 위한 설계 문서.
> ⚠️ 아직 구현 전. 이 문서는 착수 전 합의된 구조/방침이며, 실제 코드가 생기면 갱신한다.

---

## 0. 대원칙 (절대 훼손 금지)

이 데모의 정체성은 **메인프레임 바이트 원본을 그대로 저장/왕복**하는 것이다. Java 버전도 동일하게 간다.

| 데이터 | 저장 형태(바이트) | 비고 |
|--------|------------------|------|
| 텍스트(명의·지점명·공지·상태·일자 등) | **후지쯔 JEF EBCDIC** | jef4j (`x-Fujitsu-JEF-EBCDIC`) |
| 금액·이율·연수·원장금액 | **COMP-3 팩10진** | 부호 니블 C/D/F |
| 키(계좌·거래·대출 ID 등) | **존10진 EBCDIC** | 각 자리 `F`+숫자 |
| 예외(비-RAW) | `KANJI_UTF8`/`KANA_UTF8` 미러 + 조회 뷰 | 사람이 읽기용 |

- **화면 입력 → 인코딩 저장, 조회 → 디코딩 표시.** UI는 UTF-8.
- 기존 Oracle 라이브 데이터는 **바이트 동일**하게 PostgreSQL로 이관(형만 `RAW`→`bytea`).
- 검증 기준: 같은 입력에 대해 **DB에 저장되는 바이트가 COBOL판과 100% 동일**해야 한다(현신비교).

---

## 1. 기술 스택 (제안)

| 영역 | 선택 | 이유 |
|------|------|------|
| 언어/런타임 | **Java 21** (LTS, 로컬 JDK21 설치됨) | |
| 프레임워크 | **Spring Boot 3.x** (Spring Web MVC) | CGI 배관 대체 |
| DB 접근 | **Spring JDBC (`NamedParameterJdbcTemplate`)** | `byte[]` 직접 바인딩·커스텀 SQL에 최적. **JPA/Hibernate 비권장**(RAW/코덱 모델과 상충) |
| DB | **PostgreSQL 16**, 컬럼 `bytea` | |
| 드라이버 | `org.postgresql:postgresql` | |
| JEF 코덱 | **`net.arnx:jef4j`** (jar 이미 `backend-cobol/jef/`에 있음) | COBOL판 그대로 재사용 |
| 배치 | **경량 러너**(서비스 + CLI/스케줄) 기본, 필요 시 Spring Batch | 데모 규모엔 Spring Batch 과함 |
| 빌드 | **Maven** (로컬 설치됨) | |
| 컨테이너 | 단일 Dockerfile(앱) + `docker compose`(app + postgres) | nginx/fcgiwrap 불필요 |

---

## 2. 패키지 / 디렉토리 레이아웃

```
backend-java/
  pom.xml
  Dockerfile
  compose.java.yml
  src/main/java/com/ksbank/minibank/
    MinibankApplication.java
    config/         # DataSource, Jackson(UTF-8), 예외 핸들러(@ControllerAdvice)
    web/            # @RestController — /api/* (CGI 대체)
    service/        # 업무 로직(잔액계산·이체 원자성·이자 등)
    repository/     # JdbcTemplate DAO (EXEC SQL 대체, bytea 바인딩)
    domain/         # 엔티티/레코드 (KOUZA, TORIHIKI, LOAN ...)
    dto/            # 요청/응답 DTO (JSON 계약)
    codec/          # ★ JEF / COMP-3 / 존10진 코덱 (COBOL copy/W*·P* 대체)
    batch/          # 10개 배치 잡 (COBOL *BAT 대체)
    batch/report/   # 고정길이/텍스트 리포트 라이터
  src/main/resources/
    application.yml
    db/schema.sql   # PostgreSQL DDL (bytea)
    db/seed.sql     # HEXTORAW → decode(...,'hex') 시드
  src/test/java/... # 코덱 단위테스트(바이트 동일성) + API 통합테스트
```

---

## 3. 코덱 설계 (가장 중요 — `codec/`)

COBOL의 `WTXT/PTXT`(JEF), `WPACK/PPACK`(COMP-3·존10진)을 Java 클래스로 1:1 대체.

### 3.1 `JefCodec` (텍스트)
```java
static final Charset JEF = Charset.forName("x-Fujitsu-JEF-EBCDIC"); // jef4j 제공
byte[] encode(String utf8, int fixedLen)  // getBytes(JEF) → 0x40 패딩/절단(20byte 경계)
String decode(byte[] raw)                 // new String(raw, JEF) → 말미 0x40(공백) trim
```
- SO(0x28)/SI(0x29) 시프트는 jef4j가 처리. 명의는 20byte 고정, 초과 시 **20byte 경계 절단**(결정타3).
- ★DB만으로 JEF 디코드 불가 → 조회 뷰의 명의는 `KANJI_UTF8` 미러 사용(Oracle과 동일 한계).

### 3.2 `PackedDecimalCodec` (COMP-3 금액)
```java
byte[] encode(long value, int bytes)   // 팩10진, 마지막 니블 부호 C(+)/D(-)
long   decode(byte[] raw)              // 니블 파싱 + 부호
```
- 자릿수↔바이트: `bytes = floor(digits/2)+1`. 예 S9(11)=6byte, S9(5)=3byte. 이율 S9(3)V999=4byte.

### 3.3 `ZonedDecimalCodec` (존10진 키/일자)
```java
byte[] encode(String digits)  // 각 자리 → 0xF0|digit
String decode(byte[] raw)     // 하위 니블만 추출
```
- 계좌번호 `1000123` → `F1 F0 F0 F0 F1 F2 F3`. 일자(YYYYMMDD)도 동일 방식.

### 3.4 저장 원칙
- Repository는 위 코덱으로 인코딩한 `byte[]`를 **`ps.setBytes()`**로 바인딩, 조회는 **`rs.getBytes()`** 후 디코딩.
- Oracle판이 필요로 하던 `HEXTORAW()/RAWTOHEX()`는 **불필요**(PG `bytea`는 바이트 네이티브 바인딩). ← Java+PG로 가면서 깔끔해지는 지점.

---

## 4. PostgreSQL 스키마

`backend-cobol/sql/01_ddl.sql`(Oracle, 전 컬럼 RAW)을 PG로 이식:

| Oracle | PostgreSQL |
|--------|-----------|
| `RAW(n)` | `bytea` |
| `NVARCHAR2(n)` (미러 2컬럼) | `text` |
| `SEQ_* (START WITH …)` | `CREATE SEQUENCE … START …` (동일) |
| `HEXTORAW('..')` 시드 | `decode('..','hex')` 시드 |
| PK/FK/CHECK | 대부분 그대로 (CHECK는 bytea 비교로) |

**조회용 디코드 함수/뷰**(DBeaver용): `fn_unzone(bytea)→numeric`, `fn_unpack(bytea)→numeric`는 PL/pgSQL로 이식 용이.
`fn_ebc`(단바이트 EBCDIC→문자)는 PG에 `UTL_I18N/WE8EBCDIC500`이 없으므로 **PL/pgSQL 룩업 테이블** 또는 **앱단 디코드**로 대체(주의점). JEF(일본어)는 Oracle과 마찬가지로 DB 디코드 불가 → 미러 사용.

---

## 5. 온라인 API 매핑 (CGI → Controller/Service)

계약(`/api/*`, JSON UTF-8, `{"ok":true|false,...}`)은 **그대로 유지**(프론트 무변경). 실사용 CGI 9종:

| CGI (COBOL) | Controller.Method | 핵심 로직 |
|-------------|-------------------|-----------|
| LOGIN | `AuthController.login` | branch/pw 인코딩 WHERE, 계좌정보 디코드 |
| SIGNUP | `AccountController.signup` | 신규 계좌(명의 JEF, 키 채번 존10진), 미러 기록 |
| ZANDAKA | `AccountController.balance` | 잔액 조회(COMP-3 디코드) |
| FURIKOMI | `TransferController.transfer` | **원자적 이체**(출금+입금 2행, 수수료 110), `@Transactional` |
| MEISAI | `StatementController.list` | 명세(키/금액/일자 디코드) |
| LOAN | `LoanController.list/create` | 대출 목록/실행 |
| REPAY | `LoanController.repay` | 상환(이자·수수료 550) |
| NOTICE | `NoticeController.list/create` | 공지 |
| HOLDINGS | `AccountController.holdings` | 보유(최소 구현) |

- COBOL `FURIKOMI`의 원자성 → `@Transactional`(체크 예외 시 롤백).
- 계좌 상태 `9`(凍結) 거부 등 업무 규칙은 service 계층으로.

---

## 6. 배치 매핑 (10 → Java)

`batch/` 아래 잡 클래스 10개. `run_batch.sh` → `BatchRunner`(CLI 인자 or 스케줄)로 순차 실행.

| # | COBOL | Java 잡 | 비고 |
|---|-------|---------|------|
| 1 | MKDAT | `ExtractTxnJob` | DB→중간표현(파일 불필요, 컬렉션으로 대체 가능) |
| 2 | SORTDAT | *(제거)* | `ORDER BY`/Java `sort`로 흡수 |
| 3 | YAKANBAT | `PostingJob` | control-break 이자계산·잔액갱신(普通만, `floor(잔액/365000)`) |
| 4 | SORTRPT | *(제거)* | 정렬은 SQL/Java |
| 5 | NIPPOBAT | `DailyTxnReportJob` | 구분별 집계 → NIPPO.RPT |
| 6 | ZANDABAT | `BalanceListJob` | 잔액일람 |
| 7 | TESUBAT | `FeeSummaryJob` | 수수료 집계 |
| 8 | KYUMBAT | `DormantJob` | 무거래 계좌 |
| 9 | MASTBAT | `MasterListJob` | 마스터 일람 |
| 10 | TOKEBAT | `StatsJob` | 통계 |

- **SORT 분리 프로세스(SORTDAT/SORTRPT)는 소멸** — GnuCOBOL SORT 크래시 회피용이었으므로 Java에선 불필요.
- 리포트는 기존 형식 유지(고정길이 EBCDIC or 사람이 읽는 텍스트) — 필요 형식 선택.

---

## 7. COBOL 배관 → Spring 대체 (무엇이 사라지나)

| COBOL/인프라 | Java 대체 | 상태 |
|--------------|-----------|------|
| CGIINIT/CGIPARM/CGIRESP | Spring MVC(@RestController, 파라미터 바인딩, Jackson) | 소멸 |
| nginx + fcgiwrap | 내장 Tomcat | 소멸 |
| `JEFCONV.c`(C 브리지) + `JefServer`(별도 프로세스) | **jef4j 직접 호출**(인프로세스) | 소멸 |
| EXEC SQL + GixSQL + `HEXTORAW/RAWTOHEX` | JdbcTemplate + `bytea` 바인딩 | 대체 |
| PDBCON/PDBCONB(접속) | Spring DataSource(HikariCP) | 대체 |
| PERRJSON(에러 JSON) | `@ControllerAdvice` 예외 핸들러 | 대체 |
| SORTDAT/SORTRPT | SQL `ORDER BY`/Java 정렬 | 소멸 |
| Oracle Instant Client / gixsql vendor | 불필요(PG JDBC 순수 자바) | 소멸 |

→ **vendor 대용량 다운로드 의존이 사라져** 빌드/배포가 크게 단순해진다.

---

## 8. 데이터 마이그레이션 & 검증

- **이관**: Oracle 라이브 → PG. RAW 컬럼은 바이트 동일 이관(`RAWTOHEX` 덤프 → `decode(hex)` 적재). 미러/텍스트는 그대로.
- **바이트 동일성 테스트(최우선)**: 코덱 단위테스트로 COBOL판 저장 바이트와 대조
  - 명의 `山田太郎` → `28BBB3C5C4C2C0CFBA29` + 0x40 패딩
  - 잔액 `523400` → COMP-3 `00000523400C`
  - 계좌 `1000123` → 존10진 `F1F0F0F0F1F2F3`
- **E2E 회귀**: 로그인/이체(원자성·수수료)/명세/대출/상환/공지 + 10단계 배치 결과가 COBOL판과 일치.
- 병렬 가동 기간엔 같은 입력을 양쪽에 넣어 DB 바이트/리포트 diff = 0 확인.

---

## 9. 단계별 로드맵

1. **스캐폴딩**: Spring Boot + Maven + PG compose, `application.yml`, DataSource.
2. **코덱 + 테스트**: `JefCodec`/`PackedDecimalCodec`/`ZonedDecimalCodec` + 바이트 동일성 단위테스트(최우선 스파이크).
3. **스키마/시드**: `schema.sql`(bytea) + `seed.sql`(decode hex) + 디코드 함수/뷰.
4. **온라인 수직 슬라이스 1개**: LOGIN 완주(웹→서비스→리포지토리→코덱→DB→디코드 응답)로 아키텍처 확정.
5. **온라인 나머지 8**: 계약 유지하며 이식, 이체 원자성 집중 검증.
6. **배치 8종(+posting)**: 잡 러너 + 리포트.
7. **데이터 이관 + 컷오버**: 프론트를 Java 오리진으로, 양판 diff 검증.

---

## 10. 함정 체크리스트 (COBOL 이식 경험)

- [ ] COMP-3 **부호 니블**(C/D/F) 왕복 정확 — 음수 `-50000` 포함.
- [ ] 존10진 키 자릿수 고정(계좌 7, 거래ID 12 등) — 패딩/길이 어긋나면 FK 깨짐.
- [ ] 명의 **20byte 경계 절단**(SO/SI 포함) — 긴 명의 결정타3.
- [ ] JEF **미매핑 문자**(예 `〜` U+301C → `～` U+FF5E 치환) 처리.
- [ ] 단바이트 EBCDIC(코드·일자·상태)와 JEF(일본어) 디코드 경로 구분.
- [ ] 이체 **원자성**: 실패 시 전체 롤백(잔액 불일치 0).
- [ ] 이자: 普通(종별1)만 `floor(잔액/365000)`, 当座 무이자.
- [ ] PG `bytea` 조회/바인딩 시 인코딩 옵션(`bytea_output`) 영향 없는지 — `getBytes/setBytes` 사용.
- [ ] 배치 posting 이중 반영 금지(온라인이 이미 실시간 반영 — YAKANBAT은 이자만).

---

## 부록 A. 참조

- COBOL 정본: `backend-cobol/README.md`(§상단 인코딩 현황, §2 API, §5 배치 10단계)
- 코덱 원본: `backend-cobol/cobol/copy/{WTXT,PTXT,WPACK,PPACK}.cpy`, `cobol/JEFCONV.c`, `jef/`
- 스키마 원본: `backend-cobol/sql/{01_ddl,02_seed,99_reset}.sql` (Oracle 전 컬럼 RAW)
