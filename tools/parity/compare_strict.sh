#!/bin/sh
# ============================================================
#  COBOL ↔ backend-java-strict 야간배치 1:1 값 대조 하네스
#
#  ★기존 tools/parity/compare.sh(COBOL↔기존 backend-java)는 건드리지 않는다★
#    이미 검증된 스크립트를 구조가 다른 3번째 대상 때문에 손대지 않기 위해
#    별도 스크립트로 둔다.
#
#  backend-java-strict 는 COBOL과 같은 Shift-JIS/COMP-3 네이티브 바이트로
#  MEISAI.RPT 를 쓰므로, compare.sh 와 달리 meisai_dump.py 변환 없이
#  raw cmp 로 바로 바이트 대조한다 — 더 강한 parity 증거.
#
#  실행 (리포지토리 루트에서):
#      sh tools/parity/compare_strict.sh
#
#  ☠ 라이브/데모 서버에서는 실행 금지 ☠ (파리티 픽스처가 TORIHIKI 전건 삭제)
#
#  전제
#    - COBOL 스택 기동:          docker compose -f backend-cobol/docker/compose.asis.yml up -d
#    - backend-java-strict 기동: docker compose -f backend-java-strict/compose.strict.yml up -d
# ============================================================
set -e

COBOL_APP="${COBOL_APP:-mb-cobol-sjis}"
COBOL_ORA="${COBOL_ORA:-oracle_sjis}"
STRICT_APP="${STRICT_APP:-mbjs-app}"
STRICT_PG="${STRICT_PG:-mbjs-postgres}"
ORA_DSN="${ORA_DSN:-minibank/minibank@//localhost:1521/XEPDB1}"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/parity/out_strict"
TEXT_FILES="NIPPO.RPT ZANDAKA.RPT TESURYO.RPT KYUMIN.RPT KOUZA.LST TOKEI.RPT"
TABLES="KOUZA TORIHIKI"

say() { printf '\n=== %s\n' "$1"; }

