#!/bin/sh
# ============================================================
#  asis-backend エントリポイント
#   - Oracle 接続情報 / GnuCOBOL ランタイム / GixSQL / Instant Client を
#     環境に用意し、fcgiwrap(CGI 実行) と nginx(配信) を起動する。
# ============================================================
set -e

: "${ORA_CONN:=oracle://oracle:1521/FREEPDB1}"
: "${ORA_USER:=minibank}"
: "${ORA_PASS:=minibank}"
# RAW 無変換通過のための NLS。日本語列は RAW なので文字集合変換を受けない(§2)。
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

# JEF 変換サービス(JEF4J)を起動し、127.0.0.1:$JEF_PORT で待受(CGI が C ブリッジ経由で利用)
export JEF_PORT=9099
( cd /app/jef && java -cp .:jef4j.jar JefServer "$JEF_PORT" >/tmp/jef.log 2>&1 & )
j=0
until nc -z 127.0.0.1 "$JEF_PORT" 2>/dev/null || [ $j -ge 40 ]; do sleep 0.5; j=$((j+1)); done
echo "[entrypoint] JEF service ready on 127.0.0.1:$JEF_PORT"

# fcgiwrap を UNIX ソケットで起動(ORA_* を継承させる)
rm -f /run/fcgiwrap.sock
( spawn-fcgi -s /run/fcgiwrap.sock -M 0666 -- /usr/sbin/fcgiwrap ) || \
  ( fcgiwrap -s unix:/run/fcgiwrap.sock & )
sleep 1

# nginx をフォアグラウンドで
exec nginx -g 'daemon off;'
