#!/bin/sh
# ============================================================
#  COBOL ↔ Java 야간배치 1:1 값 대조 하네스
#
#  픽스처 적용 → 양쪽 배치 실행 → ① DB 테이블 직접 대조(KOUZA/TORIHIKI)
#                              → ② 帳票 7종 정규화 후 대조
#  전부 호스트에서 수행한다(컨테이너에 도구를 추가하지 않는다).
#
#  ①이 "DB 에 똑같은 값이 올라갔는가"의 직접 증거이고,
#  ②는 그 값을 읽어 만든 산출물까지 같은지 보는 것이다.
#
#  실행 (리포지토리 루트에서):
#      sh tools/parity/compare.sh
#
#  ☠ 라이브/데모 서버에서는 실행 금지 ☠
#    1단계에서 파리티 픽스처를 적용하는데, 그 SQL 은 DELETE FROM TORIHIKI(전건 삭제) +
#    잔액 시드 복원을 한다. 라이브 데이터가 사라진다. 로컬/검증 환경 전용.
#    (참고: 라이브 서버에는 Java 스택이 없어 어차피 4단계에서 실패한다)
#
#  전제
#    - COBOL 스택 기동:  docker compose -f backend-cobol/docker/compose.asis.yml up -d
#    - Java  스택 기동:  docker compose -f backend-java/compose.java.yml up -d
#    - 호스트에 python (3.x) + tar
#
#  ★재실행 규율★ 양쪽 배치 모두 newBal = 현재잔액 + 이자 로 멱등이 아니다.
#    이 스크립트는 매번 픽스처를 재적용하므로 반복 실행해도 같은 결과가 나온다.
#    반대로 배치만 두 번 돌리면 이자가 이중 가산된다.
#    또한 대조 중에는 온라인 조작을 하지 말 것(COBOL 5-10 은 별 프로세스라
#    중간에 도착한 거래를 보지만 Java 는 단일 트랜잭션 스냅샷이라 보지 않는다).
#
#  ★Windows Git Bash 주의★ MSYS 는 '/app/build' 같은 인수를 Windows 경로로 변환해
#    docker 인수를 깨뜨린다. 그래서 컨테이너 안 경로는 전부 `sh -c '...'` 안에 넣고,
#    파일 반입은 stdin, 반출은 tar 파이프로 처리한다(MSYS_NO_PATHCONV 를 쓰면 반대로
#    호스트 경로가 깨지므로 쓰지 않는다).
# ============================================================
set -e

# 컨테이너명·접속정보는 SERVER-SETUP.md §3-1/§3-2 기준. 환경변수로 덮어쓸 수 있다.
COBOL_APP="${COBOL_APP:-mb-cobol-sjis}"
COBOL_ORA="${COBOL_ORA:-oracle_sjis}"
JAVA_PG="${JAVA_PG:-mbj-postgres}"
JAVA_URL="${JAVA_URL:-http://localhost:8081}"
ORA_CONN="${ORA_CONN:-oracle://oracle:1521/XEPDB1}"
# sqlplus 접속문자열(컨테이너 내부에서 실행). 서버에서 돌릴 때도 이것만 바꾸면 된다.
ORA_DSN="${ORA_DSN:-minibank/minibank@//localhost:1521/XEPDB1}"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/parity/out"
FILES="MEISAI.TXT NIPPO.RPT ZANDAKA.RPT TESURYO.RPT KYUMIN.RPT TOKEI.RPT KOUZA.LST"
TABLES="KOUZA TORIHIKI"

say() { printf '\n=== %s\n' "$1"; }

#  Oracle 쪽 조회. ★NLS_LANG 주입 필수★ — 미지정이면 sqlplus 가
#  JA16SJISTILDE -> 클라이언트 문자셋 변환에서 일본어를 '?' 로 깨뜨린다(데이터는 정상).
ora_sql() {
  docker exec -i -e NLS_LANG=AMERICAN_AMERICA.AL32UTF8 "$COBOL_ORA" \
    sqlplus -s "$ORA_DSN"
}
pg_sql() { docker exec -i "$JAVA_PG" psql -U minibank -d minibank -At; }

