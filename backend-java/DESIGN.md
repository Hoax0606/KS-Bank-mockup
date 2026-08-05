# backend-java 구성안 — COBOL 백엔드의 Java(Spring Boot) 이식

COBOL(GnuCOBOL + GixSQL + Oracle) ASIS 백엔드를 **Spring Boot + PostgreSQL**로 재구현한 설계 문서.
> ✅ 온라인 9종 이식 완료. **2026-07-30 문자셋 정상화** 반영본.
> ✅ 배치 = posting + **明細(MEISAI)** + 帳票 6종, 파일 7종 출력.
> **COBOL과 帳票 7종 값 1:1 일치 확인(`PARITY OK`, 2026-08-04 실측)** — 절차는 §8.
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
    batch/          # BatchService(오케스트레이션) + MeisaiBuilder(YAKANBAT) + KanaSortKey(SORTRPT)
    batch/report/   # 리포트 렌더러 — JsonRenderer(API 응답) / ReportWriter(帳票 파일 7종)
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

`POST /api/batch/run` 한 번으로 10스텝 전체를 수행한다(구조: **compute → apply → render**).
`BatchService.run()`이 계산하고, 결과 `BatchResult`를 `JsonRenderer`(API 응답)와
`ReportWriter`(帳票 파일 7종)로 각각 렌더링한다.

| # | COBOL | Java | 비고 |
|---|-------|------|------|
| 1 | MKDAT | `ReportRepository.allTxnsForBatch()` | **`ORDER BY kouza_no, torihiki_id`** — MKDAT과 동일. 온라인 `findByKouza`의 `(dt,id)`와 다르다(§10) |
| 2 | SORTDAT | *(SQL `ORDER BY`로 흡수)* | GnuCOBOL SORT 크래시 회피용 껍데기였으므로 Java에선 불필요 |
| 3 | YAKANBAT | `MeisaiBuilder` | control-break. 期首 역산 + 이자(`普通` && 잔액>0 → `floor(잔액/365000)`) + **明細 D/T 생성** |
| 4 | SORTRPT | `KanaSortKey` | *제거가 아니라 재구현*. 名義カナ를 **UTF-8 60byte 패딩 후 unsigned 바이트** 비교 + `seq` 타이브레이크(`SW2-KANA SW2-SEQ`) |
| 5 | NIPPOBAT | `BatchService.dailyTxnReport` | 구분별 집계 → JSON `nippo` / `NIPPO.RPT` |
| 6 | ZANDABAT | `BatchService.balanceList` | 잔액일람 → `ZANDAKA.RPT` |
| 7 | TESUBAT | `BatchService.feeSummary` | 수수료 집계(non-null 전건) → `TESURYO.RPT` |
| 8 | KYUMBAT | `ReportRepository.dormantAccounts` | 무거래 계좌 → `KYUMIN.RPT` |
| 9 | MASTBAT | `BatchService.masterList` | 마스터 일람 → `KOUZA.LST` |
| 10 | TOKEBAT | `BatchService.stats` | 통계 → `TOKEI.RPT` |

- **파일 7종**은 `app.batch.output-dir`(기본 `./data`, compose에서 호스트로 마운트)에 출력된다.
  6종은 COBOL 서식(자릿수·제로패딩·필러 공백)을 그대로 재현하므로 **파일 대 파일 `diff`가 성립**한다.
- 明細만 `MEISAI.TXT`(텍스트)로 쓴다. COBOL은 `MEISAI.RPT`(98byte 고정 + COMP-3) 바이너리이므로
  이름을 일부러 다르게 해 혼동을 피하고, 대조 시 `tools/parity/meisai_dump.py`가 COBOL 쪽을
  같은 텍스트 포맷으로 변환한다. **98byte·COMP-3은 재도입하지 않는다**(§8 각주 — 바이트 동일성은 검증 범위 밖).

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
- **금액·키 정확도**: 잔액·수수료·이자 계산값, 채번 키의 자릿수/무결성이 정상 타입으로 유지되는지.

### 배치 파리티 — 기계 검증 절차

"업무적으로 일치"는 측정 불가하므로 **① DB 테이블 + ② 帳票 7종의 값을 `diff`로** 확인한다.

```bash
sh tools/parity/compare.sh
# → PARITY OK   DB 2/2 (KOUZA·TORIHIKI) + 帳票 7/7  전부 일치
```

- **① DB 직접 대조**가 "DB에 똑같은 값이 올라갔는가"의 직접 증거다. `KOUZA`(8행: 계좌·명의漢字·명의カナ·
  종별·개설일·상태·잔액)와 `TORIHIKI`(8행: ID·계좌·일시·구분·금액·상대·수수료·적요)를 파이프 구분 문자열로
  뽑아 비교한다. 숫자는 `TO_CHAR`/캐스팅으로 방언 차이를 없애고 NULL은 `-`로 통일한다.
  ⚠️ Oracle 조회 시 **`NLS_LANG=AMERICAN_AMERICA.AL32UTF8` 주입 필수** — `mb-oracle` 컨테이너에는
  `NLS_LANG`이 없어서 sqlplus가 JA16SJIS→클라이언트 변환에서 일본어를 `?`로 깨뜨린다(데이터는 정상).
