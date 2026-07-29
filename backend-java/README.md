# backend-java (Spring Boot + PostgreSQL)

COBOL ASIS 백엔드의 Java 이식. **RAW 바이트 저장(bytea) 유지**, 코덱만 Java 재구현.
설계 배경·전체 로드맵은 [`DESIGN.md`](./DESIGN.md) 참조.

> 기존 COBOL 백엔드/Oracle 은 그대로 두고, 이 백엔드는 **신규 PostgreSQL** 에 붙어 독립 구동합니다.

## 현재 상태 (스캐폴딩)

- ✅ 프로젝트 골격 (Spring Boot 3.3 / Java 21 / Maven)
- ✅ **코덱 3종** — `codec/`: `JefCodec`(JEF EBCDIC), `PackedDecimalCodec`(COMP-3), `ZonedDecimalCodec`(존10진)
- ✅ **바이트 동일성 테스트** — `CodecByteIdentityTest` (라이브 DB 실측 hex와 대조)
- ✅ PostgreSQL 스키마(`db/schema.sql`, 전 컬럼 bytea) + 스타터 시드(`db/seed.sql`, 2계좌)
- ✅ 헬스체크 `GET /api/health`, 예외 핸들러
- ⬜ 업무 엔드포인트(login/furikomi/meisai …), repository, 배치 — 다음 단계

## 로컬 실행

```bash
# 1) 코덱 테스트만 (DB 불필요)
mvn -q test

# 2) 전체 스택 (PostgreSQL + 앱)
docker compose -f compose.java.yml up -d --build
curl http://localhost:8081/api/health          # {"ok":true,"db":"up",...}

# 3) 앱만 로컬 실행 (PG는 별도 기동, 기본 localhost:5432)
mvn spring-boot:run
```

## 레이어 (예정)

`web`(REST) → `service`(업무) → `repository`(JdbcTemplate, bytea 바인딩) + `codec`(핵심) + `batch`.
매핑표·함정 체크리스트는 `DESIGN.md` §5·§6·§10.

## 다음 작업 순서 (DESIGN.md §9)

1. 코덱 테스트 green 확인 → 2. 전체 시드 생성(Oracle hex 기계치환) → 3. **LOGIN 수직 슬라이스**
(web→service→repository→codec→PG→디코드 응답)로 아키텍처 확정 → 4. 온라인 나머지 → 5. 배치.
