# ASIS COBOL 야간배치 10단계 — Input/Output 명세

전체 실행 순서는 `backend-cobol/build/run_batch.sh`(구 JCL의 스텝 분할에 상당하는 셸 스크립트)가 고정한다.
1~4단계는 **코어반영**(DB를 실제로 갱신), 5~10단계는 **일일제표**(읽기전용).

| # | 배치 | Input | Output | 비고 |
|---|---|---|---|---|
| 1 | MKDAT | `TORIHIKI`(Oracle DB) — `SELECT TORIHIKI_ID,KOUZA_NO,TORIHIKI_DT,TORIHIKI_KBN,KINGAKU,AITE_KOUZA,TESURYO,TEKIYOU ORDER BY KOUZA_NO,TORIHIKI_ID` | `TORIHIKI.DAT` — 97byte 고정길이 파일 | 계좌번호 7→10자리 제로패딩. YAKANBAT의 입력이 되는 시작점 |
| 2 | SORTDAT | `TORIHIKI.DAT`(97byte) | `TORIHIKI.SORTED`(97byte) | 정렬키: 계좌번호(1키)+거래ID(2키). 이미 정렬된 입력이라 사실상 항등변환 |
| 3 | YAKANBAT | `TORIHIKI.SORTED`(97byte) + `KOUZA`(DB, 계좌별 `MEIGI_KANJI,MEIGI_KANA,SHUBETSU,ZANDAKA`) | `REPORT.WORK`(164byte) **+ `KOUZA.ZANDAKA` UPDATE (DB, 이자 반영)** | 10단계 중 유일하게 DB에 쓰기가 발생. 계좌별 커밋 |
| 4 | SORTRPT | `REPORT.WORK`(164byte) | `MEISAI.RPT` — 98byte 고정길이, D(明細)/T(계좌합계) 레코드 | 정렬키: 명의카나(Shift-JIS 바이트순, 2026-08부터) |
| 5 | NIPPOBAT | `TORIHIKI`(DB, 전건) | `NIPPO.RPT` — 텍스트 3줄 (구분 1/2/3별 건수+합계) | 읽기전용 |
| 6 | ZANDABAT | `KOUZA`(DB, 계좌번호순 전체) | `ZANDAKA.RPT` — 텍스트, 계좌당 1줄 + TOTAL줄 | 읽기전용 |
| 7 | TESUBAT | `TORIHIKI.TESURYO`(DB, NULL 아닌 것만) | `TESURYO.RPT` — 텍스트 1줄 (건수+합계) | 읽기전용 |
| 8 | KYUMBAT | `KOUZA`+`TORIHIKI`(DB, 거래 0건 계좌 조회) | `KYUMIN.RPT` — 텍스트, 계좌당 1줄 | 읽기전용 |
| 9 | MASTBAT | `KOUZA`(DB, 계좌번호순, 개설일 포함) | `KOUZA.LST` — 텍스트, 계좌당 1줄 | 읽기전용 |
| 10 | TOKEBAT | `KOUZA`(DB, 전체) + `TORIHIKI` 건수(DB) | `TOKEI.RPT` — 텍스트 6줄 요약 | 읽기전용 |

근거 소스: `backend-cobol/cobol/{MKDAT,SORTDAT,YAKANBAT,SORTRPT,NIPPOBAT,ZANDABAT,TESUBAT,KYUMBAT,MASTBAT,TOKEBAT}.cbl`,
레코드 레이아웃은 `backend-cobol/cobol/copy/WTRDAT.cpy`(TORIHIKI.DAT/SORTED), `copy/WMEISAI.cpy`(MEISAI.RPT).

## 인코딩 관련 중요 정정 (2026-08 갱신 — 이전 결론을 뒤집음)

이 문서를 처음 쓸 때는 GixSQL 드라이버가 클라이언트 문자셋을 UTF-8로 강제해서, COBOL이 실제로 만드는
파일(`TORIHIKI.DAT`, `REPORT.WORK`, `MEISAI.RPT`)의 한자/카나 필드가 UTF-8이라고 결론 냈었다. 그
원인을 더 파보니 두 겹이었다: **Oracle Instant Client가 "Basic Lite"**(문자셋 변환 데이터
`libociei.so`가 통째로 없는 경량판)인 것도 한 원인이었지만, Basic으로 바꿔도 안 고쳐졌다 — **GixSQL
자체가 ODPI-C 연결 시 encoding을 "UTF-8"로 하드코딩**하고 있어서 `NLS_LANG`이 통째로 무시되고
있었다(`docker/vendor/gixsql-oracle-nls-lang.patch`로 수정). 매니저 지시("ASIS는 무조건 Shift-JIS —
앱/파일 레벨까지")에 따라 Basic 패키지 교체 + 이 패치 + `NLS_LANG=JAPANESE_JAPAN.JA16SJISTILDE`
세 가지를 다 적용해서 전환했다.

**현재(2026-08 이후) 결론**: DB 컬럼 저장(`JA16SJIS`)뿐 아니라, COBOL이 실제로 만드는 배치 파일의
한자/카나 필드도 **전부 Shift-JIS**다. "DB만 S-JIS, 파일 내용은 UTF-8"이라던 위 예전 결론은 더 이상
유효하지 않다. Java(to-be)는 이 변경과 무관하게 계속 UTF-8이므로, COBOL↔Java 대조 시 `tools/parity/
meisai_dump.py`가 CP932→UTF-8 변환을 대신 해준다(§관련 자료).

## 실행 환경변수

| 변수 | 의미 |
|---|---|
| `DAT_IN` | TORIHIKI.DAT 경로 (기본 `./data/TORIHIKI.DAT`) |
| `RPT_OUT` | MEISAI.RPT 경로 |
| `NIPPO_OUT` / `ZANDA_OUT` / `TESU_OUT` / `KYUM_OUT` / `MAST_OUT` / `TOKE_OUT` | 각 리포트 파일 경로 |
| `ORA_CONN` / `ORA_USER` / `ORA_PASS` | Oracle 접속 정보 (배치는 `docker exec` 실행 시 매번 주입 필요) |
| `NLS_LANG` | `JAPANESE_JAPAN.JA16SJISTILDE` — 이것도 `docker exec` 시 매번 주입 필요(누락 시 UTF-8로 조용히 전환됨) |

## 관련 자료

- COBOL→Java 비교 도구 검증용 (의도적 오류 주입) 픽스처: `tools/parity/handoff-test/`
- 이 프로젝트 자체의 COBOL↔Java 1:1 대조 하네스: `tools/parity/compare.sh`
