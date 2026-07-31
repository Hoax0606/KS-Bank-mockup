#!/bin/sh
# ============================================================
#  日次夜間バッチ 実行スクリプト(古典 JCL のステップ分割相当)  10ステップ
#   各ステップを独立プロセスで実行する。特に SORT は Oracle を使う
#   プロセス内で呼ぶと GnuCOBOL がクラッシュするため、SORTDAT/SORTRPT を
#   YAKANBAT とは別プロセスに分離している。
#
#   [コア反映]  1 MKDAT  2 SORTDAT  3 YAKANBAT  4 SORTRPT
#   [日次帳票]  5 NIPPO(取引日報) 6 ZANDA(残高一覧) 7 TESU(手数料集計)
#               8 KYUM(休眠口座)  9 MAST(マスタ一覧) 10 TOKE(統計サマリ)
#   ※ 5-10 は読取専用(DB 更新なし)。全ステップ ./data/ に出力。
#
#   環境変数(既定は ./data/ 配下):
#     DAT_IN / RPT_OUT / NIPPO_OUT / ZANDA_OUT / TESU_OUT /
#     KYUM_OUT / MAST_OUT / TOKE_OUT
#     ORA_CONN/ORA_USER/ORA_PASS  DB 接続(SQL ステップ)
#   実行: backend-cobol/build/ で `sh run_batch.sh`(bin/ が同階層)
# ============================================================
set -e
BIN="$(dirname "$0")/bin"
export DAT_IN="${DAT_IN:-./data/TORIHIKI.DAT}"
export RPT_OUT="${RPT_OUT:-./data/MEISAI.RPT}"
export NIPPO_OUT="${NIPPO_OUT:-./data/NIPPO.RPT}"
export ZANDA_OUT="${ZANDA_OUT:-./data/ZANDAKA.RPT}"
export TESU_OUT="${TESU_OUT:-./data/TESURYO.RPT}"
export KYUM_OUT="${KYUM_OUT:-./data/KYUMIN.RPT}"
export MAST_OUT="${MAST_OUT:-./data/KOUZA.LST}"
export TOKE_OUT="${TOKE_OUT:-./data/TOKEI.RPT}"
export COB_LIBRARY_PATH="${COB_LIBRARY_PATH:-$(dirname "$0")/lib}"

# ---- コア反映(データ更新あり) ----
echo "[batch] (1/10) MKDAT    -> $DAT_IN"
"$BIN/MKDAT"
echo "[batch] (2/10) SORTDAT  -> TORIHIKI.SORTED (口座番号順)"
"$BIN/SORTDAT"
echo "[batch] (3/10) YAKANBAT (反映 + KOUZA 更新 + REPORT.WORK)"
"$BIN/YAKANBAT"
echo "[batch] (4/10) SORTRPT  -> $RPT_OUT (名義カナ順, 98byte固定/ネイティブ)"
"$BIN/SORTRPT"
echo "[batch] core done. meisai records: $(( $(wc -c < "$RPT_OUT") / 98 )) x 98byte"

# ---- 日次帳票(読取専用) ----
echo "[batch] (5/10) NIPPOBAT -> $NIPPO_OUT (取引日報: 区分別集計)"
"$BIN/NIPPOBAT"
echo "[batch] (6/10) ZANDABAT -> $ZANDA_OUT (残高一覧)"
"$BIN/ZANDABAT"
echo "[batch] (7/10) TESUBAT  -> $TESU_OUT (振込手数料集計)"
"$BIN/TESUBAT"
echo "[batch] (8/10) KYUMBAT  -> $KYUM_OUT (休眠口座抽出)"
"$BIN/KYUMBAT"
echo "[batch] (9/10) MASTBAT  -> $MAST_OUT (口座マスタ一覧)"
"$BIN/MASTBAT"
echo "[batch] (10/10) TOKEBAT -> $TOKE_OUT (統計サマリ)"
"$BIN/TOKEBAT"
echo "[batch] all 10 steps done."