- **② 帳票 대조**는 그 값을 읽어 만든 산출물까지 같은지 본다.
- **음성 대조군 확인**: PG 잔액을 1원만 틀리게 하면 ①이 즉시 그 줄을 잡아낸다(거짓 통과가 아님을 실증).

1. **픽스처 적용** — `backend-cobol/sql/90_parity_fixture.sql` / `backend-java/.../db/90_parity_fixture.sql`.
   ⚠️ 온라인 이체로 데이터를 만들면 안 된다: `TORIHIKI_DT`가 삽입 시각(wall-clock)이고 그 값이
   明細 D레코드(`MD-TORIHIKI-DT`)에 들어가므로 양쪽 dt가 어긋나 전 줄이 diff된다.
   픽스처는 `TORIHIKI_ID`·`TORIHIKI_DT`를 **리터럴로 고정**한다.
2. **양쪽 배치 실행** → 3. **정규화**(줄끝 공백 제거 + CRLF→LF, 明細은 COMP-3 디코드) → 4. **7개 diff**

**교차검증**(하네스 자체의 버그를 잡는 용도, 전부 실측 확인됨):
- `MEISAI.RPT` 바이트수 == `98 × 레코드수` (1372 = 98×14) — `compare.sh`가 자동 검사
- `cmp TORIHIKI.DAT TORIHIKI.SORTED` **일치** → SORTDAT이 항등 순열임을 실증(§`backend-cobol/README.md` §5)
- `ZANDAKA.RPT`의 `TOTAL BAL` == `TOKEI.RPT`의 `TOTAL BAL` (ZANDABAT/TOKEBAT 독립 코드경로)
- 검산: `Σ배치후잔액(3,613,055) = Σ픽스처잔액(3,613,050) + Σ이자(5)`
- 온라인 `/api/meisai` `afterBal`이 양쪽 동일. ⚠️ **배치 후**에 조회하면 期首를 이자 포함 잔액에서
  역산하므로 배치 `zandakaGo`보다 이자만큼 커진다(양쪽 동일하게 시프트). 배치값과 직접 비교하려면
  배치 **전에** 조회할 것.

> ⚠️ **Windows 함정 2개** (`tools/parity/compare.sh` 에 대응 코드와 이유가 주석으로 있음)
> 1. Git Bash(MSYS)는 `/app/build`·`/nolog` 같은 **단독 인수**를 Windows 경로로 변환해 docker/sqlplus를
>    깨뜨린다(`sh -c '...'` 안에 넣은 경로는 안전). `MSYS_NO_PATHCONV=1`은 반대로 호스트 경로를 깨므로 금물.
> 2. Windows 의 `python3` 은 Microsoft Store 앱 실행 별칭 스텁일 수 있다(실행하면 "Python" 한 줄만 출력).
>    또 리다이렉트 시 로케일 인코딩·CRLF 로 쓰므로 **출력 UTF-8/LF 고정**이 필요하다.

⚠️ **재실행 규율**: 배치는 `newBal = 현재잔액 + 이자`로 **멱등이 아니다**(처리済 플래그 없음).
대조 전에 반드시 픽스처를 재적용한다. 대조 중 온라인 조작 금지 — COBOL 5-10은 별 프로세스라
중간 거래를 보지만 Java는 단일 트랜잭션 스냅샷이라 보지 않는다.

**단위 테스트**(DB·컨테이너 불필요): `MeisaiBuilderTest` / `KanaSortKeyTest` / `ReportWriterTest`.
`MeisaiBuilder`가 순수 함수라 골든값으로 검증한다. `mvn test`
(⚠️ `Dockerfile`은 `-DskipTests`이므로 이미지 빌드로는 테스트가 돌지 않는다).

### 남는 정당한 차이 (일치 불가 — 문서화 대상)

1. **`YAKANBAT`의 `TXR OCCURS 500 TIMES`** — 계좌당 501건째부터 상한 검사 없이 테이블 밖을 침범한다
   (`APPLY-TXN`). Java엔 상한이 없다. 데모 규모 한계로 두고 Java를 500으로 맞추지는 않는다.
2. **트랜잭션 경계** — COBOL은 계좌별 `COMMIT`, Java는 배치 전체 1트랜잭션. 성공 시 동일,
   중간 실패 시 부분반영 vs 전체롤백. **파리티는 성공 실행에 한해** 주장한다.
