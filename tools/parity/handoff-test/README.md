# 상대방(제3자) 검증용 핸드오프 세트

다른 사람이 만드는 **COBOL→Java 비교 도구**가 실제로 값 차이를 잡아내는지 시험하기 위한
의도적 오류 주입 픽스처. 이 폴더 안에서 무엇을 주고 무엇을 주지 말지 구분해서 전달할 것.

## 상대방에게 줄 것

1. **`backend-cobol/`** 폴더 전체 (`cobol/`, `sql/`, `docker/`) — ASIS COBOL 배치 10개 소스와
   빌드/실행 환경. 상대방이 직접 빌드해서 "정답 COBOL 출력"을 스스로 뽑아내야 한다.
2. **ASIS 배치 10개 Input/Output 명세** (별도 전달된 문서) — Java를 새로 짤 때 각 배치가
   뭘 읽고 뭘 써야 하는지의 근거.
3. **이 폴더의 `cobol_fixture.sql` + `java_fixture.sql`** — COBOL/Java 각각에 적용할
   테스트 데이터. 아래 "실행 방법"대로 적용.

## 상대방에게 절대 주지 말 것

- **`ANSWER-KEY.md`** (이 폴더, 본인 전용) — 어디를 일부러 틀리게 했는지 적힌 정답지.
- **`backend-java/`** (이미 완성된 정답 Java 구현) — 주면 상대방이 그냥 베낄 수 있어 테스트가
  무의미해진다.
- **`tools/parity/compare.sh` / `meisai_dump.py`** (이 프로젝트가 이미 만든 비교 도구 자체) —
  상대방이 "자기 도구"를 만들어야 시험이 되는 것이므로.

## 실행 방법

```bash
# COBOL 쪽 (Oracle) — 정답 데이터
sqlplus -s minibank/minibank@//localhost:1521/XEPDB1 @cobol_fixture.sql

# Java 쪽 (PostgreSQL) — 의도적으로 1곳 틀린 데이터
docker exec -i mbj-postgres psql -U minibank -d minibank < java_fixture.sql
```

이후 COBOL 배치 10단계와 Java 배치를 각각 돌려 나온 7개 리포트를, 상대방이 만든 도구로
비교시킨다. 정답(어디가 얼마나 달라야 하는지)은 `ANSWER-KEY.md`에만 있다.
