# backend-java (Spring Boot + PostgreSQL)

COBOL ASIS 백엔드의 Java 이식. **일반 타입 + 평문 UTF-8 저장** (PostgreSQL=UTF-8).
설계 배경·전체 로드맵은 [`DESIGN.md`](./DESIGN.md) 참조.

> **2026-07-30 전환**: 원래 전 컬럼 RAW(bytea, JEF/COMP-3/존10진 코덱)로 저장했으나,
> 상사 지시(Oracle=Shift-JIS / PostgreSQL=UTF-8)에 따라 **코덱 일체를 폐지**하고 통상 타입
> (`integer`/`bigint`/`numeric`/`varchar`/`char`)으로 정상화했습니다. 일본어는 평문 UTF-8로 저장됩니다.

> 기존 COBOL 백엔드/Oracle 은 그대로 두고, 이 백엔드는 **신규 PostgreSQL** 에 붙어 독립 구동합니다.

## 현재 상태 (기능 이식 완료)

- ✅ 프로젝트 골격 (Spring Boot 3.3 / Java 21 / Maven)
- ✅ **통상 타입 직접 바인딩** — `repository/`가 `JdbcTemplate`으로 `int`/`long`/`String`을 직접
  바인딩(코덱 없음). 과거 `codec/` 패키지(JefCodec/PackedDecimalCodec/ZonedDecimalCodec)와
  `jef4j` 의존성은 삭제됨.
- ✅ PostgreSQL 스키마(전 컬럼 일반 타입, 평문 UTF-8) + 전체 시드(8계좌·10지점·5은행·3공지).
  (구 디코드 뷰 `V_KOUZA`/`V_TORIHIKI`·함수 `fn_unzone`/`fn_unpack`·UTF-8 미러 컬럼은 제거)
- ✅ **온라인 9종** — `login` `signup` `zandaka` `holdings` `meisai` `furikomi` `loan` `repay` `notice` (계약 COBOL 동일, 응답 UTF-8, E2E 검증)
- ✅ **야간배치** — `POST /api/batch/run` (posting + 帳票 6종; COBOL 10스텝 = SORT 2개는 ORDER BY로 흡수)
- ✅ 헬스체크 `GET /api/health`, 예외 핸들러
- ⬜ 남은 것: 프로필 컬럼 확장·인증/보안 강화 등 운영화 (기능 자체는 COBOL 파리티 달성)

## 로컬 실행

```bash
# 1) 컴파일 확인 (DB 불필요)
mvn -q -DskipTests compile

# 2) 전체 스택 (PostgreSQL + 앱) — 리포 루트에서 (COBOL과 동일한 방식)
docker compose -f backend-java/compose.java.yml up -d --build   # 프로젝트명: minibank-java
curl http://localhost:8081/api/health          # {"ok":true,"db":"up",...}

# 3) 앱만 로컬 실행 (PG는 compose로 먼저, 기본 localhost:5433)
mvn spring-boot:run
```

> ⚠️ **포트**: 호스트에 네이티브 PostgreSQL(5432)이 있으면 충돌하므로, compose PG는 **5433**으로 공개하고
> 로컬 앱 기본 접속도 5433입니다. COBOL 스택(8080/1521)과도 안 겹치게 앱은 8081(compose)/기본 8080(로컬)입니다.

> ⚠️ **일본어 폼 입력 테스트**: `application.yml`에서 요청 charset을 UTF-8로 강제합니다. CLI 테스트 시
> Windows `curl.exe`는 명령줄 인자의 일본어를 시스템 코드페이지로 뭉개므로, UTF-8 파일 본문
> (`curl --data-binary @body.txt`)으로 보내야 합니다. (브라우저 프론트는 정상 UTF-8.)

## 레이어

`web`(REST) → `service`(업무) → `repository`(JdbcTemplate, 통상 타입 바인딩) → `batch`.
매핑표·함정 체크리스트는 `DESIGN.md`.