3. **수치 범위** — COBOL `S9(11)`/Oracle `NUMBER(11)` vs Java `long`/PG `bigint`. 데모 규모에선 도달 불가.
4. **명의 용량** — Oracle `VARCHAR2(40)`은 JA16SJIS 하 *바이트* 의미(≤60byte), PG `varchar(40)`은
   *문자* 의미(최대 120byte). `KanaSortKey`·`ReportWriter`가 COBOL의 60byte 절단을 모델링한다.
5. **`accountsPosted` 의미** — Java는 이자>0 계좌수, COBOL엔 대응 카운터 없음(거래 있는 전 계좌 UPDATE).
   `accountsUpdated`를 추가해 해소. 둘 다 JSON 요약이고 帳票 값이 아니라 대조 대상에서 제외된다.
6. **양쪽 공통이나 업무 검토 필요** — 배치 재실행 시 이자 매회 가산, `JOUTAI='9'`(凍結) 계좌에도
   이자 가산. 픽스처가 계좌 5001415로 이 동작을 의도적으로 고정하므로 한쪽만 "고치면" 대조가 잡아낸다.

> 구 검증의 핵심이던 "코덱 바이트 동일성"(JEF/COMP-3/존10진 RAW 바이트 대조) 스파이크는 2026-07-30 정상화로 대상에서 빠졌다.
> 이제 관점은 "정상 타입 값 정확도 + 일본어 UTF-8 왕복"이다.

---

## 9. 단계별 로드맵

> 온라인 9종 + 배치(明細 포함)는 이식 완료. 아래는 현재 구조 기준의 빌드 경로(정상화 후).

1. **스캐폴딩**: Spring Boot + Maven + PG compose, `application.yml`(UTF-8 강제), DataSource.
2. **스키마/시드**: `schema.sql`(정상 타입) + `seed.sql`(일본어 리터럴 + 숫자값 직접 INSERT).
3. **온라인 수직 슬라이스 1개**: LOGIN 완주(웹→서비스→리포지토리→DB→응답)로 아키텍처 확정.
4. **온라인 나머지 8**: 계약 유지하며 이식, 이체 원자성 집중 검증.
5. **배치**: posting + 明細(D/T) + 帳票 6종 + 파일 7종 출력.
6. **파리티 하네스**: `tools/parity/compare.sh` 로 COBOL 산출물과 7개 diff.
7. **컷오버**: 프론트를 Java 오리진으로.

> (남은 운영화: 서버 배포, 인증/PW 해시, 프로필 컬럼 확장 등 — `ONBOARDING.md` §6 참조.)

---

## 10. 함정 체크리스트

> 구 코덱(COMP-3 부호 니블·존10진 자릿수·20byte 절단·JEF 미매핑·bytea 옵션) 관련 함정은
> 정상 타입 전환으로 대부분 소멸. 현재 유효한 것만:

- [ ] 이체 **원자성**: 실패 시 전체 롤백(잔액 불일치 0).
- [ ] 이자: 普通(종별1)만 `floor(잔액/365000)`, 当座 무이자.
- [ ] 배치 posting 이중 반영 금지(온라인이 이미 실시간 반영 — YAKANBAT은 이자만).
- [ ] **明細 거래 순서 = `(kouza_no, torihiki_id)`** — `取引後残高`가 순서 의존이므로 온라인
      `findByKouza`의 `(dt, id)`와 "통일"하면 COBOL 파리티가 조용히 깨진다.
- [ ] **카나 정렬은 UTF-8 바이트 비교** — `String.compareTo`(UTF-16 코드유닛)나
      `java.text.Collator`(로케일 조합)를 쓰면 안 된다. `Arrays.compareUnsigned` + 60byte 패딩.
- [ ] **期首 = 現残高 − Σdelta 는 posting *이전* 잔액 기준** — 帳票 6종은 반대로 posting *이후* 잔액을 읽는다
      (COBOL 5-10은 YAKANBAT COMMIT 뒤의 별 프로세스).
- [ ] **明細의 `手数料合計`은 区分3만** 집계, `TESUBAT`은 non-null 전건 — 의도적으로 다른 집계다.
- [ ] 일본어 폼 파라미터 디코드 — `application.yml`의 `server.servlet.encoding.force=true` 유지(끄면 폼 일본어 깨질 수 있음).
- [ ] 채번 키 자릿수(계좌 7자리 등)·FK 무결성 유지.
- [ ] 로컬 PG 포트 **5433**(호스트 native PG 5432 충돌 회피, `compose.java.yml`).

---

## 부록 A. 참조

- 스키마/시드 정본(Java): `backend-java/src/main/resources/db/{schema.sql,seed.sql}` (정상 타입, UTF-8)
- COBOL 정본: `backend-cobol/README.md`(§상단 문자셋 현황, §2 API, §5 배치 10단계)
- COBOL 스키마: `backend-cobol/sql/{01_ddl,02_seed,99_reset}.sql` (Oracle JA16SJIS, 정상 타입)
