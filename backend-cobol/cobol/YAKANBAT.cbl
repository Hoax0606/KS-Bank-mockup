      *>****************************************************************
      *> YAKANBAT  -  日次夜間バッチ (通常型/Shift-JIS DB版, 明細+利息専任)
      *>   オンライン CGI が既に取引を TORIHIKI へ INSERT し残高も即時反映済み。
      *>   よって当バッチは:
      *>     (1) 当日取引(TORIHIKI.SORTED)を口座別に読み、明細D + 合計T を生成
      *>     (2) 確定残高に対する日次利息を計算し KOUZA 残高へ加算(posting)
      *>   取引後残高は 期首(=現残高-当日増減合計)から積み上げて表示する。
      *>   ※ EBCDIC/JEF/存10進/COMP-3コーデック廃止。ファイルはネイティブ、
      *>     DB は通常型直接バインド。名義は UTF-8(REPORT は X(60))。
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
       COPY WTRDAT.
       FD  F-RPTW.
       01  RPTW-REC.
           05  RPTW-KANA   PIC X(60).
           05  RPTW-SEQ    PIC 9(6).
           05  RPTW-BODY   PIC X(98).
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
       01  ACC-KANJI      PIC X(60).
       01  ACC-KANA       PIC X(60).
       01  WK-DELTA       PIC S9(13) VALUE 0.
       01  WK-DIV         PIC S9(15).
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
       01  P-KINGAKU      PIC S9(11).
       01  P-AITE         PIC 9(10).
       01  P-TESURYO      PIC S9(05).
       01  P-TEKIYOU      PIC X(40).
       COPY WMEISAI.
       COPY WDB.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  DB-KANJI       PIC X(60).
       01  DB-KANA        PIC X(60).
       01  DB-SHU         PIC X(01).
       01  DB-ZAN         PIC S9(11).
       01  HV-KZ7         PIC 9(7).
       01  HV-NEWBAL      PIC S9(11).
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
               READ F-SDAT
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
           MOVE TD-ID          TO P-ID
           MOVE TD-KOUZA-NO    TO P-KOUZA
           MOVE TD-NICHIJI     TO P-NICHIJI
           MOVE TD-KBN         TO P-KBN
           MOVE TD-KINGAKU     TO P-KINGAKU
           MOVE 0 TO P-AITE MOVE 0 TO P-TESURYO
           IF P-KBN = '3'
               MOVE TD-AITE-KOUZA TO P-AITE
               MOVE TD-TESURYO    TO P-TESURYO
           END-IF
           MOVE TD-TEKIYOU     TO P-TEKIYOU.
       START-ACCT.
           MOVE P-KOUZA TO CUR-KOUZA
           MOVE 'Y' TO HAVE-ACCT
           MOVE 0 TO ACC-FEE ACC-TD NTX
           MOVE P-KOUZA TO HV-KZ7
           EXEC SQL
               SELECT MEIGI_KANJI, MEIGI_KANA, SHUBETSU, ZANDAKA
                 INTO :DB-KANJI, :DB-KANA, :DB-SHU, :DB-ZAN
                 FROM KOUZA WHERE KOUZA_NO = :HV-KZ7
           END-EXEC
           IF SQLCODE = 0
               MOVE DB-KANJI TO ACC-KANJI
               MOVE DB-KANA  TO ACC-KANA
               MOVE DB-SHU   TO ACC-SHU
               MOVE DB-ZAN   TO ACC-BAL
           ELSE
               MOVE SPACES TO ACC-KANJI ACC-KANA
               MOVE '1' TO ACC-SHU
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
           IF ACC-SHU = '1' AND ACC-BAL > 0
               MOVE ACC-BAL TO WK-DIV
               COMPUTE ACC-INT =
                   FUNCTION INTEGER-PART(WK-DIV / 365000)
           END-IF
           COMPUTE ACC-NEW = ACC-BAL + ACC-INT
           MOVE CUR-KOUZA TO HV-KZ7
           MOVE ACC-NEW   TO HV-NEWBAL
           EXEC SQL
               UPDATE KOUZA SET ZANDAKA = :HV-NEWBAL
                WHERE KOUZA_NO = :HV-KZ7
           END-EXEC
           EXEC SQL COMMIT END-EXEC
           MOVE ACC-OPEN TO ACC-RUN
           PERFORM VARYING TIX FROM 1 BY 1 UNTIL TIX > NTX
               ADD TX-DELTA(TIX) TO ACC-RUN
               MOVE SPACES TO MEISAI-D
               MOVE 'D'        TO MD-KUBUN
               MOVE CUR-KOUZA  TO MD-KOUZA-NO
               MOVE ACC-KANJI  TO MD-MEIGI-KANJI
               MOVE TX-DT(TIX) TO MD-TORIHIKI-DT
               MOVE TX-KBN(TIX) TO MD-KBN
               MOVE TX-KIN(TIX) TO MD-KINGAKU
               MOVE ACC-RUN    TO MD-ZANDAKA-GO
               PERFORM RELEASE-RPTW-D
           END-PERFORM
           MOVE SPACES TO MEISAI-T
           MOVE 'T'       TO MT-KUBUN
           MOVE CUR-KOUZA TO MT-KOUZA-NO
           MOVE ACC-INT   TO MT-RISOKU
           MOVE ACC-FEE   TO MT-TESURYO-GK
           MOVE ACC-NEW   TO MT-KAKUTEI-ZAN
           MOVE SPACES    TO MT-FILLER
           PERFORM RELEASE-RPTW-T
           MOVE 'N' TO HAVE-ACCT.
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
       COPY PDBCONB.
       END PROGRAM YAKANBAT.
