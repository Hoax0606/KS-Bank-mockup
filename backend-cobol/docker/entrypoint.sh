#!/bin/sh
# ============================================================
#  asis-backend エントリポイント
#   - Oracle 接続情報 / GnuCOBOL ランタイム / GixSQL / Instant Client を
#     環境に用意し、fcgiwrap(CGI 実行) と nginx(配信) を起動する。
# ============================================================
set -e

: "${ORA_CONN:=oracle://oracle:1521/XEPDB1}"
: "${ORA_USER:=minibank}"
: "${ORA_PASS:=minibank}"
# ★2026-08 Shift-JIS 재전환: Instant Client를 Basic(비-Lite)으로 바꾸면서
#   클라이언트 문자셋이 실제로 JA16SJIS를 따라간다. DB 저장(JA16SJIS)과
#   앱/응답이 이제 전부 Shift-JIS. TILDE 변종을 클라이언트가 못 받으면
#   JA16SJIS로 낮출 것(§ backend-cobol/README.md 참조).
: "${NLS_LANG:=JAPANESE_JAPAN.JA16SJISTILDE}"

export ORA_CONN ORA_USER ORA_PASS NLS_LANG
# GnuCOBOL がサブモジュール(.so)を探すパス
export COB_LIBRARY_PATH=/app/build/lib
export LD_LIBRARY_PATH=/opt/oracle/instantclient:${GIXHOME:-/opt/gixsql}/lib:${LD_LIBRARY_PATH}

echo "[entrypoint] ORA_CONN=$ORA_CONN COB_LIBRARY_PATH=$COB_LIBRARY_PATH"

# Oracle 起動待ち(簡易)
i=0
until nc -z oracle 1521 2>/dev/null || [ $i -ge 60 ]; do
  echo "[entrypoint] waiting for oracle:1521 ..."; sleep 3; i=$((i+1));
done

# (JEF 変換サービ스는 Shift-JIS 전환으로 폐지 — 더 이상 기동하지 않음)

# fcgiwrap を UNIX ソケットで起動(ORA_* を継承させる)
rm -f /run/fcgiwrap.sock
( spawn-fcgi -s /run/fcgiwrap.sock -M 0666 -- /usr/sbin/fcgiwrap ) || \
  ( fcgiwrap -s unix:/run/fcgiwrap.sock & )
sleep 1

# nginx をフォアグラウンドで
exec nginx -g 'daemon off;'
