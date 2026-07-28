      *>****************************************************************
      *> LOAN  -  ローン CGI (拡張)
      *>   GET  : kouza -> 有効ローン一覧
      *>   POST : kouza, amt, method(A/B/C), years -> 実行(与信 300万上限)
      *>          口座残高へ入金 + LOAN_ASIS 追加 + TORIHIKI(区分1)
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WCGI.
       COPY WONLINE.
       COPY WDB.
       01  WK-NOW      PIC X(21).
       01  FIRST-ROW   PIC X(1) VALUE 'Y'.
       01  LOAN-AVAIL  PIC S9(11) VALUE 3000000.
       COPY WPACK.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KOUZA    PIC 9(7).
       01  HV-KZ-HEX   PIC X(14).
       01  HV-AMT      PIC S9(11) COMP-3.
       01  HV-ZAN-HX   PIC X(12).
       01  HV-AMT-HX   PIC X(12).
       01  HV-BAL      PIC S9(11) COMP-3.
       01  HV-METHOD   PIC X(1).
       01  HV-YEARS    PIC 9(3).
       01  HV-LOANID   PIC 9(12).
       01  HV-LOANID-HEX PIC X(24).
       01  HV-TID-HEX  PIC X(24).
       01  HV-USED     PIC S9(13) COMP-3.
       01  HV-DT       PIC X(14).
       01  HV-TID      PIC 9(12).
       01  HV-CNT      PIC 9(9).
       01  HV-ACTIVE   PIC X(6) VALUE 'ACTIVE'.
       01  C-ID        PIC 9(12).
       01  C-ID-HX     PIC X(24).
       01  C-PRIN      PIC S9(11) COMP-3.
       01  C-BAL       PIC S9(11) COMP-3.
       01  C-METHOD    PIC X(1).
       01  C-YEARS     PIC 9(3).
       EXEC SQL END DECLARE SECTION END-EXEC.
       EXEC SQL
           DECLARE C-LOAN CURSOR FOR
             SELECT RAWTOHEX(LOAN_ID), PRINCIPAL, BALANCE,
                    METHOD, TERM_YEARS
               FROM LOAN_ASIS
              WHERE STATUS = 'ACTIVE'
                AND KOUZA_NO = HEXTORAW(:HV-KZ-HEX)
              ORDER BY LOAN_ID
       END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           CALL "CGIINIT" USING CGI-ENV
           MOVE "kouza" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE FUNCTION NUMVAL(CP-VALUE) TO HV-KOUZA
           MOVE HV-KOUZA TO KY-STR(1:7)
           MOVE 7 TO KY-N
           PERFORM ENC-KEY
           MOVE KY-HEX(1:14) TO HV-KZ-HEX
           PERFORM DB-CONNECT
           IF CGI-METHOD = "POST"
               PERFORM DO-APPLY
           ELSE
               PERFORM DO-LIST
           END-IF
           PERFORM DB-DISCONNECT
           CALL "CGIRESP" USING RESP
           STOP RUN.
      *>-- 一覧 -----------------------------------------------------
       DO-LIST.
           MOVE 1 TO RESP-PTR MOVE SPACES TO RESP-BUF
           STRING '{"ok":true,"loans":[' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE 'Y' TO FIRST-ROW
           EXEC SQL OPEN C-LOAN END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL
                   FETCH C-LOAN INTO :C-ID-HX, :C-PRIN, :C-BAL,
                                     :C-METHOD, :C-YEARS
               END-EXEC
               IF SQLCODE = 0 PERFORM EMIT-LOAN END-IF
           END-PERFORM
           EXEC SQL CLOSE C-LOAN END-EXEC
           STRING ']}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN.
       EMIT-LOAN.
           IF FIRST-ROW = 'Y' MOVE 'N' TO FIRST-ROW
           ELSE STRING ',' DELIMITED SIZE
                       INTO RESP-BUF WITH POINTER RESP-PTR
           END-IF
           MOVE C-ID-HX TO KY-HEX(1:24)
           MOVE 12 TO KY-N
           PERFORM DEC-KEY
           MOVE KY-STR(1:12) TO C-ID
           MOVE C-ID TO WK-NUM11
           PERFORM FMT-NUM
           STRING '{"loanId":' DELIMITED SIZE
                  FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  ',"principal":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE C-PRIN TO WK-NUM11 PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  ',"balance":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE C-BAL TO WK-NUM11 PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  ',"method":"' DELIMITED SIZE
                  C-METHOD DELIMITED SIZE
                  '","years":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE C-YEARS TO WK-NUM11
           PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  '}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR.
      *>-- 実行 -----------------------------------------------------
       DO-APPLY.
           MOVE "amt" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE FUNCTION NUMVAL(CP-VALUE) TO HV-AMT
           MOVE "method" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE(1:1) TO HV-METHOD
           IF HV-METHOD NOT = 'A' AND HV-METHOD NOT = 'B'
              AND HV-METHOD NOT = 'C'
               MOVE 'A' TO HV-METHOD
           END-IF
           MOVE "years" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE FUNCTION NUMVAL(CP-VALUE) TO HV-YEARS
           IF HV-AMT <= 0
               MOVE "invalid_amount" TO WK-ERRMSG PERFORM ERR-400
           END-IF
      *>   与信枠チェック(300万 - 現行残高合計)
           MOVE 0 TO HV-USED
           EXEC SQL
               SELECT NVL(SUM(BALANCE),0) INTO :HV-USED
                 FROM LOAN_ASIS
                WHERE KOUZA_NO = HEXTORAW(:HV-KZ-HEX)
                  AND STATUS = :HV-ACTIVE
           END-EXEC
           IF (HV-USED + HV-AMT) > LOAN-AVAIL
               MOVE "loan_over_limit" TO WK-ERRMSG PERFORM ERR-409
           END-IF
      *>   口座存在
           EXEC SQL
               SELECT COUNT(*) INTO :HV-CNT
                 FROM KOUZA WHERE KOUZA_NO = HEXTORAW(:HV-KZ-HEX)
           END-EXEC
           IF HV-CNT = 0
               MOVE "kouza_not_found" TO WK-ERRMSG PERFORM ERR-404
           END-IF
           EXEC SQL
               SELECT SEQ_LOAN_ASIS.NEXTVAL, SEQ_TORIHIKI.NEXTVAL
                 INTO :HV-LOANID, :HV-TID FROM DUAL
           END-EXEC
           MOVE FUNCTION CURRENT-DATE TO WK-NOW
           MOVE WK-NOW(1:14) TO HV-DT
      *>   PRINCIPAL と BALANCE に同一ホスト変数を2回使うと gixpp が
      *>   同一パラメータに畳み込み INSERT が失敗するため別変数にする。
           MOVE HV-AMT TO HV-BAL
           MOVE HV-LOANID TO KY-STR(1:12)
           MOVE 12 TO KY-N
           PERFORM ENC-KEY
           MOVE KY-HEX(1:24) TO HV-LOANID-HEX
           EXEC SQL
               INSERT INTO LOAN_ASIS
                 (LOAN_ID, KOUZA_NO, PRINCIPAL, BALANCE, METHOD,
                  TERM_YEARS, RATE, STATUS)
               VALUES
                 (HEXTORAW(:HV-LOANID-HEX), HEXTORAW(:HV-KZ-HEX),
                  :HV-AMT, :HV-BAL, :HV-METHOD,
                  :HV-YEARS, 2.5, 'ACTIVE')
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM LOAN-ABORT END-IF
           EXEC SQL
               SELECT RAWTOHEX(ZANDAKA) INTO :HV-ZAN-HX
                 FROM KOUZA WHERE KOUZA_NO = HEXTORAW(:HV-KZ-HEX)
           END-EXEC
           MOVE HV-ZAN-HX TO PK-HEX
           PERFORM DEC-P11
           ADD HV-AMT TO PK-P11
           PERFORM ENC-P11
           MOVE PK-HEX TO HV-ZAN-HX
           EXEC SQL
               UPDATE KOUZA SET ZANDAKA = HEXTORAW(:HV-ZAN-HX)
                WHERE KOUZA_NO = HEXTORAW(:HV-KZ-HEX)
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM LOAN-ABORT END-IF
           MOVE HV-AMT TO PK-P11
           PERFORM ENC-P11
           MOVE PK-HEX TO HV-AMT-HX
           MOVE HV-TID TO KY-STR(1:12)
           MOVE 12 TO KY-N
           PERFORM ENC-KEY
           MOVE KY-HEX(1:24) TO HV-TID-HEX
           EXEC SQL
               INSERT INTO TORIHIKI
                 (TORIHIKI_ID, KOUZA_NO, TORIHIKI_DT, TORIHIKI_KBN,
                  KINGAKU, AITE_KOUZA, TESURYO, TEKIYOU)
               VALUES
                 (HEXTORAW(:HV-TID-HEX), HEXTORAW(:HV-KZ-HEX),
                  :HV-DT, '1',
                  HEXTORAW(:HV-AMT-HX), NULL, NULL, NULL)
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM LOAN-ABORT END-IF
           EXEC SQL COMMIT END-EXEC
           MOVE 1 TO RESP-PTR MOVE SPACES TO RESP-BUF
           MOVE HV-LOANID TO WK-NUM11
           PERFORM FMT-NUM
           STRING '{"ok":true,"loanId":' DELIMITED SIZE
                  FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  ',"kouza":"' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-KOUZA TO WK-KOUZA-Z
           STRING WK-KOUZA-Z DELIMITED SIZE
                  '","amount":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-AMT TO WK-NUM11 PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  '}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN.
       LOAN-ABORT.
           EXEC SQL ROLLBACK END-EXEC
           PERFORM DB-DISCONNECT
           MOVE "loan_failed" TO WK-ERRMSG PERFORM ERR-500.
       COPY PFMTNUM.
       COPY PPACK.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM LOAN.
