      *>****************************************************************
      *> REPAY  -  ローン返済 CGI (拡張)
      *>   POST: loanId, principal
      *>   経過利息 = round(残高 * 年利% / 100 / 12), 中途手数料 = 550円。
      *>   引落合計 = 元金 + 利息 + 手数料。口座残高不足なら拒否。
      *>   全額返済で LOAN_ASIS.STATUS='CLOSED'。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. REPAY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WCGI.
       COPY WONLINE.
       COPY WDB.
       01  WK-CLOSED   PIC X(1) VALUE 'N'.
       01  WK-CALC     PIC S9(15)V999.
       01  WK-NOW      PIC X(21).
       01  WK-DATE     PIC X(8).
       COPY WPACK.
       COPY WTXT.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-LOANID   PIC 9(12).
       01  HV-LOANID-HEX PIC X(24).
       01  HV-PRIN     PIC S9(11) COMP-3.
       01  HV-BAL      PIC S9(11) COMP-3.
       01  HV-RATE     PIC S9(3)V999 COMP-3.
       01  HV-KOUZA    PIC 9(7).
       01  HV-KZ-HEX   PIC X(14).
       01  HV-INT      PIC S9(11) COMP-3.
       01  HV-FEE      PIC S9(11) COMP-3 VALUE 550.
       01  HV-TOTAL    PIC S9(11) COMP-3.
       01  HV-ZAN      PIC S9(11) COMP-3.
       01  HV-ZAN-HX   PIC X(12).
       01  HV-NEWBAL   PIC S9(11) COMP-3.
       01  HV-REPID    PIC 9(15).
       01  HV-REPID-HEX PIC X(30).
       01  HV-CNT      PIC 9(9).
       01  HV-ACT-HX   PIC X(12) VALUE 'C1C3E3C9E5C5'.
       01  HV-CLOSED-HX PIC X(12) VALUE 'C3D3D6E2C5C4'.
       01  HV-CDATE-HX PIC X(20).
       01  HV-BAL-HX   PIC X(12).
       01  HV-RATE-HX  PIC X(8).
       01  HV-PRIN-HX  PIC X(12).
       01  HV-INT-HX   PIC X(12).
       01  HV-FEE-HX   PIC X(12).
       01  HV-TOTAL-HX PIC X(12).
       01  HV-NEWBAL-HX PIC X(12).
       01  HV-ZERO-HX  PIC X(12).
       EXEC SQL END DECLARE SECTION END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           CALL "CGIINIT" USING CGI-ENV
           MOVE "loanId" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE FUNCTION NUMVAL(CP-VALUE) TO HV-LOANID
           MOVE HV-LOANID TO KY-STR(1:12)
           MOVE 12 TO KY-N
           PERFORM ENC-KEY
           MOVE KY-HEX(1:24) TO HV-LOANID-HEX
           MOVE "principal" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE FUNCTION NUMVAL(CP-VALUE) TO HV-PRIN
           IF HV-PRIN <= 0
               MOVE "invalid_amount" TO WK-ERRMSG PERFORM ERR-400
           END-IF
           PERFORM DB-CONNECT
           MOVE 0 TO HV-CNT
           EXEC SQL
               SELECT COUNT(*) INTO :HV-CNT FROM LOAN_ASIS
                WHERE LOAN_ID = HEXTORAW(:HV-LOANID-HEX)
                  AND STATUS = HEXTORAW(:HV-ACT-HX)
           END-EXEC
           IF HV-CNT = 0
               PERFORM DB-DISCONNECT
               MOVE "loan_not_found" TO WK-ERRMSG PERFORM ERR-404
           END-IF
           EXEC SQL
               SELECT RAWTOHEX(BALANCE), RAWTOHEX(RATE),
                      RAWTOHEX(KOUZA_NO)
                 INTO :HV-BAL-HX, :HV-RATE-HX, :HV-KZ-HEX
                 FROM LOAN_ASIS WHERE LOAN_ID = HEXTORAW(:HV-LOANID-HEX)
           END-EXEC
           MOVE HV-BAL-HX TO PK-HEX
           PERFORM DEC-P11
           MOVE PK-P11 TO HV-BAL
           MOVE HV-RATE-HX TO PK-HEX(1:8)
           PERFORM DEC-RATE
           MOVE PK-RATE TO HV-RATE
           IF HV-PRIN > HV-BAL
               PERFORM DB-DISCONNECT
               MOVE "over_balance" TO WK-ERRMSG PERFORM ERR-409
           END-IF
      *>   経過利息 = round(残高 * 年利/100 / 12)
           COMPUTE WK-CALC = HV-BAL * HV-RATE / 100 / 12
           COMPUTE HV-INT = FUNCTION INTEGER(WK-CALC + 0.5)
           MOVE 550 TO HV-FEE
           COMPUTE HV-TOTAL = HV-PRIN + HV-INT + HV-FEE
      *>   口座残高チェック
           EXEC SQL
               SELECT RAWTOHEX(ZANDAKA) INTO :HV-ZAN-HX
                 FROM KOUZA WHERE KOUZA_NO = HEXTORAW(:HV-KZ-HEX)
           END-EXEC
           MOVE HV-ZAN-HX TO PK-HEX
           PERFORM DEC-P11
           MOVE PK-P11 TO HV-ZAN
           IF HV-ZAN < HV-TOTAL
               PERFORM DB-DISCONNECT
               MOVE "insufficient_funds" TO WK-ERRMSG PERFORM ERR-409
           END-IF
           COMPUTE HV-NEWBAL = HV-BAL - HV-PRIN
           MOVE 'N' TO WK-CLOSED
           IF HV-NEWBAL <= 0 MOVE 'Y' TO WK-CLOSED END-IF
      *>   ===== トランザクション =====
           SUBTRACT HV-TOTAL FROM HV-ZAN
           MOVE HV-ZAN TO PK-P11
           PERFORM ENC-P11
           MOVE PK-HEX TO HV-ZAN-HX
           EXEC SQL
               UPDATE KOUZA SET ZANDAKA = HEXTORAW(:HV-ZAN-HX)
                WHERE KOUZA_NO = HEXTORAW(:HV-KZ-HEX)
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM RP-ABORT END-IF
      *>   新残高(または 0)を COMP-3 RAW へ符号化
           MOVE 0 TO PK-P11
           PERFORM ENC-P11
           MOVE PK-HEX TO HV-ZERO-HX
           MOVE HV-NEWBAL TO PK-P11
           PERFORM ENC-P11
           MOVE PK-HEX TO HV-NEWBAL-HX
           MOVE FUNCTION CURRENT-DATE TO WK-NOW
           MOVE WK-NOW(1:8) TO WK-DATE
           MOVE WK-DATE TO TX-UTF8
           MOVE 8 TO TX-ULEN
           PERFORM ENC-TXT
           MOVE TX-HEX(1:TX-HLEN) TO HV-CDATE-HX
           IF WK-CLOSED = 'Y'
               EXEC SQL
                   UPDATE LOAN_ASIS
                      SET BALANCE = HEXTORAW(:HV-ZERO-HX),
                          STATUS = HEXTORAW(:HV-CLOSED-HX),
                          CLOSED_DATE = HEXTORAW(RTRIM(:HV-CDATE-HX))
                    WHERE LOAN_ID = HEXTORAW(:HV-LOANID-HEX)
               END-EXEC
           ELSE
               EXEC SQL
                   UPDATE LOAN_ASIS
                      SET BALANCE = HEXTORAW(:HV-NEWBAL-HX)
                    WHERE LOAN_ID = HEXTORAW(:HV-LOANID-HEX)
               END-EXEC
           END-IF
           IF SQLCODE NOT = 0 PERFORM RP-ABORT END-IF
           EXEC SQL
               SELECT SEQ_REPAY_ASIS.NEXTVAL INTO :HV-REPID FROM DUAL
           END-EXEC
           MOVE HV-REPID TO KY-STR(1:15)
           MOVE 15 TO KY-N
           PERFORM ENC-KEY
           MOVE KY-HEX(1:30) TO HV-REPID-HEX
      *>   返済金額(元金/利息/手数料/合計)を COMP-3 RAW へ符号化
           MOVE HV-PRIN TO PK-P11
           PERFORM ENC-P11
           MOVE PK-HEX TO HV-PRIN-HX
           MOVE HV-INT TO PK-P11
           PERFORM ENC-P11
           MOVE PK-HEX TO HV-INT-HX
           MOVE HV-FEE TO PK-P11
           PERFORM ENC-P11
           MOVE PK-HEX TO HV-FEE-HX
           MOVE HV-TOTAL TO PK-P11
           PERFORM ENC-P11
           MOVE PK-HEX TO HV-TOTAL-HX
           EXEC SQL
               INSERT INTO LOAN_REPAY_ASIS
                 (REPAY_ID, LOAN_ID, PRINCIPAL, INTEREST, FEE, TOTAL)
               VALUES
                 (HEXTORAW(:HV-REPID-HEX), HEXTORAW(:HV-LOANID-HEX),
                  HEXTORAW(:HV-PRIN-HX), HEXTORAW(:HV-INT-HX),
                  HEXTORAW(:HV-FEE-HX), HEXTORAW(:HV-TOTAL-HX))
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM RP-ABORT END-IF
           EXEC SQL COMMIT END-EXEC
           PERFORM DB-DISCONNECT
           PERFORM BUILD-JSON
           CALL "CGIRESP" USING RESP
           STOP RUN.
       RP-ABORT.
           EXEC SQL ROLLBACK END-EXEC
           PERFORM DB-DISCONNECT
           MOVE "repay_failed" TO WK-ERRMSG PERFORM ERR-500.
       BUILD-JSON.
           MOVE 1 TO RESP-PTR MOVE SPACES TO RESP-BUF
           MOVE HV-LOANID TO WK-NUM11
           PERFORM FMT-NUM
           STRING '{"ok":true,"loanId":' DELIMITED SIZE
                  FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  ',"principal":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-PRIN TO WK-NUM11 PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  ',"interest":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-INT TO WK-NUM11 PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  ',"fee":550,"total":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-TOTAL TO WK-NUM11 PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  ',"loanBalance":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-NEWBAL TO WK-NUM11 PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  ',"closed":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           IF WK-CLOSED = 'Y'
               STRING 'true}' DELIMITED SIZE
                      INTO RESP-BUF WITH POINTER RESP-PTR
           ELSE
               STRING 'false}' DELIMITED SIZE
                      INTO RESP-BUF WITH POINTER RESP-PTR
           END-IF
           SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN.
       COPY PFMTNUM.
       COPY PPACK.
       COPY PTXT.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM REPAY.
