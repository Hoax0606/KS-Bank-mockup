      *>****************************************************************
      *> MKDAT  -  当日取引 TORIHIKI.DAT (97byte固定, EBCDIC) サンプル生成
      *>   バッチ(YAKANBAT)の入力。決定打を通すサンプルを口座混在順で出力。
      *>   DISPLAY数字は EBCDIC(EBCDIG 'F'), COMP-3はパック直接, 摘要は
      *>   EBCDIC空白(0x40)。並びは未整列(バッチ側 SORT を実証)。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MKDAT.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT F-OUT ASSIGN TO OUT-PATH
               ORGANIZATION IS SEQUENTIAL FILE STATUS IS FS.
       DATA DIVISION.
       FILE SECTION.
       FD  F-OUT.
       COPY WTRDAT.
       WORKING-STORAGE SECTION.
       01  OUT-PATH   PIC X(256).
       01  FS         PIC X(2).
       01  I          PIC 9(2) COMP.
       01  CV-POS     PIC 9(4) COMP.
       01  CV-LEN     PIC 9(4) COMP.
       01  EB-IO.
           05 EB-MODE PIC X(1).
           05 EB-LEN  PIC 9(4).
           05 EB-BUF  PIC X(64).
      *>-- サンプル取引定義(native) -------------------------------
       01  SAMP.
           05 FILLER PIC X(50) VALUE
              "100000000001 1000000002 20260714090000 1 000200000".
           05 FILLER PIC X(50) VALUE
              "100000000002 1000000001 20260714090500 3 000080000".
           05 FILLER PIC X(50) VALUE
              "100000000003 1000000003 20260714091000 1 000010000".
           05 FILLER PIC X(50) VALUE
              "100000000004 1000000002 20260714093000 2 000035000".
           05 FILLER PIC X(50) VALUE
              "100000000005 1000000004 20260714094500 2 000050000".
           05 FILLER PIC X(50) VALUE
              "100000000006 1000000002 20260714095000 1 -00050000".
           05 FILLER PIC X(50) VALUE
              "100000000007 1000000100 20260714100000 1 000005000".
       01  SAMP-R REDEFINES SAMP.
           05 S-ROW OCCURS 7 TIMES.
              10 S-ID     PIC X(12).
              10 FILLER   PIC X(1).
              10 S-KOUZA  PIC X(10).
              10 FILLER   PIC X(1).
              10 S-DT     PIC X(14).
              10 FILLER   PIC X(1).
              10 S-KBN    PIC X(1).
              10 FILLER   PIC X(1).
              10 S-AMT-X  PIC X(9).       *> 符号付き文字列(先頭 '-' 可)
      *>   振込明細(行2 = 1000000001 -> 1000000100, 手数料110)
       01  FURI-AITE   PIC 9(10) VALUE 1000000100.
       01  FURI-TES    PIC S9(05) VALUE 110.
       PROCEDURE DIVISION.
       MAIN.
           MOVE "./data/TORIHIKI.DAT" TO OUT-PATH
           ACCEPT OUT-PATH FROM ENVIRONMENT "DAT_IN"
           OPEN OUTPUT F-OUT
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > 7
               PERFORM BUILD-ONE
               WRITE TR-DAT-REC
           END-PERFORM
           CLOSE F-OUT
           DISPLAY "[MKDAT] wrote 7 records to " FUNCTION TRIM(OUT-PATH)
                   UPON SYSERR
           STOP RUN.
       BUILD-ONE.
           MOVE ALL X'40' TO TR-DAT-REC        *> EBCDIC 空白で初期化
           MOVE S-ID(I)    TO TD-ID
           MOVE S-KOUZA(I) TO TD-KOUZA-NO
           MOVE S-DT(I)    TO TD-NICHIJI
           MOVE S-KBN(I)   TO TD-KBN
           IF S-AMT-X(I)(1:1) = '-'
               COMPUTE TD-KINGAKU = 0 - FUNCTION NUMVAL(S-AMT-X(I)(2:8))
           ELSE
               MOVE FUNCTION NUMVAL(S-AMT-X(I)) TO TD-KINGAKU
           END-IF
           MOVE ALL X'40'  TO TD-EXT
           IF TD-KBN = '3'
               MOVE FURI-AITE TO TD-AITE-KOUZA
               MOVE FURI-TES  TO TD-TESURYO
           END-IF
           MOVE ALL X'40'  TO TD-TEKIYOU
      *>   DISPLAY数字領域を EBCDIC へ(参照修飾でレコード上を直接変換)。
      *>   ※ 数値項目(PIC 9)へ EBCDIC バイトを MOVE すると正規化で壊れるため、
      *>     必ず TR-DAT-REC のバイト位置に対して変換する。COMP-3(38-43,54-56)
      *>     は変換対象外(パック10進は EBCDIC/ASCII 同一)。
           MOVE 1  TO CV-POS  MOVE 12 TO CV-LEN  PERFORM CVT-AT  *> ID
           MOVE 13 TO CV-POS  MOVE 10 TO CV-LEN  PERFORM CVT-AT  *> KOUZA
           MOVE 23 TO CV-POS  MOVE 14 TO CV-LEN  PERFORM CVT-AT  *> 日時
           MOVE 37 TO CV-POS  MOVE 1  TO CV-LEN  PERFORM CVT-AT  *> 区分
           IF S-KBN(I) = '3'
               MOVE 44 TO CV-POS  MOVE 10 TO CV-LEN  PERFORM CVT-AT
           END-IF.
       CVT-AT.
           MOVE 'F' TO EB-MODE
           MOVE CV-LEN TO EB-LEN
           MOVE TR-DAT-REC(CV-POS:CV-LEN) TO EB-BUF
           CALL "EBCDIG" USING EB-IO
           MOVE EB-BUF(1:CV-LEN) TO TR-DAT-REC(CV-POS:CV-LEN).
       END PROGRAM MKDAT.
