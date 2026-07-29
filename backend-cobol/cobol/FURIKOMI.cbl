      *>****************************************************************
      *> FURIKOMI  -  振込 CGI (オンライン 5種の1) ★原子的★
      *>   POST: kouza(振込元), aite(振込先), kingaku
      *>   手数料=定額110円。出金側 -(kingaku+110), 入金側 +kingaku を
      *>   1トランザクションで実施。失敗時 ROLLBACK / 成功時 COMMIT (§5)。
      *>   出金側 TORIHIKI: 区分3, KINGAKU=amt, TESURYO=110, AITE_KOUZA=先。
      *>   入金側 TORIHIKI: 区分1(振込先が自行口座に存在する場合のみ)。
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
       COPY WPACK.
       COPY WTXT.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KOUZA    PIC 9(7).
       01  HV-AITE     PIC 9(7).
       01  HV-KZ-HEX   PIC X(14).
       01  HV-AZ-HEX   PIC X(14).
       01  HV-TID-HEX  PIC X(24).
       01  HV-TID2-HEX PIC X(24).
       01  HV-AMT      PIC S9(11) COMP-3.
       01  HV-FEE      PIC S9(05) COMP-3 VALUE 110.
       01  HV-TOTAL    PIC S9(11) COMP-3.
       01  HV-ZAN      PIC S9(11) COMP-3.
       01  HV-ZAN-HX   PIC X(12).
       01  HV-AZAN-HX  PIC X(12).
       01  HV-AMT-HX   PIC X(12).
       01  HV-FEE-HX   PIC X(6).
       01  HV-JOU-HX   PIC X(4).
       01  HV-DT-HX    PIC X(30).
       01  HV-KBN3-HX  PIC X(2) VALUE 'F3'.
       01  HV-KBN1-HX  PIC X(2) VALUE 'F1'.
       01  HV-TID      PIC 9(12).
       01  HV-TID2     PIC 9(12).
       01  HV-DT       PIC X(14).
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
           MOVE HV-KOUZA TO KY-STR(1:7)
           MOVE 7 TO KY-N
           PERFORM ENC-KEY
           MOVE KY-HEX(1:14) TO HV-KZ-HEX
           MOVE HV-AITE TO KY-STR(1:7)
           MOVE 7 TO KY-N
           PERFORM ENC-KEY
           MOVE KY-HEX(1:14) TO HV-AZ-HEX
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
               SELECT RAWTOHEX(ZANDAKA), RAWTOHEX(JOUTAI)
                 INTO :HV-ZAN-HX, :HV-JOU-HX
                 FROM KOUZA WHERE KOUZA_NO = HEXTORAW(:HV-KZ-HEX)
           END-EXEC
           IF SQLCODE = 0 MOVE 'Y' TO WK-FOUND END-IF
           MOVE HV-ZAN-HX TO PK-HEX
           PERFORM DEC-P11
           MOVE PK-P11 TO HV-ZAN
           IF WK-FOUND NOT = 'Y'
               PERFORM DB-DISCONNECT
               MOVE "kouza_not_found" TO WK-ERRMSG PERFORM ERR-404
           END-IF
           IF HV-JOU-HX(1:2) = 'F9'
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
                 FROM KOUZA WHERE KOUZA_NO = HEXTORAW(:HV-AZ-HEX)
           END-EXEC
           MOVE HV-CNT TO WK-AITE-CNT
           EXEC SQL
               SELECT SEQ_TORIHIKI.NEXTVAL, SEQ_RECEIPT_ASIS.NEXTVAL
                 INTO :HV-TID, :HV-RSEQ FROM DUAL
           END-EXEC
           MOVE FUNCTION CURRENT-DATE TO WK-NOW
           MOVE WK-NOW(1:14) TO HV-DT
           MOVE HV-DT TO TX-UTF8
           MOVE 14 TO TX-ULEN
           PERFORM ENC-TXT
           MOVE TX-HEX(1:TX-HLEN) TO HV-DT-HX
      *>   ===== 原子的トランザクション開始 =====
           SUBTRACT HV-TOTAL FROM HV-ZAN
           MOVE HV-ZAN TO PK-P11
           PERFORM ENC-P11
           MOVE PK-HEX TO HV-ZAN-HX
           EXEC SQL
               UPDATE KOUZA SET ZANDAKA = HEXTORAW(:HV-ZAN-HX)
                WHERE KOUZA_NO = HEXTORAW(:HV-KZ-HEX)
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM TXN-ABORT END-IF
           MOVE HV-AMT TO PK-P11
           PERFORM ENC-P11
           MOVE PK-HEX TO HV-AMT-HX
           MOVE HV-FEE TO PK-P5
           PERFORM ENC-P5
           MOVE PK-HEX(1:6) TO HV-FEE-HX
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
                  HEXTORAW(RTRIM(:HV-DT-HX)), HEXTORAW(:HV-KBN3-HX),
                  HEXTORAW(:HV-AMT-HX), HEXTORAW(:HV-AZ-HEX),
                  HEXTORAW(:HV-FEE-HX), NULL)
           END-EXEC
           IF SQLCODE NOT = 0 PERFORM TXN-ABORT END-IF
           IF WK-AITE-CNT > 0
               EXEC SQL
                   SELECT RAWTOHEX(ZANDAKA) INTO :HV-AZAN-HX
                     FROM KOUZA WHERE KOUZA_NO = HEXTORAW(:HV-AZ-HEX)
               END-EXEC
               MOVE HV-AZAN-HX TO PK-HEX
               PERFORM DEC-P11
               ADD HV-AMT TO PK-P11
               PERFORM ENC-P11
               MOVE PK-HEX TO HV-AZAN-HX
               EXEC SQL
                   UPDATE KOUZA SET ZANDAKA = HEXTORAW(:HV-AZAN-HX)
                    WHERE KOUZA_NO = HEXTORAW(:HV-AZ-HEX)
               END-EXEC
               IF SQLCODE NOT = 0 PERFORM TXN-ABORT END-IF
               EXEC SQL
                   SELECT SEQ_TORIHIKI.NEXTVAL INTO :HV-TID2 FROM DUAL
               END-EXEC
               MOVE HV-TID2 TO KY-STR(1:12)
               MOVE 12 TO KY-N
               PERFORM ENC-KEY
               MOVE KY-HEX(1:24) TO HV-TID2-HEX
               EXEC SQL
                   INSERT INTO TORIHIKI
                     (TORIHIKI_ID, KOUZA_NO, TORIHIKI_DT, TORIHIKI_KBN,
                      KINGAKU, AITE_KOUZA, TESURYO, TEKIYOU)
                   VALUES
                     (HEXTORAW(:HV-TID2-HEX), HEXTORAW(:HV-AZ-HEX),
                      HEXTORAW(RTRIM(:HV-DT-HX)), HEXTORAW(:HV-KBN1-HX),
                      HEXTORAW(:HV-AMT-HX), NULL, NULL, NULL)
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
       COPY PPACK.
       COPY PTXT.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM FURIKOMI.
