#!/bin/sh
# ============================================================
#  expand_copy.sh <infile> <copydir>
#   COBOL の COPY 文を copybook 内容でインライン展開して stdout へ。
#   目的: gixpp は COPY を展開しない/ cobc は EXEC SQL INCLUDE を
#         COPY 扱いして誤処理する、の двойного 問題を回避するため、
#         gixpp 前に自前で COPY を平坦化して「全 EXEC SQL を単一ソースに」集める。
#   前提: copybook はネストした COPY を持たない(本プロジェクトの構成)。
#         念のため 3 パス展開する。
# ============================================================
infile="$1"; cpdir="$2"

expand_once() {
  while IFS= read -r line || [ -n "$line" ]; do
    # 先頭空白を除いた文字列で判定(コメント行 *> は対象外)
    trimmed=`printf '%s' "$line" | sed 's/^[[:space:]]*//'`
    case "$trimmed" in
      COPY\ *|COPY.)
        name=`printf '%s' "$trimmed" | sed -n 's/^COPY[[:space:]]*\([A-Za-z0-9_-]*\).*/\1/p'`
        if   [ -n "$name" ] && [ -f "$cpdir/$name.cpy" ]; then cat "$cpdir/$name.cpy"
        elif [ -n "$name" ] && [ -f "$cpdir/$name.CPY" ]; then cat "$cpdir/$name.CPY"
        else printf '%s\n' "$line"; fi ;;
      *) printf '%s\n' "$line" ;;
    esac
  done
}

tmp1=`mktemp`; tmp2=`mktemp`
cat "$infile" > "$tmp1"
i=0
while [ $i -lt 3 ]; do
  expand_once < "$tmp1" > "$tmp2"
  # COPY が残っていなければ終了
  if ! grep -qiE '^[[:space:]]*COPY[[:space:]]' "$tmp2"; then break; fi
  cp "$tmp2" "$tmp1"; i=`expr $i + 1`
done
cat "$tmp2"
rm -f "$tmp1" "$tmp2"
