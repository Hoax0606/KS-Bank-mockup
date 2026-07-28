#!/bin/sh
# ============================================================
#  日次夜間バッチ 実行スクリプト(古典 JCL のステップ分割相当)
#   各ステップを独立プロセスで実行する。特に SORT は Oracle を使う
#   プロセス内で呼ぶと GnuCOBOL がクラッシュするため、SORTDAT/SORTRPT を
#   YAKANBAT とは別プロセスに分離している。
#
#   環境変数:
#     DAT_IN  入力 当日取引(既定 ./data/TORIHIKI.DAT)
#     RPT_OUT 出力 明細レポート(既定 ./data/MEISAI.RPT)
#     ORA_CONN/ORA_USER/ORA_PASS  YAKANBAT の DB 接続
#   実行: backend-cobol/build/ で `sh run_batch.sh`(bin/ が同階層)
# ============================================================
set -e
BIN="$(dirname "$0")/bin"
export DAT_IN="${DAT_IN:-./data/TORIHIKI.DAT}"
export RPT_OUT="${RPT_OUT:-./data/MEISAI.RPT}"
export COB_LIBRARY_PATH="${COB_LIBRARY_PATH:-$(dirname "$0")/lib}"

echo "[batch] (1/4) MKDAT   -> $DAT_IN"
"$BIN/MKDAT"
echo "[batch] (2/4) SORTDAT -> TORIHIKI.SORTED (口座番号順)"
"$BIN/SORTDAT"
echo "[batch] (3/4) YAKANBAT (反映 + KOUZA 更新 + REPORT.WORK)"
"$BIN/YAKANBAT"
echo "[batch] (4/4) SORTRPT -> $RPT_OUT (名義カナ EBCDIC 順, 58byte固定)"
"$BIN/SORTRPT"
echo "[batch] done. records: $(( $(wc -c < "$RPT_OUT") / 58 )) x 58byte"