ora_sql() {
  docker exec -i -e NLS_LANG=AMERICAN_AMERICA.AL32UTF8 "$COBOL_ORA" \
    sqlplus -s "$ORA_DSN"
}
pg_sql() { docker exec -i "$STRICT_PG" psql -U minibank -d minibankstrict -At; }
norm_rows() { sed -e 's/\r$//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"; }

rm -rf "$OUT"; mkdir -p "$OUT/cobol" "$OUT/strict" "$OUT/raw"

# ------------------------------------------------------------
say "1/6  픽스처 적용 (Oracle)"
docker exec -i "$COBOL_ORA" sqlplus -s "$ORA_DSN" \
  < "$ROOT/backend-cobol/sql/90_parity_fixture.sql" \
  > "$OUT/fixture_oracle.log" 2>&1
if grep -qE '^(ORA|SP2)-' "$OUT/fixture_oracle.log"; then
  echo "  !! Oracle 픽스처 오류 — $OUT/fixture_oracle.log 확인"; exit 1
fi
ora_cnt=$(docker exec -i "$COBOL_ORA" sqlplus -s "$ORA_DSN" <<'SQL' | tr -d ' \t\r\n'
SET PAGES 0 FEED OFF
SELECT COUNT(*) FROM TORIHIKI;
EXIT
SQL
)
echo "  TORIHIKI=$ora_cnt (expect 8)"
[ "$ora_cnt" = "8" ] || { echo "  !! Oracle 픽스처 미적용"; exit 1; }

say "2/6  픽스처 적용 (backend-java-strict / PostgreSQL)"
docker exec -i "$STRICT_PG" psql -U minibank -d minibankstrict -q -v ON_ERROR_STOP=1 \
  < "$ROOT/backend-java-strict/src/main/resources/db/90_parity_fixture.sql" \
  > "$OUT/fixture_pg.log" 2>&1
tail -8 "$OUT/fixture_pg.log"

# ------------------------------------------------------------
say "3/6  COBOL 배치 실행 (10 스텝)"
docker exec -i \
  -e NLS_LANG=JAPANESE_JAPAN.JA16SJISTILDE \
  "$COBOL_APP" sh -c 'cd /app/build && mkdir -p data && sh run_batch.sh'

say "4/6  backend-java-strict 배치 실행 (10개 독립 JVM 프로세스)"
docker exec "$STRICT_APP" sh run_batch.sh

# ------------------------------------------------------------
say "5/6  DB 직접 대조 (KOUZA / TORIHIKI)"
ora_sql > "$OUT/raw/ora_KOUZA.txt" 2>&1 <<'SQL'
SET PAGES 0 FEED OFF HEAD OFF TRIMS ON LIN 400
SELECT TO_CHAR(KOUZA_NO)||'|'||MEIGI_KANJI||'|'||MEIGI_KANA||'|'||SHUBETSU||'|'
       ||KAISETSU_BI||'|'||JOUTAI||'|'||TO_CHAR(ZANDAKA)
  FROM KOUZA ORDER BY KOUZA_NO;
EXIT
SQL
pg_sql > "$OUT/raw/pg_KOUZA.txt" 2>&1 <<'SQL'
SELECT kouza_no||'|'||meigi_kanji||'|'||meigi_kana||'|'||shubetsu||'|'
       ||kaisetsu_bi||'|'||joutai||'|'||zandaka
  FROM kouza ORDER BY kouza_no;
SQL
ora_sql > "$OUT/raw/ora_TORIHIKI.txt" 2>&1 <<'SQL'
SET PAGES 0 FEED OFF HEAD OFF TRIMS ON LIN 400
SELECT TO_CHAR(TORIHIKI_ID)||'|'||TO_CHAR(KOUZA_NO)||'|'||TORIHIKI_DT||'|'
       ||TORIHIKI_KBN||'|'||TO_CHAR(KINGAKU)||'|'||NVL(TO_CHAR(AITE_KOUZA),'-')
       ||'|'||NVL(TO_CHAR(TESURYO),'-')||'|'||NVL(TEKIYOU,'-')
  FROM TORIHIKI ORDER BY KOUZA_NO, TORIHIKI_ID;
EXIT
SQL
pg_sql > "$OUT/raw/pg_TORIHIKI.txt" 2>&1 <<'SQL'
SELECT torihiki_id||'|'||kouza_no||'|'||torihiki_dt||'|'||torihiki_kbn||'|'
       ||kingaku||'|'||COALESCE(aite_kouza::text,'-')||'|'
       ||COALESCE(tesuryo::text,'-')||'|'||COALESCE(tekiyou,'-')
  FROM torihiki ORDER BY kouza_no, torihiki_id;
SQL

db_rc=0
for t in $TABLES; do
  norm_rows "$OUT/raw/ora_$t.txt" > "$OUT/cobol/$t.rows"
  norm_rows "$OUT/raw/pg_$t.txt"  > "$OUT/strict/$t.rows"
  n=$(wc -l < "$OUT/cobol/$t.rows" | tr -d ' ')
  if [ "$n" -eq 0 ]; then
    db_rc=1; echo "  FAIL  $t  (Oracle 조회 결과 0행)"
  elif diff -u "$OUT/cobol/$t.rows" "$OUT/strict/$t.rows" > "$OUT/DB_$t.diff"; then
    rm -f "$OUT/DB_$t.diff"; echo "  OK    $t  ($n 행 완전 일치)"
  else
    db_rc=1; echo "  DIFF  $t  -> $OUT/DB_$t.diff"
    sed -n '1,20p' "$OUT/DB_$t.diff" | sed 's/^/        /'
  fi
done

# ------------------------------------------------------------
say "6/6  帳票 대조"
docker exec -i "$COBOL_APP" sh -c 'cd /app/build/data && tar cf - .' \
  | tar xf - -C "$OUT/raw/cobol_reports" 2>/dev/null || \
  { mkdir -p "$OUT/raw/cobol_reports"; docker exec -i "$COBOL_APP" sh -c 'cd /app/build/data && tar cf - .' | tar xf - -C "$OUT/raw/cobol_reports"; }
docker exec -i "$STRICT_APP" sh -c 'cd /app/data && tar cf - .' \
  | tar xf - -C "$OUT/raw" 2>/dev/null
mkdir -p "$OUT/raw/strict_reports"
docker exec -i "$STRICT_APP" sh -c 'cd /app/data && tar cf - .' | tar xf - -C "$OUT/raw/strict_reports"

rc=0
# MEISAI.RPT: 양쪽 다 네이티브 Shift-JIS/COMP-3 바이트 — 변환 없이 raw cmp
if cmp -s "$OUT/raw/cobol_reports/MEISAI.RPT" "$OUT/raw/strict_reports/MEISAI.RPT"; then
  echo "  OK    MEISAI.RPT  (byte-identical, 변환 없음)"
else
  rc=1; echo "  DIFF  MEISAI.RPT  (raw bytes 불일치)"
  cmp "$OUT/raw/cobol_reports/MEISAI.RPT" "$OUT/raw/strict_reports/MEISAI.RPT" || true
fi
# 나머지 6종: ASCII 텍스트, 개행/후행공백만 정규화
norm() { sed -e 's/\r$//' -e 's/[[:space:]]*$//' "$1"; }
for f in $TEXT_FILES; do
  norm "$OUT/raw/cobol_reports/$f" > "$OUT/cobol/$f"
  norm "$OUT/raw/strict_reports/$f" > "$OUT/strict/$f"
  if diff -u "$OUT/cobol/$f" "$OUT/strict/$f" > "$OUT/$f.diff"; then
    rm -f "$OUT/$f.diff"; echo "  OK    $f"
  else
    rc=1; echo "  DIFF  $f  -> $OUT/$f.diff"
    sed -n '1,20p' "$OUT/$f.diff" | sed 's/^/        /'
  fi
done

echo
if [ "$db_rc" -eq 0 ] && [ "$rc" -eq 0 ]; then
  echo "PARITY OK   DB 2/2 (KOUZA·TORIHIKI) + 帳票 7/7  전부 일치 (backend-java-strict)"
  exit 0
fi
echo "PARITY FAIL — 위 DIFF/FAIL 항목 확인 ($OUT 아래 상세 로그)"
exit 1
