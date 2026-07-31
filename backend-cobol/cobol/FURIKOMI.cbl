      *>****************************************************************
      *> FURIKOMI  -  振込 CGI (オンライン 5種の1) ★原子的★
      *>   POST: kouza(振込元), aite(振込先), kingaku
      *>   手数料=定額110円。出金側 -(kingaku+110), 入金側 +kingaku を
      *>   1トランザクションで実施。失敗時 ROLLBACK / 成功時 COMMIT (§5)。
      *>   通常型/Shift-JIS DB版: 金額=NUMBER, 口座=NUMBER 直接。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. FURIKOMI.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WCGI.
       COPY WONLINE.
       COPY WDB.
       01  WK-NOW      PIC X(21).
       01  RCPT        PIC X(20).
       01  WK-FOUND    PIC X(1) VALUE 'N'.
       01  WK-AITE-CNT PIC 9(1) VALUE 0.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KOUZA    PIC 9(7).
       01  HV-AITE     PIC 9(7).
       01  HV-AMT      PIC S9(11).
       01  HV-FEE      PIC S9(05) VALUE 110.
       01  HV-TOTAL    PIC S9(11).
       01  HV-ZAN      PIC S9(11).
       01  HV-AZAN     PIC S9(11).
       01  HV-JOU      PIC X(1).
       01  HV-DT       PIC X(14).
       01  HV-TID      PIC 9(12).
       01  HV-TID2     PIC 9(12).
       01  HV-RSEQ     PIC 9(9).
       01  HV-CNT      PIC 9(9).
       EXEC SQL END DECLARE SECTION END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           CALL "CGIINIT" USING CGI-ENV
           MOVE "kouza" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           IF CP-FOUND NOT = 'Y'
               MOVE "missing_kouza" TO WK-ERRMSG PERFORM ERR-400
           END-IF
           MOVE FUNCTION NUMVAL(CP-VALUE) TO HV-KOUZA
           MOVE "aite" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           IF CP-FOUND NOT = 'Y'
               MOVE "missing_aite" TO WK-ERRMSG PERFORM ERR-400
           END-IF
           MOVE FUNCTION NUMVAL(CP-VALUE) TO HV-AITE
           MOVE "kingaku" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE FUNCTION NUMVAL(CP-VALUE) TO HV-AMT
           IF HV-AMT <= 0
               MOVE "invalid_amount" TO WK-ERRMSG PERFORM ERR-400
           END-IF
           MOVE 110 TO HV-FEE
           ADD HV-AMT HV-FEE GIVING HV-TOTAL
           PERFORM DB-CONNECT
           MOVE 'N' TO WK-FOUND
           EXEC SQL
               SELECT ZANDAKA, JOUTAI
                 INTO :HV-ZAN, :HV-JOU
                 FROM KOUZA WHERE KOUZA_NO = :HV-KOUZA
           END-EXEC
           IF SQLCODE = 0 MOVE 'Y' TO WK-FOUND END-IF
           IF WK-FOUND NOT = 'Y'
               PERFORM DB-DISCONNECT
               MOVE "kouza_not_found" TO WK-ERRMSG PERFORM ERR-404
           END-IF
           IF HV-JOU = '9'
               PERFORM DB-DISCONNECT
               MOVE "account_frozen" TO WK-ERRMSG PERFORM ERR-409
           END-IF
           IF HV-ZAN < HV-TOTAL
               PERFORM DB-DISCONNECT
               MOVE "insufficient_funds" TO WK-ERRMSG PERFORM ERR-409
           END-IF
      *>   振込先が自行に存在するか
           EXEC SQL
               SELECT COUNT(*) INTO :HV-CNT
                 FROM KOUZA WHERE KOUZA_NO = :HV-AITE
           END-EXEC
           MOVE HV-CNT TO WK-AITE-CNT
           EXEC SQL
               SELECT SEQ_TORIHIKI.NEXTVAL, SEQ_RECEIPT_ASIS.NEXTVAL
                 INTO :HV-TID, :HV-RSEQ FROM DUAL
           END-EXEC
           MOVE FUNCTION CURRENT-DATE TO WK-NOW
           MOVE WK-NOW(1:14) TO HV-DT
      *>   ===== 原子的トランザクション開始 =====
           SUBTRACT HV-TOTAL FROM HV-ZAN
           EXEC SQL
               UPDATE KOUZA SET ZANDAKA = :HV-ZAN
                WHERE KOUZA_NO = :HV-KOUZA
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM TXN-ABORT END-IF
           EXEC SQL
               INSERT INTO TORIHIKI
                 (TORIHIKI_ID, KOUZA_NO, TORIHIKI_DT, TORIHIKI_KBN,
                  KINGAKU, AITE_KOUZA, TESURYO, TEKIYOU)
               VALUES
                 (:HV-TID, :HV-KOUZA, :HV-DT, '3',
                  :HV-AMT, :HV-AITE, :HV-FEE, NULL)
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM TXN-ABORT END-IF
           IF WK-AITE-CNT > 0
               EXEC SQL
                   SELECT ZANDAKA INTO :HV-AZAN
                     FROM KOUZA WHERE KOUZA_NO = :HV-AITE
               END-EXEC
               ADD HV-AMT TO HV-AZAN
               EXEC SQL
                   UPDATE KOUZA SET ZANDAKA = :HV-AZAN
                    WHERE KOUZA_NO = :HV-AITE
               END-EXEC
               IF SQLCODE NOT = 0 PERFORM TXN-ABORT END-IF
               EXEC SQL
                   SELECT SEQ_TORIHIKI.NEXTVAL INTO :HV-TID2 FROM DUAL
               END-EXEC
               EXEC SQL
                   INSERT INTO TORIHIKI
                     (TORIHIKI_ID, KOUZA_NO, TORIHIKI_DT, TORIHIKI_KBN,
                      KINGAKU, AITE_KOUZA, TESURYO, TEKIYOU)
                   VALUES
                     (:HV-TID2, :HV-AITE, :HV-DT, '1',
                      :HV-AMT, NULL, NULL, NULL)
               END-EXEC
               IF SQLCODE NOT = 0 PERFORM TXN-ABORT END-IF
           END-IF
           EXEC SQL COMMIT END-EXEC
      *>   ===== 原子的トランザクション終了 =====
      *>   HV-ZAN は既に振込後残高(上で減算済)
           PERFORM DB-DISCONNECT
           PERFORM MAKE-RCPT
           PERFORM BUILD-JSON
           CALL "CGIRESP" USING RESP
           STOP RUN.
       TXN-ABORT.
           EXEC SQL ROLLBACK END-EXEC
           PERFORM DB-DISCONNECT
           MOVE "transfer_failed" TO WK-ERRMSG
           PERFORM ERR-500.
       MAKE-RCPT.
           MOVE SPACES TO RCPT
           MOVE FUNCTION MOD(HV-RSEQ, 10000) TO WK-NUM11-U
           STRING "WEB" DELIMITED SIZE
                  HV-DT(1:8) DELIMITED SIZE
                  "-" DELIMITED SIZE
                  WK-NUM11-U(8:4) DELIMITED SIZE
                  INTO RCPT.
       BUILD-JSON.
           MOVE 1 TO RESP-PTR
           MOVE SPACES TO RESP-BUF
           MOVE HV-KOUZA TO WK-KOUZA-Z
           STRING '{"ok":true,"kouza":"' DELIMITED SIZE
                  WK-KOUZA-Z DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-AITE TO WK-KOUZA-Z
           STRING '","aite":"' DELIMITED SIZE
                  WK-KOUZA-Z DELIMITED SIZE
                  '","receipt":"' DELIMITED SIZE
                  FUNCTION TRIM(RCPT) DELIMITED SIZE
                  '","dt":"' DELIMITED SIZE
                  HV-DT DELIMITED SIZE
                  '","fee":110,"afterBal":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-ZAN TO WK-NUM11
           PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  '}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN.
       COPY PFMTNUM.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM FURIKOMI.
