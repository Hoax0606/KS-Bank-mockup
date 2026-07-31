# ============================================================
#  ASIS ビルド (COPY展開 -> gixpp プリコンパイル -> cobc)
#  対象: GnuCOBOL + GixSQL(EXEC SQL) + Oracle Instant Client
#
#  ★ gixpp は COPY を展開せず、cobc は EXEC SQL INCLUDE を誤処理するため、
#    自前の expand_copy.sh で COPY を平坦化し、END PROGRAM 行を除去してから
#    gixpp に渡す(gixpp は生成カーソル定義を EOF に付すため)。
#  ★ gixpp は SD(SORT記述)を解析不可 -> SORT は SORTDAT/SORTRPT(純COBOL)
#    へ分離し、YAKANBAT から CALL する。
#
#  使い方: make            # 全ビルド
#          make clean
# ============================================================
GIXHOME ?= /opt/gixsql
COBC    ?= cobc
GIXPP   ?= gixpp
SHELL   := /bin/sh

SRC   := ../cobol
COPY  := ../cobol/copy
GENC  := ./gen
BIN   := ./bin
LIB   := ./lib

# -S: ESQL 静的呼び出し(GIXSQL ランタイムを -lgixsql でリンク時解決)。
#     これが無いと GIXSQLConnect 等が実行時に「module not found」になる。
# -z c: パラメータスタイル = コロン(:1)。Oracle(ODPI)は :1 バインドなので必須。
#       既定 -z d($1, PostgreSQL式)だと 0件返却になる。
GIXFLAGS := -e -S -z c -I $(COPY) -I $(GIXHOME)/share/gixsql/copy
COBFLAGS := -I $(COPY) -I $(GIXHOME)/share/gixsql/copy -L $(GIXHOME)/lib -lgixsql

# 共通サブモジュール(.so)。CGI/バッチから動的 CALL される。
# (EBCDIG/RAWUTF8 등 코덱 모듈은 Shift-JIS 전환으로 폐지)
MODS := CGIINIT CGIPARM CGIRESP
# SQL を含む CGI メイン
CGI_SQL := ZANDAKA FURIKOMI MEISAI \
           LOGIN SIGNUP LOAN REPAY NOTICE HOLDINGS
# バッチ(SQL あり)
BATCH := YAKANBAT MKDAT NIPPOBAT ZANDABAT TESUBAT KYUMBAT MASTBAT TOKEBAT
# ツール/バッチ・ステップ(SQL 無し実行体)。SORTDAT/SORTRPT は SORT を
# 含むため独立プロセスで実行(Oracle 使用プロセス内 SORT のクラッシュ回避)。
TOOLS := SORTDAT SORTRPT

.PHONY: all dirs mods cgi batch tools clean
all: dirs mods cgi batch tools

dirs:
	@mkdir -p $(GENC) $(BIN) $(LIB)

# ---- 共通サブモジュール(.so) ----
mods: dirs
	@for m in $(MODS); do \
	  echo "  [mod]  $$m"; \
	  $(COBC) -m -I $(COPY) $(SRC)/$$m.cbl -o $(LIB)/$$m.so || exit 1; \
	done

# ---- CGI メイン(展開 -> END PROGRAM除去 -> gixpp -> cobc -x) ----
cgi: dirs
	@for p in $(CGI_SQL); do \
	  lp=`echo $$p | tr A-Z a-z`; \
	  echo "  [prep] $$p"; \
	  sh ./expand_copy.sh $(SRC)/$$p.cbl $(COPY) \
	    | grep -v -iE '^[[:space:]]*END PROGRAM' > $(GENC)/$$p.exp || exit 1; \
	  echo "  [gixpp] $$p"; \
	  $(GIXPP) $(GIXFLAGS) -i $(GENC)/$$p.exp -o $(GENC)/$$p.cob || exit 1; \
	  echo "  [cgi]  $$lp.cgi"; \
	  $(COBC) -x $(COBFLAGS) $(GENC)/$$p.cob -o $(BIN)/$$lp.cgi || exit 1; \
	done

# ---- バッチ ----
batch: dirs
	@for b in $(BATCH); do \
	  echo "  [prep] $$b"; \
	  sh ./expand_copy.sh $(SRC)/$$b.cbl $(COPY) \
	    | grep -v -iE '^[[:space:]]*END PROGRAM' > $(GENC)/$$b.exp || exit 1; \
	  echo "  [gixpp] $$b"; \
	  $(GIXPP) $(GIXFLAGS) -i $(GENC)/$$b.exp -o $(GENC)/$$b.cob || exit 1; \
	  echo "  [batch] $$b"; \
	  $(COBC) -x $(COBFLAGS) $(GENC)/$$b.cob -o $(BIN)/$$b || exit 1; \
	done

# ---- ツール(MKDAT: サンプル TORIHIKI.DAT 生成) ----
tools: dirs
	@for t in $(TOOLS); do \
	  echo "  [tool] $$t"; \
	  $(COBC) -x -I $(COPY) $(SRC)/$$t.cbl -o $(BIN)/$$t || exit 1; \
	done

clean:
	rm -rf $(GENC) $(BIN) $(LIB)
