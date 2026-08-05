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
# DB는 JA16SJIS 저장이나 GixSQL 드라이버가 취득 시 UTF-8로 강제 변환한다
# (NLS_LANG는 실질 무시됨). 응답은 UTF-8.
: "${NLS_LANG:=AMERICAN_AMERICA.AL32UTF8}"

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
