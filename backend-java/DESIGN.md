# backend-java 구성안 — COBOL 백엔드의 Java(Spring Boot) 이식

COBOL(GnuCOBOL + GixSQL + Oracle) ASIS 백엔드를 **Spring Boot + PostgreSQL**로 재구현한 설계 문서.
> ✅ 온라인 9종 + 배치 이식 완료. **2026-07-30 문자셋 정상화** 반영본.
> 이전엔 전 컬럼을 메인프레임 바이트(RAW/bytea) + 앱측 코덱으로 왕복했으나, 그 설계는 전부 제거됐다.

---

## 0. 대원칙

이 데모의 정체성은 일본 은행 인터넷뱅킹 업무를 **COBOL판과 동일한 화면·기능·계약**으로 재현하는 것이다.
Java 버전은 **PostgreSQL을 UTF-8로 평범하게** 쓴다(정상 타입 end-to-end).

| 데이터 | PostgreSQL 타입 | 비고 |
|--------|------------------|------|
| 키(계좌·지점·거래·대출 ID 등) | `integer` | KOUZA_NO / BRANCH_CODE 등 |
| 금액·원장금액 | `bigint` / `numeric` | ZANDAKA / KINGAKU / PRINCIPAL |
| 이율 | `numeric(5,3)` | |
| 텍스트(명의·지점명·공지 등) | `varchar` (**UTF-8**) | 일본어 평문 저장 |
| 코드·상태·일자 | `char` / `date` | |

- **UI·앱·DB 전부 UTF-8, 정상 타입.** 인코딩/디코딩 코덱 없음.
- COBOL/Oracle 쪽은 DB가 디스크에 Shift-JIS(JA16SJIS)로 저장되지만 드라이버가 앱에 UTF-8로 넘겨준다. **Java/PostgreSQL 쪽은 저장부터 UTF-8**이라 그 변환조차 없다.

> 📌 이전엔 텍스트=JEF EBCDIC / 금액=COMP-3 / 키=존10진을 `bytea`로 저장하고 `codec` 패키지로 왕복했으나,
> 2026-07-30에 전부 정상 타입(UTF-8)으로 마이그레이션하며 코덱·미러컬럼·디코드 함수/뷰를 삭제했다.

---

## 1. 기술 스택 (제안)

| 영역 | 선택 | 이유 |
|------|------|------|
| 언어/런타임 | **Java 21** (LTS, 로컬 JDK21 설치됨) | |
| 프레임워크 | **Spring Boot 3.x** (Spring Web MVC) | CGI 배관 대체 |
| DB 접근 | **Spring JDBC (`NamedParameterJdbcTemplate`)** | 정상 타입 직접 바인딩·커스텀 SQL에 최적 |
| DB | **PostgreSQL 16**, 정상 타입 컬럼(`integer`/`bigint`/`numeric`/`varchar`/`char`/`date`) | UTF-8 |
| 드라이버 | `org.postgresql:postgresql` | |
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
    repository/     # JdbcTemplate DAO (EXEC SQL 대체, int/long/String 직접 바인딩)
    domain/         # 엔티티/레코드 (KOUZA, TORIHIKI, LOAN ...)
    dto/            # 요청/응답 DTO (JSON 계약)
    batch/          # 10개 배치 잡 (COBOL *BAT 대체)
    batch/report/   # 고정길이/텍스트 리포트 라이터
  src/main/resources/
    application.yml # UTF-8 서블릿 인코딩 강제(아래 §3)
    db/schema.sql   # PostgreSQL DDL (정상 타입, UTF-8)
    db/seed.sql     # 일본어 리터럴 + 숫자값 직접 INSERT
  src/test/java/... # API 통합테스트
