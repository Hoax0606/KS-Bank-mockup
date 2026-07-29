# backend-java (Spring Boot + PostgreSQL)

COBOL ASIS 백엔드의 Java 이식. **RAW 바이트 저장(bytea) 유지**, 코덱만 Java 재구현.
설계 배경·전체 로드맵은 [`DESIGN.md`](./DESIGN.md) 참조.

> 기존 COBOL 백엔드/Oracle 은 그대로 두고, 이 백엔드는 **신규 PostgreSQL** 에 붙어 독립 구동합니다.

## 현재 상태 (기능 이식 완료)

- ✅ 프로젝트 골격 (Spring Boot 3.3 / Java 21 / Maven)
- ✅ **코덱 3종** — `codec/`: `JefCodec`(JEF EBCDIC), `PackedDecimalCodec`(COMP-3), `ZonedDecimalCodec`(존10진) + 헬퍼 `Fields`(디코드)/`Enc`(인코드). 바이트 동일성 테스트 통과.
- ✅ PostgreSQL 스키마(전 컬럼 bytea) + 전체 시드(8계좌·10지점·5은행·3공지) + 디코드 뷰 `V_KOUZA`/`V_TORIHIKI`
- ✅ **온라인 9종** — `login` `signup` `zandaka` `holdings` `meisai` `furikomi` `loan` `repay` `notice` (계약·바이트 COBOL 동일, E2E 검증)
- ✅ **야간배치** — `POST /api/batch/run` (posting + 帳票 6종; COBOL 10스텝 = SORT 2개는 ORDER BY로 흡수)
- ✅ 헬스체크 `GET /api/health`, 예외 핸들러
- ⬜ 남은 것: 프로필 컬럼 확장·인증/보안 강화 등 운영화 (기능 자체는 COBOL 파리티 달성)

## 로컬 실행

```bash
# 1) 코덱 테스트만 (DB 불필요) — 바이트 동일성 9개
mvn -q test

# 2) 전체 스택 (PostgreSQL + 앱)
docker compose -f compose.java.yml up -d --build
curl http://localhost:8081/api/health          # {"ok":true,"db":"up",...}

# 3) 앱만 로컬 실행 (PG는 compose로 먼저, 기본 localhost:5433)
mvn spring-boot:run
```

> ⚠️ **포트**: 호스트에 네이티브 PostgreSQL(5432)이 있으면 충돌하므로, compose PG는 **5433**으로 공개하고
> 로컬 앱 기본 접속도 5433입니다. COBOL 스택(8080/1521)과도 안 겹치게 앱은 8081(compose)/기본 8080(로컬)입니다.

## 레이어 (예정)

`web`(REST) → `service`(업무) → `repository`(JdbcTemplate, bytea 바인딩) + `codec`(핵심) + `batch`.
매핑표·함정 체크리스트는 `DESIGN.md` §5·§6·§10.

## 다음 작업 순서 (DESIGN.md §9)

1. 코덱 테스트 green 확인 → 2. 전체 시드 생성(Oracle hex 기계치환) → 3. **LOGIN 수직 슬라이스**
(web→service→repository→codec→PG→디코드 응답)로 아키텍처 확정 → 4. 온라인 나머지 → 5. 배치.
