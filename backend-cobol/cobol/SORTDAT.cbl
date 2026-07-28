      *>****************************************************************
      *> SORTDAT  -  当日取引ファイルを口座番号で整列(SORT サブプログラム)
      *>   gixpp は SD(SORT記述)を解析できないため、SORT は EXEC SQL を
      *>   含まない本モジュールに分離し、YAKANBAT から CALL する。
      *>   入力 : DAT_IN(既定 ./data/TORIHIKI.DAT, 97byte固定, EBCDIC)
      *>   出力 : ./data/TORIHIKI.SORTED (口座番号=EBCDIC数字バイト昇順=数値昇順)
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
           05  FILLER      PIC X(12).
           05  SW1-KOUZA   PIC X(10).      *> 13-22 ソートキー
           05  FILLER      PIC X(75).
       WORKING-STORAGE SECTION.
       01  DAT-PATH       PIC X(256).
       01  FS-DAT         PIC X(2).
       01  FS-OUT         PIC X(2).
       PROCEDURE DIVISION.
       MAIN.
           MOVE "./data/TORIHIKI.DAT" TO DAT-PATH
           ACCEPT DAT-PATH FROM ENVIRONMENT "DAT_IN"
           SORT SW1 ON ASCENDING KEY SW1-KOUZA
                USING F-DAT GIVING F-OUT
           GOBACK.
       END PROGRAM SORTDAT.
