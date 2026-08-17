#!/bin/sh
# ============================================================
#  日次夜間バッチ 実行スクリプト — backend-cobol/build/run_batch.sh の
#  Java 1:1 이식판. 10 스텝을 "10개의 독립 JVM 프로세스"로 순차 실행한다
#  (한 JVM 안에서 메서드만 순서대로 호출하지 않는다 — 각 프로그램이 자체
#  DB 커넥션을 열고 닫는 독립 실행 단위라는 구조적 사실 자체가 이 모듈의
#  존재 이유이므로, ps/로그에서 실제로 10번의 프로세스 시작/종료가 보여야 한다).
#
#   [コア反映]  1 MKDAT  2 SORTDAT  3 YAKANBAT  4 SORTRPT
#   [日次帳票]  5 NIPPOBAT 6 ZANDABAT 7 TESUBAT 8 KYUMBAT 9 MASTBAT 10 TOKEBAT
#
#   환경변수(기본은 ./data/ 하위 — COBOL 원본과 동일한 이름):
#     DAT_IN / RPT_OUT / NIPPO_OUT / ZANDA_OUT / TESU_OUT /
#     KYUM_OUT / MAST_OUT / TOKE_OUT
#     DB_URL / DB_USER / DB_PASS  DB 接続
#   실행: backend-java-strict/(컨테이너 내 /app) 에서 `sh run_batch.sh`
# ============================================================
set -e
CP="$(dirname "$0")/classes:$(dirname "$0")/dependency/*"
PKG=com.ksbank.minibank.strict.batch

export DAT_IN="${DAT_IN:-./data/TORIHIKI.DAT}"
export RPT_OUT="${RPT_OUT:-./data/MEISAI.RPT}"
export NIPPO_OUT="${NIPPO_OUT:-./data/NIPPO.RPT}"
export ZANDA_OUT="${ZANDA_OUT:-./data/ZANDAKA.RPT}"
export TESU_OUT="${TESU_OUT:-./data/TESURYO.RPT}"
export KYUM_OUT="${KYUM_OUT:-./data/KYUMIN.RPT}"
export MAST_OUT="${MAST_OUT:-./data/KOUZA.LST}"
export TOKE_OUT="${TOKE_OUT:-./data/TOKEI.RPT}"
export DB_URL="${DB_URL:-jdbc:postgresql://localhost:5435/minibankstrict}"
export DB_USER="${DB_USER:-minibank}"
export DB_PASS="${DB_PASS:-minibank}"

mkdir -p ./data

echo "[batch] (1/10) MKDAT    -> $DAT_IN"
java -cp "$CP" $PKG.mkdat.Mkdat
echo "[batch] (2/10) SORTDAT  -> TORIHIKI.SORTED (口座番号順, 하드코딩 리터럴 파일명 — COBOL과 동일)"
java -cp "$CP" $PKG.sortdat.Sortdat
echo "[batch] (3/10) YAKANBAT (反映 + KOUZA 계좌별 즉시 UPDATE+COMMIT + REPORT.WORK)"
java -cp "$CP" $PKG.yakanbat.Yakanbat
echo "[batch] (4/10) SORTRPT  -> $RPT_OUT (名義カナ順, 98byte固定/ネイティブ)"
java -cp "$CP" $PKG.sortrpt.Sortrpt
echo "[batch] core done. meisai records: $(( $(wc -c < "$RPT_OUT") / 98 )) x 98byte"

echo "[batch] (5/10) NIPPOBAT -> $NIPPO_OUT (取引日報: 区分別集計)"
java -cp "$CP" $PKG.nippobat.Nippobat
echo "[batch] (6/10) ZANDABAT -> $ZANDA_OUT (残高一覧)"
java -cp "$CP" $PKG.zandabat.Zandabat
echo "[batch] (7/10) TESUBAT  -> $TESU_OUT (振込手数料集計)"
java -cp "$CP" $PKG.tesubat.Tesubat
echo "[batch] (8/10) KYUMBAT  -> $KYUM_OUT (休眠口座抽出)"
java -cp "$CP" $PKG.kyumbat.Kyumbat
echo "[batch] (9/10) MASTBAT  -> $MAST_OUT (口座マスタ一覧)"
java -cp "$CP" $PKG.mastbat.Mastbat
echo "[batch] (10/10) TOKEBAT -> $TOKE_OUT (統計サマリ)"
java -cp "$CP" $PKG.tokebat.Tokebat
echo "[batch] all 10 steps done."
