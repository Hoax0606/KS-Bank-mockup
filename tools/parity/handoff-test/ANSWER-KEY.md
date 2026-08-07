# 정답지 — 본인 전용, 상대방(테스트 대상자)에게 절대 전달하지 말 것

이 폴더의 `cobol_fixture.sql`(정답, 무변경)과 `java_fixture.sql`(복사본, 1곳 변경)은
상대방이 만드는 **COBOL→Java 비교 도구가 실제로 값 차이를 잡아내는지** 검증하기 위한
의도적 오류 주입 세트다.

## 무엇을 바꿨나

`java_fixture.sql`에서만 거래 `TORIHIKI_ID = 100000000007` (계좌 `4001213`, 구분=3 振込,
KINGAKU=1000, 상대계좌=3000789)의 **TESURYO(수수료)를 110 → 90으로 변경**.
`cobol_fixture.sql`은 원본 그대로 110.

| 필드 | cobol_fixture.sql (정답) | java_fixture.sql (변경) |
|---|---|---|
| TESURYO (TORIHIKI_ID=100000000007) | 110 | **90** |

## 반드시 달라져야 하는 출력 (2개)

- **`TESURYO.RPT`** (7 TESUBAT) — `FEE COUNT=`는 동일(TESURYO가 NULL이 아닌 거래는 전체
  8건 중 2건뿐: 100000000003과 100000000007), `TOTAL=`이 COBOL은 220, Java는 200으로
  달라짐(100000000003의 110은 안 건드렸으므로 동일, 100000000007만 110→90).
  ★실제로 양쪽 배치를 돌려 확인함: COBOL `FEE COUNT=0000002 TOTAL=0000000000220`,
  Java `FEE COUNT=0000002 TOTAL=0000000000200`.
- **`MEISAI.RPT`** (3-4 YAKANBAT/SORTRPT 산출) — 계좌 `4001213`의 T레코드
  `MT-TESURYO-GK`(手数料合計)가 COBOL=110, Java=90으로 달라짐.
  (`4001213`은 이 거래 1건뿐이라 계좌 합계 = 거래 자체 금액)

## 절대 달라지면 안 되는 출력

리포트 7종 중 나머지 5종: `NIPPO.RPT`, `ZANDAKA.RPT`, `KYUMIN.RPT`, `KOUZA.LST`, `TOKEI.RPT`.
그리고 `MEISAI.RPT`/`MEISAI.TXT` 안에서도 `4001213` **외의 다른 계좌 라인**은 전부 동일.
→ TESURYO는 NIPPOBAT/ZANDABAT/KYUMBAT/MASTBAT/TOKEBAT 어느 SELECT에도 들어가지 않으므로
  (각 프로그램 소스 확인됨) 이 5개 리포트는 절대 영향받지 않는다.

★실제로 이 두 픽스처로 COBOL·Java 배치를 둘 다 돌려서 7개 리포트를 전부 diff해 확인함:
`MEISAI.TXT`·`TESURYO.RPT`만 diff 발생, 나머지 5개(`NIPPO.RPT`,`ZANDAKA.RPT`,`KYUMIN.RPT`,
`KOUZA.LST`,`TOKEI.RPT`)는 완전 일치. 설계대로 정확히 동작함.

## 상대방 도구 결과 채점 체크리스트

- [ ] `TESURYO.RPT` 차이를 잡아냈는가? (110 vs 90 계열의 TOTAL 불일치)
- [ ] `MEISAI.RPT`의 계좌 4001213 T레코드 차이를 잡아냈는가?
- [ ] 위 2개 **외의** 파일에서는 "다르다"고 오탐하지 않았는가? (오탐도 도구 부실의 증거)
- [ ] 차이가 있다고만 뭉뚱그리지 않고, 어느 파일/어느 값이 다른지 구체적으로 짚어주는가?

## 실행 순서 (본인이 먼저 셀프 검증할 때)

1. `sqlplus -s minibank/minibank@//localhost:1521/XEPDB1 @cobol_fixture.sql`
2. COBOL 배치 10단계 실행 (`backend-cobol/README.md` §4.2 참고)
3. `docker exec -i mbj-postgres psql -U minibank -d minibank < java_fixture.sql`
4. Java 배치 실행 (`POST /api/batch/run`)
5. 7개 리포트 diff — 위 "반드시 달라져야 하는 출력 2개"만 다르고 나머지 5개는
   동일한지 직접 확인 (이 리포지토리의 `tools/parity/compare.sh` 방식 재사용 가능,
   단 대상 DB를 이 폴더의 두 픽스처로 바꿔서 실행). 이미 한 번 확인 완료 — 위 참고.