#  줄끝 공백/CR 제거 + 빈 줄 제거(sqlplus 는 앞뒤로 빈 줄을 낸다)
norm_rows() { sed -e 's/\r$//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"; }

#  실제로 동작하는 Python 3 을 고른다.
#  ★Windows 에서 'python3' 은 Microsoft Store 앱 실행 별칭(스텁)일 수 있고, 그 경우
#    "Python" 한 줄만 출력하고 아무 일도 하지 않는다. 그래서 존재 확인만으로는 부족하고
#    실제 실행을 시켜봐야 한다.
pick_python() {
  for c in "$PYTHON" python3 python py; do
    [ -n "$c" ] || continue
    command -v "$c" >/dev/null 2>&1 || continue
    if "$c" -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)' \
         >/dev/null 2>&1; then
      echo "$c"; return 0
    fi
  done
  return 1
}
PY="$(pick_python)" || { echo "동작하는 Python 3 이 없습니다 (\$PYTHON 으로 지정)"; exit 2; }
rm -rf "$OUT"; mkdir -p "$OUT/cobol" "$OUT/java" "$OUT/raw"

# ------------------------------------------------------------
say "1/7  픽스처 적용 (Oracle)"
#  스크립트를 stdin 으로 직접 먹인다 — 컨테이너에 파일을 두지 않으므로
#  Oracle 이미지의 /tmp 권한 문제를 피한다.
#  ★접속정보를 인수로 넘기는 이유: '/nolog' 는 '/' 로 시작하는 단독 인수라
#    Windows Git Bash(MSYS)가 Windows 경로로 변환해 sqlplus 가 usage 를 뱉는다.
#    'minibank/...' 는 상대경로처럼 보여 변환되지 않는다.
#    (스크립트 안의 CONNECT 문이 다시 접속하므로 중복 접속은 무해)
docker exec -i "$COBOL_ORA" \
  sqlplus -s "$ORA_DSN" \
  < "$ROOT/backend-cobol/sql/90_parity_fixture.sql" \
  > "$OUT/fixture_oracle.log" 2>&1
tail -8 "$OUT/fixture_oracle.log"
#  sqlplus 는 스크립트 오류로도 0 을 반환할 수 있으니 결과를 별도 쿼리로 확인한다
if grep -qE '^(ORA|SP2)-' "$OUT/fixture_oracle.log"; then
  echo "  !! Oracle 픽스처에 오류 — $OUT/fixture_oracle.log 확인"; exit 1
fi
ora_cnt=$(docker exec -i "$COBOL_ORA" \
  sqlplus -s "$ORA_DSN" <<'SQL' | tr -d ' \t\r\n'
SET PAGES 0 FEED OFF
SELECT COUNT(*) FROM TORIHIKI;
EXIT
SQL
)
echo "  TORIHIKI=$ora_cnt (expect 8)"
[ "$ora_cnt" = "8" ] || { echo "  !! Oracle 픽스처 미적용"; exit 1; }

say "2/7  픽스처 적용 (PostgreSQL)"
docker exec -i "$JAVA_PG" psql -U minibank -d minibank -q -v ON_ERROR_STOP=1 \
  < "$ROOT/backend-java/src/main/resources/db/90_parity_fixture.sql" \
  > "$OUT/fixture_pg.log" 2>&1
tail -12 "$OUT/fixture_pg.log"

# ------------------------------------------------------------
say "3/7  COBOL 배치 실행 (10 스텝)"
#  ORA_*/NLS_LANG 주입 필수 — docker exec 셸은 entrypoint 의 export 를 상속하지 않는다.
#  2026-08부터 배치도 Shift-JIS 응답이라 NLS_LANG 누락 시 UTF-8로 조용히 전환된다.
docker exec -i \
  -e ORA_CONN="$ORA_CONN" -e ORA_USER=minibank -e ORA_PASS=minibank \
  -e NLS_LANG=JAPANESE_JAPAN.JA16SJISTILDE \
  "$COBOL_APP" sh -c 'cd /app/build && mkdir -p data && sh run_batch.sh'

say "4/7  Java 배치 실행"
curl -sS -X POST "$JAVA_URL/api/batch/run" -o "$OUT/java_batch.json"
echo "  -> $OUT/java_batch.json"

