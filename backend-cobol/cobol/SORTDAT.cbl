      *>****************************************************************
      *> SORTDAT  -  当日取引ファイルを口座番号で整列(SORT サブプログラム)
      *>   gixpp は SD(SORT記述)を解析できないため、SORT は EXEC SQL を
      *>   含まない本モジュールに分離し、YAKANBAT から CALL する。
      *>   入力 : DAT_IN(既定 ./data/TORIHIKI.DAT, 97byte固定, ネイティブ)
      *>   出力 : ./data/TORIHIKI.SORTED
      *>          第1キー 口座番号(ASCII数字バイト昇順=数値昇順)
      *>          第2キー 取引ID  (同一口座内の順序を確定させる)
      *>   ※ 第2キー必須: 同一口座に2件以上の取引があると第1キーが重複し、
      *>     重複キーの出力順は規格上未定義になる。YAKANBAT は本ファイルの
      *>     順序どおりに残高を積み上げて「取引後残高」を書くため、順序が
      *>     揺れると明細の値そのものが変わる(最終残高・T レコードは不変)。
      *>     MKDAT が既に ORDER BY KOUZA_NO, TORIHIKI_ID で抽出しているので
      *>     この2キー整列は恒等変換=保証された no-op になる。
      *>     (兄弟の SORTRPT も SW2-SEQ で同じ安定化を行っている)
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SORTDAT.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT F-DAT  ASSIGN TO DAT-PATH
               ORGANIZATION IS SEQUENTIAL FILE STATUS IS FS-DAT.
           SELECT F-OUT  ASSIGN TO "TORIHIKI.SORTED"
               ORGANIZATION IS SEQUENTIAL FILE STATUS IS FS-OUT.
           SELECT SW1    ASSIGN TO "sw1.tmp".
       DATA DIVISION.
       FILE SECTION.
       FD  F-DAT.
       01  DAT-REC        PIC X(97).
       FD  F-OUT.
       01  OUT-REC        PIC X(97).
       SD  SW1.
       01  SW1-REC.
           05  SW1-ID      PIC X(12).      *> 1-12  第2キー(TD-ID 投入順)
           05  SW1-KOUZA   PIC X(10).      *> 13-22 第1キー
           05  FILLER      PIC X(75).
       WORKING-STORAGE SECTION.
       01  DAT-PATH       PIC X(256).
       01  FS-DAT         PIC X(2).
       01  FS-OUT         PIC X(2).
       PROCEDURE DIVISION.
       MAIN.
           MOVE "./data/TORIHIKI.DAT" TO DAT-PATH
           ACCEPT DAT-PATH FROM ENVIRONMENT "DAT_IN"
           SORT SW1 ON ASCENDING KEY SW1-KOUZA SW1-ID
                USING F-DAT GIVING F-OUT
           GOBACK.
       END PROGRAM SORTDAT.
