      *>****************************************************************
      *> LOAN  -  ローン CGI (拡張, 通常型/Shift-JIS DB版)
      *>   GET  : kouza -> 有効ローン一覧
      *>   POST : kouza, amt, method(A/B/C), years -> 実行(与信 300万上限)
      *>          口座残高へ入金 + LOAN_ASIS 追加 + TORIHIKI(区分1)
      *>   金額/年数=NUMBER, METHOD=CHAR(1), STATUS='ACTIVE' 直接。
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
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KOUZA    PIC 9(7).
       01  HV-AMT      PIC S9(11).
       01  HV-BAL      PIC S9(11).
       01  HV-ZAN      PIC S9(11).
       01  HV-METHOD   PIC X(1).
       01  HV-YEARS    PIC 9(3).
       01  HV-LOANID   PIC 9(12).
       01  HV-USED     PIC S9(13).
       01  HV-DT       PIC X(14).
       01  HV-TID      PIC 9(12).
       01  HV-CNT      PIC 9(9).
       01  HV-ACT      PIC X(10) VALUE 'ACTIVE'.
       01  C-ID        PIC 9(12).
       01  C-PRIN      PIC S9(11).
       01  C-BAL       PIC S9(11).
       01  C-METHOD    PIC X(1).
       01  C-YEARS     PIC 9(3).
       EXEC SQL END DECLARE SECTION END-EXEC.
       EXEC SQL
           DECLARE C-LOAN CURSOR FOR
             SELECT LOAN_ID, PRINCIPAL, BALANCE, METHOD, TERM_YEARS
               FROM LOAN_ASIS
              WHERE STATUS = RTRIM(:HV-ACT)
                AND KOUZA_NO = :HV-KOUZA
              ORDER BY LOAN_ID
       END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           CALL "CGIINIT" USING CGI-ENV
           MOVE "kouza" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE FUNCTION NUMVAL(CP-VALUE) TO HV-KOUZA
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
                   FETCH C-LOAN INTO :C-ID, :C-PRIN, :C-BAL,
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
      *>   与信枠チェック(300万 - 現行残高合計)。BALANCE は NUMBER なので SUM。
           EXEC SQL
               SELECT NVL(SUM(BALANCE),0) INTO :HV-USED
                 FROM LOAN_ASIS
                WHERE STATUS = RTRIM(:HV-ACT)
                  AND KOUZA_NO = :HV-KOUZA
           END-EXEC
           IF (HV-USED + HV-AMT) > LOAN-AVAIL
               MOVE "loan_over_limit" TO WK-ERRMSG PERFORM ERR-409
           END-IF
      *>   口座存在
           EXEC SQL
               SELECT COUNT(*) INTO :HV-CNT
                 FROM KOUZA WHERE KOUZA_NO = :HV-KOUZA
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
           EXEC SQL
               INSERT INTO LOAN_ASIS
                 (LOAN_ID, KOUZA_NO, PRINCIPAL, BALANCE, METHOD,
                  TERM_YEARS, RATE, STATUS)
               VALUES
                 (:HV-LOANID, :HV-KOUZA, :HV-AMT, :HV-BAL, :HV-METHOD,
                  :HV-YEARS, 2.5, RTRIM(:HV-ACT))
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM LOAN-ABORT END-IF
           EXEC SQL
               SELECT ZANDAKA INTO :HV-ZAN
                 FROM KOUZA WHERE KOUZA_NO = :HV-KOUZA
           END-EXEC
           ADD HV-AMT TO HV-ZAN
           EXEC SQL
               UPDATE KOUZA SET ZANDAKA = :HV-ZAN
                WHERE KOUZA_NO = :HV-KOUZA
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM LOAN-ABORT END-IF
           EXEC SQL
               INSERT INTO TORIHIKI
                 (TORIHIKI_ID, KOUZA_NO, TORIHIKI_DT, TORIHIKI_KBN,
                  KINGAKU, AITE_KOUZA, TESURYO, TEKIYOU)
               VALUES
                 (:HV-TID, :HV-KOUZA, :HV-DT, '1',
                  :HV-AMT, NULL, NULL, NULL)
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
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM LOAN.