# ------------------------------------------------------------
say "5/7  DB 직접 대조 (KOUZA / TORIHIKI)"
#  "DB 에 올라가는 값이 같은가" 를 帳票 경유가 아니라 테이블에서 직접 확인한다.
#  숫자는 TO_CHAR/캐스팅으로 방언 차이를 없애고, NULL 은 '-' 로 통일한다.
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
  norm_rows "$OUT/raw/pg_$t.txt"  > "$OUT/java/$t.rows"
  n=$(wc -l < "$OUT/cobol/$t.rows" | tr -d ' ')
  if [ "$n" -eq 0 ]; then
    db_rc=1; echo "  FAIL  $t  (Oracle 조회 결과 0행 — $OUT/raw/ora_$t.txt 확인)"
  elif diff -u "$OUT/cobol/$t.rows" "$OUT/java/$t.rows" > "$OUT/DB_$t.diff"; then
    rm -f "$OUT/DB_$t.diff"; echo "  OK    $t  ($n 행 완전 일치)"
  else
    db_rc=1; echo "  DIFF  $t  -> $OUT/DB_$t.diff"
    sed -n '1,20p' "$OUT/DB_$t.diff" | sed 's/^/        /'
  fi
done

# ------------------------------------------------------------
say "6/7  帳票 정규화"
#  COBOL: 컨테이너에서 tar 로 반출 → MEISAI.RPT 만 디코드
docker exec -i "$COBOL_APP" sh -c 'cd /app/build/data && tar cf - .' \
  | tar xf - -C "$OUT/raw"
"$PY" "$ROOT/tools/parity/meisai_dump.py" "$OUT/raw/MEISAI.RPT" > "$OUT/cobol/MEISAI.TXT"

norm() {  # 줄끝 공백 제거 + CRLF -> LF
  #  GnuCOBOL LINE SEQUENTIAL 은 기본적으로 후행 공백을 자르지만
  #  COB_LS_FIXED=1 환경에서는 X(80) 로 패딩하므로 안전망으로 정규화한다
  sed -e 's/\r$//' -e 's/[[:space:]]*$//' "$1"
}
for f in NIPPO.RPT ZANDAKA.RPT TESURYO.RPT KYUMIN.RPT KOUZA.LST TOKEI.RPT; do
  norm "$OUT/raw/$f" > "$OUT/cobol/$f"
done
#  Java: 산출 디렉터리에서 복사(같은 정규화 적용)
for f in $FILES; do
  norm "$ROOT/backend-java/data/$f" > "$OUT/java/$f"
done

#  레코드길이 교차검증 (backend-cobol/README.md §7 의 98byte 점검 자동화)
bytes=$(wc -c < "$OUT/raw/MEISAI.RPT" | tr -d ' ')
lines=$(wc -l < "$OUT/cobol/MEISAI.TXT" | tr -d ' ')
echo "  MEISAI.RPT ${bytes} bytes / ${lines} recs (expect 98 x ${lines} = $((98 * lines)))"
[ "$bytes" -eq $((98 * lines)) ] || { echo "  !! 98byte 고정길이 위반"; exit 1; }

# ------------------------------------------------------------
say "7/7  帳票 diff"
rc=0
for f in $FILES; do
  if diff -u "$OUT/cobol/$f" "$OUT/java/$f" > "$OUT/$f.diff"; then
    rm -f "$OUT/$f.diff"
    echo "  OK    $f"
  else
    rc=1
    echo "  DIFF  $f  -> $OUT/$f.diff"
    sed -n '1,20p' "$OUT/$f.diff" | sed 's/^/        /'
  fi
done

echo
if [ "$db_rc" -eq 0 ] && [ "$rc" -eq 0 ]; then
  echo "PARITY OK   DB 2/2 (KOUZA·TORIHIKI) + 帳票 7/7  전부 일치"
  exit 0
fi
[ "$db_rc" -eq 0 ] || echo "PARITY FAILED — DB 값 불일치 ($OUT/DB_*.diff)"
[ "$rc" -eq 0 ]    || echo "PARITY FAILED — 帳票 불일치 ($OUT/*.diff)"
exit 1