```

> 구 `codec/` 패키지(`JefCodec`/`PackedDecimalCodec`/`ZonedDecimalCodec`/`Enc`/`Fields`)와 그 단위테스트,
> `jef4j` Maven 의존성은 2026-07-30에 **삭제**됐다.

---

## 3. 데이터 접근 & 문자셋 (정상 타입 · UTF-8)

> 이전 버전의 핵심이던 `codec/` 패키지(JEF/COMP-3/존10진 인코딩)는 2026-07-30 정상화로 **삭제**됐다.
> 지금은 코덱이 없다 — Repository가 `int`/`long`/`String`을 JdbcTemplate로 **직접 바인딩**한다.

### 3.1 바인딩 원칙
- 키·금액 = `setInt/setLong` 또는 `numeric` 매핑, 텍스트 = `setString`(UTF-8). 조회는 `getInt/getLong/getString` 그대로.
- Oracle판이 필요로 하던 `HEXTORAW()/RAWTOHEX()`·`setBytes/getBytes`·부호 니블 처리·20byte 경계 절단 로직은 **전부 불필요**. 명의 길이는 `varchar` 컬럼 폭으로 관리.

### 3.2 문자셋(UTF-8) 강제
- `application.yml`이 서블릿 요청/응답 인코딩을 UTF-8로 강제한다:
  ```yaml
  server:
    servlet:
      encoding:
        charset: UTF-8
        enabled: true
        force: true      # 폼 파라미터(일본어)가 UTF-8로 확실히 디코드되도록
  ```
- PostgreSQL DB는 UTF-8, JDBC 드라이버는 기본 UTF-8. 저장부터 표시까지 일본어가 평문으로 흐른다(변환 단계 없음).

---

## 4. PostgreSQL 스키마

정본은 `backend-java/src/main/resources/db/{schema.sql,seed.sql}`(정상 타입, UTF-8). 타입 매핑:

| 데이터 | PostgreSQL |
|--------|-----------|
| 키(계좌·지점·거래·대출 ID) | `integer` |
| 금액·원장금액 | `bigint` / `numeric` |
| 이율 | `numeric(5,3)` |
| 텍스트(명의·지점명·공지 등) | `varchar` (UTF-8 평문) |
| 코드·상태·일자 | `char` / `date` |
| 채번 시퀀스 | `CREATE SEQUENCE … START …` |
| PK/FK/CHECK | 정상 타입 비교로 그대로 |

- **시드**는 일본어 리터럴 + 숫자값을 직접 `INSERT`한다(구 `decode('..','hex')` hex 시드는 폐기).
- 구 `KANJI_UTF8`/`KANA_UTF8` **UTF-8 미러 컬럼**, 디코드 함수 `fn_unzone`/`fn_unpack`, 디코드 뷰 `V_KOUZA`/`V_TORIHIKI`는 **모두 제거**됐다 — 일본어가 `varchar`에 평문으로 들어가 조회 시 그대로 읽히므로 불필요.

---

## 5. 온라인 API 매핑 (CGI → Controller/Service)

계약(`/api/*`, JSON UTF-8, `{"ok":true|false,...}`)은 **그대로 유지**(프론트 무변경). 실사용 CGI 9종:

| CGI (COBOL) | Controller.Method | 핵심 로직 |
|-------------|-------------------|-----------|
| LOGIN | `AuthController.login` | branch/pw WHERE 조회, 계좌정보 반환 |
| SIGNUP | `AccountController.signup` | 신규 계좌(명의 varchar, 키 채번) |
| ZANDAKA | `AccountController.balance` | 잔액 조회 |
| FURIKOMI | `TransferController.transfer` | **원자적 이체**(출금+입금 2행, 수수료 110), `@Transactional` |
| MEISAI | `StatementController.list` | 명세 목록 |
| LOAN | `LoanController.list/create` | 대출 목록/실행 |
| REPAY | `LoanController.repay` | 상환(이자·수수료 550) |
| NOTICE | `NoticeController.list/create` | 공지 |
| HOLDINGS | `AccountController.holdings` | 보유(최소 구현) |

- 모든 컬럼이 정상 타입이라 encode/decode 없이 값을 그대로 다룬다(구 코덱 경유 로직 제거됨).
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
- 리포트는 사람이 읽는 텍스트(UTF-8). 명세 명의 등 일본어도 평문으로 출력(구 고정길이 EBCDIC 원본 방식 폐기).

---

## 7. COBOL 배관 → Spring 대체 (무엇이 사라지나)

| COBOL/인프라 | Java 대체 | 상태 |
|--------------|-----------|------|
| CGIINIT/CGIPARM/CGIRESP | Spring MVC(@RestController, 파라미터 바인딩, Jackson) | 소멸 |
| nginx + fcgiwrap | 내장 Tomcat | 소멸 |
| `JEFCONV.c`(C 브리지) + `JefServer`(별도 프로세스) | **불필요**(정상 타입·UTF-8) | 소멸 |
| EXEC SQL + GixSQL + `HEXTORAW/RAWTOHEX` | JdbcTemplate + 정상 타입 직접 바인딩 | 대체 |
| PDBCON/PDBCONB(접속) | Spring DataSource(HikariCP) | 대체 |
| PERRJSON(에러 JSON) | `@ControllerAdvice` 예외 핸들러 | 대체 |
| SORTDAT/SORTRPT | SQL `ORDER BY`/Java 정렬 | 소멸 |
| Oracle Instant Client / gixsql vendor | 불필요(PG JDBC 순수 자바) | 소멸 |

→ **vendor 대용량 다운로드 의존이 사라져** 빌드/배포가 크게 단순해진다.

---

## 8. 검증

- **문자셋**: 일본어(명의 `山田太郎` 등)가 UI 입력 → DB `varchar` → 조회/리포트까지 UTF-8 평문으로 왕복, 문자화けなし.
- **기능 파리티(E2E 회귀)**: 로그인/이체(원자성·수수료)/명세/대출/상환/공지 + 10단계 배치 결과가 COBOL판과 업무적으로 일치.
- **금액·키 정확도**: 잔액·수수료·이자 계산값, 채번 키의 자릿수/무결성이 정상 타입으로 유지되는지.

> 구 검증의 핵심이던 "코덱 바이트 동일성"(JEF/COMP-3/존10진 RAW 바이트 대조) 스파이크는 2026-07-30 정상화로 대상에서 빠졌다.
> 이제 관점은 "정상 타입 값 정확도 + 일본어 UTF-8 왕복"이다.

---

## 9. 단계별 로드맵

> 온라인 9종 + 배치는 이식 완료. 아래는 현재 구조 기준의 빌드 경로(정상화 후).

1. **스캐폴딩**: Spring Boot + Maven + PG compose, `application.yml`(UTF-8 강제), DataSource.
2. **스키마/시드**: `schema.sql`(정상 타입) + `seed.sql`(일본어 리터럴 + 숫자값 직접 INSERT).
3. **온라인 수직 슬라이스 1개**: LOGIN 완주(웹→서비스→리포지토리→DB→응답)로 아키텍처 확정.
4. **온라인 나머지 8**: 계약 유지하며 이식, 이체 원자성 집중 검증.
5. **배치 8종(+posting)**: 잡 러너 + 리포트.
6. **컷오버**: 프론트를 Java 오리진으로.

> (남은 운영화: 서버 배포, 인증/PW 해시, 프로필 컬럼 확장 등 — `ONBOARDING.md` §6 참조.)

---

## 10. 함정 체크리스트

> 구 코덱(COMP-3 부호 니블·존10진 자릿수·20byte 절단·JEF 미매핑·bytea 옵션) 관련 함정은
> 정상 타입 전환으로 대부분 소멸. 현재 유효한 것만:

- [ ] 이체 **원자성**: 실패 시 전체 롤백(잔액 불일치 0).
- [ ] 이자: 普通(종별1)만 `floor(잔액/365000)`, 当座 무이자.
- [ ] 배치 posting 이중 반영 금지(온라인이 이미 실시간 반영 — YAKANBAT은 이자만).
- [ ] 일본어 폼 파라미터 디코드 — `application.yml`의 `server.servlet.encoding.force=true` 유지(끄면 폼 일본어 깨질 수 있음).
- [ ] 채번 키 자릿수(계좌 7자리 등)·FK 무결성 유지.
- [ ] 로컬 PG 포트 **5433**(호스트 native PG 5432 충돌 회피, `compose.java.yml`).

---

## 부록 A. 참조

- 스키마/시드 정본(Java): `backend-java/src/main/resources/db/{schema.sql,seed.sql}` (정상 타입, UTF-8)
- COBOL 정본: `backend-cobol/README.md`(§상단 문자셋 현황, §2 API, §5 배치 10단계)
- COBOL 스키마: `backend-cobol/sql/{01_ddl,02_seed,99_reset}.sql` (Oracle JA16SJIS, 정상 타입)
