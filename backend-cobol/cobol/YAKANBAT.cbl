      *>****************************************************************
      *> YAKANBAT  -  日次夜間バッチ (オプション1: 実取引 / 明細+利息専任)
      *>   オンライン CGI が既に取引を TORIHIKI へ INSERT し残高も即時反映済み。
      *>   よって当バッチは「再INSERT/再反映」はせず、以下のみ行う:
      *>     (1) 当日取引(TORIHIKI.SORTED)を口座別に読み、明細D + 合計T を生成
      *>     (2) 確定残高に対する日次利息を計算し KOUZA 残高へ加算(posting)
      *>   取引後残高は 期首(=現残高-当日増減合計)から積み上げて表示する。
      *>   出力は UTF-8 変換しない(EBCDIC 原本)。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. YAKANBAT.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT F-SDAT  ASSIGN TO "TORIHIKI.SORTED"
               ORGANIZATION IS SEQUENTIAL FILE STATUS IS FS-SDAT.
           SELECT F-RPTW  ASSIGN TO "REPORT.WORK"
               ORGANIZATION IS SEQUENTIAL FILE STATUS IS FS-RPTW.
       DATA DIVISION.
       FILE SECTION.
       FD  F-SDAT.
       01  DAT-REC        PIC X(97).
       FD  F-RPTW.
       01  RPTW-REC.
           05  RPTW-KANA   PIC X(20).
           05  RPTW-SEQ    PIC 9(6).
           05  RPTW-BODY   PIC X(58).
       WORKING-STORAGE SECTION.
       01  FS-SDAT        PIC X(2).
       01  FS-RPTW        PIC X(2).
       01  EOF-SW         PIC X(1) VALUE 'N'.
       01  SEQ-CNT        PIC 9(6) VALUE 0.
      *>-- control break 制御 --------------------------------------
       01  CUR-KOUZA      PIC 9(10) VALUE 0.
       01  HAVE-ACCT      PIC X(1) VALUE 'N'.
       01  ACC-BAL        PIC S9(13) VALUE 0.
       01  ACC-FEE        PIC S9(13) VALUE 0.
       01  ACC-INT        PIC S9(13) VALUE 0.
       01  ACC-TD         PIC S9(13) VALUE 0.
       01  ACC-OPEN       PIC S9(13) VALUE 0.
       01  ACC-RUN        PIC S9(13) VALUE 0.
       01  ACC-NEW        PIC S9(13) VALUE 0.
       01  ACC-SHU        PIC X(1)  VALUE '1'.
       01  ACC-KANJI      PIC X(20).
       01  ACC-KANA       PIC X(20).
       01  WK-DELTA       PIC S9(13) VALUE 0.
       01  WK-DIV         PIC S9(15).
       01  WK-KZ7         PIC 9(7).
      *>-- 口座内 取引バッファ(期首から積上げ用) --------------------
       01  TXTBL.
           05  TXR OCCURS 500 TIMES.
               10  TX-DT     PIC X(14).
               10  TX-KBN    PIC X(01).
               10  TX-KIN    PIC S9(11) COMP-3.
               10  TX-DELTA  PIC S9(13).
       01  NTX            PIC 9(4) COMP VALUE 0.
       01  TIX            PIC 9(4) COMP VALUE 0.
      *>-- DAT レコード解析 ----------------------------------------
       01  P-ID           PIC 9(12).
       01  P-KOUZA        PIC 9(10).
       01  P-NICHIJI      PIC X(14).
       01  P-KBN          PIC X(01).
       01  P-KINGAKU      PIC S9(11) COMP-3.
       01  P-AITE         PIC 9(10).
       01  P-TESURYO      PIC S9(05) COMP-3.
       01  P-TEKIYOU      PIC X(40).
       01  C3-6.
           05  C3-6X       PIC X(6).
       01  C3-6N REDEFINES C3-6  PIC S9(11) COMP-3.
       01  C3-3.
           05  C3-3X       PIC X(3).
       01  C3-3N REDEFINES C3-3  PIC S9(05) COMP-3.
       01  EB-IO.
           05  EB-MODE     PIC X(1).
           05  EB-LEN      PIC 9(4).
           05  EB-BUF      PIC X(64).
       COPY WMEISAI.
       COPY WDB.
       COPY WPACK.
       COPY WTXT.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  DB-KANJI       PIC X(20).
       01  DB-KANA        PIC X(20).
       01  DB-SHU         PIC X(01).
       01  DB-ZAN-HX      PIC X(12).
       01  DB-CONF-HX     PIC X(12).
       01  DB-KZ-HEX      PIC X(14).
       EXEC SQL END DECLARE SECTION END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           DISPLAY "[YAKANBAT] start (reads TORIHIKI.SORTED)"
           PERFORM DB-CONNECT
           PERFORM PROCESS-SORTED
           PERFORM DB-DISCONNECT
           DISPLAY "[YAKANBAT] done (wrote REPORT.WORK)"
           STOP RUN.
       PROCESS-SORTED.
           OPEN INPUT F-SDAT
           OPEN OUTPUT F-RPTW
           MOVE 'N' TO EOF-SW HAVE-ACCT
           MOVE 0 TO SEQ-CNT
           PERFORM UNTIL EOF-SW = 'Y'
               READ F-SDAT INTO DAT-REC
                   AT END MOVE 'Y' TO EOF-SW
                   NOT AT END
                       PERFORM PARSE-DAT
                       IF HAVE-ACCT = 'N'
                           PERFORM START-ACCT
                       ELSE
                           IF P-KOUZA NOT = CUR-KOUZA
                               PERFORM BREAK-ACCT
                               PERFORM START-ACCT
                           END-IF
                       END-IF
                       PERFORM APPLY-TXN
               END-READ
           END-PERFORM
           IF HAVE-ACCT = 'Y'
               PERFORM BREAK-ACCT
           END-IF
           CLOSE F-SDAT F-RPTW.
       PARSE-DAT.
           MOVE DAT-REC(1:12) TO EB-BUF
           MOVE 'T' TO EB-MODE MOVE 12 TO EB-LEN
           CALL "EBCDIG" USING EB-IO
           MOVE EB-BUF(1:12) TO P-ID
           MOVE DAT-REC(13:10) TO EB-BUF MOVE 10 TO EB-LEN
           CALL "EBCDIG" USING EB-IO
           MOVE EB-BUF(1:10) TO P-KOUZA
           MOVE DAT-REC(23:14) TO EB-BUF MOVE 14 TO EB-LEN
           CALL "EBCDIG" USING EB-IO
           MOVE EB-BUF(1:14) TO P-NICHIJI
           MOVE DAT-REC(37:1) TO EB-BUF MOVE 1 TO EB-LEN
           CALL "EBCDIG" USING EB-IO
           MOVE EB-BUF(1:1) TO P-KBN
           MOVE DAT-REC(38:6) TO C3-6X
           MOVE C3-6N TO P-KINGAKU
           MOVE 0 TO P-AITE MOVE 0 TO P-TESURYO
           IF P-KBN = '3'
               MOVE DAT-REC(44:10) TO EB-BUF MOVE 10 TO EB-LEN
               MOVE 'T' TO EB-MODE
               CALL "EBCDIG" USING EB-IO
               MOVE EB-BUF(1:10) TO P-AITE
               MOVE DAT-REC(54:3) TO C3-3X
               MOVE C3-3N TO P-TESURYO
           END-IF
           MOVE DAT-REC(58:40) TO P-TEKIYOU.
       START-ACCT.
           MOVE P-KOUZA TO CUR-KOUZA
           MOVE 'Y' TO HAVE-ACCT
           MOVE 0 TO ACC-FEE ACC-TD NTX
           MOVE P-KOUZA TO WK-KZ7
           MOVE WK-KZ7 TO KY-STR(1:7)
           MOVE 7 TO KY-N
           PERFORM ENC-KEY
           MOVE KY-HEX(1:14) TO DB-KZ-HEX
           EXEC SQL
               SELECT MEIGI_KANJI, MEIGI_KANA, SHUBETSU,
                      RAWTOHEX(ZANDAKA)
                 INTO :DB-KANJI, :DB-KANA, :DB-SHU, :DB-ZAN-HX
                 FROM KOUZA WHERE KOUZA_NO = HEXTORAW(:DB-KZ-HEX)
           END-EXEC
           IF SQLCODE = 0
               MOVE DB-KANJI TO ACC-KANJI
               MOVE DB-KANA  TO ACC-KANA
               MOVE DB-SHU   TO ACC-SHU
               MOVE DB-ZAN-HX TO PK-HEX
               PERFORM DEC-P11
               MOVE PK-P11 TO ACC-BAL
           ELSE
               MOVE SPACES TO ACC-KANJI ACC-KANA
               MOVE X'F1' TO ACC-SHU
               MOVE 0 TO ACC-BAL
               DISPLAY "  WARN kouza not in master: " P-KOUZA
           END-IF.
       APPLY-TXN.
           PERFORM CALC-DELTA
           ADD WK-DELTA TO ACC-TD
           IF P-KBN = '3'
               ADD P-TESURYO TO ACC-FEE
           END-IF
           ADD 1 TO NTX
           MOVE P-NICHIJI TO TX-DT(NTX)
           MOVE P-KBN     TO TX-KBN(NTX)
           MOVE P-KINGAKU TO TX-KIN(NTX)
           MOVE WK-DELTA  TO TX-DELTA(NTX).
       CALC-DELTA.
           EVALUATE P-KBN
               WHEN '1' MOVE P-KINGAKU TO WK-DELTA
               WHEN '2' COMPUTE WK-DELTA = 0 - P-KINGAKU
               WHEN '3' COMPUTE WK-DELTA = 0 - (P-KINGAKU + P-TESURYO)
               WHEN OTHER MOVE 0 TO WK-DELTA
           END-EVALUATE.
       BREAK-ACCT.
           COMPUTE ACC-OPEN = ACC-BAL - ACC-TD
           MOVE 0 TO ACC-INT
           IF ACC-SHU = X'F1' AND ACC-BAL > 0
               MOVE ACC-BAL TO WK-DIV
               COMPUTE ACC-INT =
                   FUNCTION INTEGER-PART(WK-DIV / 365000)
           END-IF
           COMPUTE ACC-NEW = ACC-BAL + ACC-INT
           MOVE CUR-KOUZA TO WK-KZ7
           MOVE WK-KZ7 TO KY-STR(1:7)
           MOVE 7 TO KY-N
           PERFORM ENC-KEY
           MOVE KY-HEX(1:14) TO DB-KZ-HEX
           MOVE ACC-NEW TO PK-P11
           PERFORM ENC-P11
           MOVE PK-HEX TO DB-CONF-HX
           EXEC SQL
               UPDATE KOUZA SET ZANDAKA = HEXTORAW(:DB-CONF-HX)
                WHERE KOUZA_NO = HEXTORAW(:DB-KZ-HEX)
           END-EXEC
           EXEC SQL COMMIT END-EXEC
           MOVE ACC-OPEN TO ACC-RUN
           PERFORM VARYING TIX FROM 1 BY 1 UNTIL TIX > NTX
               ADD TX-DELTA(TIX) TO ACC-RUN
               MOVE SPACES TO MEISAI-D
               MOVE X'C4'      TO MD-KUBUN
               MOVE CUR-KOUZA  TO MD-KOUZA-NO
               MOVE ACC-KANJI  TO MD-MEIGI-KANJI
               MOVE TX-DT(TIX) TO MD-TORIHIKI-DT
               MOVE TX-KBN(TIX) TO MD-KBN
               MOVE TX-KIN(TIX) TO MD-KINGAKU
               MOVE ACC-RUN    TO MD-ZANDAKA-GO
               PERFORM ENC-D-DISPLAY
               PERFORM RELEASE-RPTW-D
           END-PERFORM
           MOVE SPACES TO MEISAI-T
           MOVE X'E3'     TO MT-KUBUN
           MOVE CUR-KOUZA TO MT-KOUZA-NO
           MOVE ACC-INT   TO MT-RISOKU
           MOVE ACC-FEE   TO MT-TESURYO-GK
           MOVE ACC-NEW   TO MT-KAKUTEI-ZAN
           MOVE ALL X'40' TO MT-FILLER
           PERFORM ENC-T-DISPLAY
           PERFORM RELEASE-RPTW-T
           MOVE 'N' TO HAVE-ACCT.
       ENC-D-DISPLAY.
           MOVE 'F' TO EB-MODE
           MOVE 10 TO EB-LEN MOVE MEISAI-D(2:10) TO EB-BUF
           CALL "EBCDIG" USING EB-IO
           MOVE EB-BUF(1:10) TO MEISAI-D(2:10)
           MOVE 14 TO EB-LEN MOVE MEISAI-D(32:14) TO EB-BUF
           CALL "EBCDIG" USING EB-IO
           MOVE EB-BUF(1:14) TO MEISAI-D(32:14)
           MOVE 1 TO EB-LEN MOVE MEISAI-D(46:1) TO EB-BUF
           CALL "EBCDIG" USING EB-IO
           MOVE EB-BUF(1:1) TO MEISAI-D(46:1).
       ENC-T-DISPLAY.
           MOVE 'F' TO EB-MODE
           MOVE 10 TO EB-LEN MOVE MEISAI-T(2:10) TO EB-BUF
           CALL "EBCDIG" USING EB-IO
           MOVE EB-BUF(1:10) TO MEISAI-T(2:10).
       RELEASE-RPTW-D.
           ADD 1 TO SEQ-CNT
           MOVE ACC-KANA  TO RPTW-KANA
           MOVE SEQ-CNT   TO RPTW-SEQ
           MOVE MEISAI-D  TO RPTW-BODY
           WRITE RPTW-REC.
       RELEASE-RPTW-T.
           ADD 1 TO SEQ-CNT
           MOVE ACC-KANA  TO RPTW-KANA
           MOVE SEQ-CNT   TO RPTW-SEQ
           MOVE MEISAI-T  TO RPTW-BODY
           WRITE RPTW-REC.
       COPY PPACK.
       COPY PTXT.
       COPY PDBCONB.
       END PROGRAM YAKANBAT.
