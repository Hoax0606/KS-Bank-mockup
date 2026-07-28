      *>****************************************************************
      *> NYUKIN  -  入金 CGI (オンライン 5種の1)
      *>   POST: kouza, kingaku
      *>   KOUZA.ZANDAKA += kingaku, TORIHIKI(区分1) 追記, COMMIT。
      *>   凍結(JOUTAI=9)口座は拒否(§8.4 の一貫方針: 凍結=取引不可)。
      *>   摘要(TEKIYOU)はオンライン生成分は NULL(EBCDIC原本はバッチ/シード側)。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. NYUKIN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WCGI.
       COPY WONLINE.
       COPY WDB.
       01  WK-NOW      PIC X(21).
       01  RCPT        PIC X(20).
       01  WK-FOUND    PIC X(1) VALUE 'N'.
       COPY WPACK.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KOUZA    PIC 9(7).
       01  HV-KZ-HEX   PIC X(14).
       01  HV-TID-HEX  PIC X(24).
       01  HV-AMT      PIC S9(11) COMP-3.
       01  HV-ZAN      PIC S9(11) COMP-3.
       01  HV-ZAN-HX   PIC X(12).
       01  HV-AMT-HX   PIC X(12).
       01  HV-JOUTAI   PIC X(01).
       01  HV-TID      PIC 9(12).
       01  HV-DT       PIC X(14).
       01  HV-RSEQ     PIC 9(9).
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
           MOVE HV-KOUZA TO KY-STR(1:7)
           MOVE 7 TO KY-N
           PERFORM ENC-KEY
           MOVE KY-HEX(1:14) TO HV-KZ-HEX
           MOVE "kingaku" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE FUNCTION NUMVAL(CP-VALUE) TO HV-AMT
           IF HV-AMT <= 0
               MOVE "invalid_amount" TO WK-ERRMSG PERFORM ERR-400
           END-IF
           PERFORM DB-CONNECT
      *>   口座存在/状態チェック
           MOVE 'N' TO WK-FOUND
           EXEC SQL
               SELECT JOUTAI INTO :HV-JOUTAI
                 FROM KOUZA WHERE KOUZA_NO = HEXTORAW(:HV-KZ-HEX)
           END-EXEC
           IF SQLCODE = 0 MOVE 'Y' TO WK-FOUND END-IF
           IF WK-FOUND NOT = 'Y'
               PERFORM DB-DISCONNECT
               MOVE "kouza_not_found" TO WK-ERRMSG PERFORM ERR-404
           END-IF
           IF HV-JOUTAI = '9'
               PERFORM DB-DISCONNECT
               MOVE "account_frozen" TO WK-ERRMSG PERFORM ERR-409
           END-IF
      *>   採番・日時
           EXEC SQL
               SELECT SEQ_TORIHIKI.NEXTVAL, SEQ_RECEIPT_ASIS.NEXTVAL
                 INTO :HV-TID, :HV-RSEQ FROM DUAL
           END-EXEC
           MOVE FUNCTION CURRENT-DATE TO WK-NOW
           MOVE WK-NOW(1:14) TO HV-DT
      *>   残高更新 + 明細追記(1トランザクション)
      *>   현재 잔액(RAW COMP-3) 읽어 COBOL에서 가산 후 다시 저장
           EXEC SQL
               SELECT RAWTOHEX(ZANDAKA) INTO :HV-ZAN-HX
                 FROM KOUZA WHERE KOUZA_NO = HEXTORAW(:HV-KZ-HEX)
           END-EXEC
           MOVE HV-ZAN-HX TO PK-HEX
           PERFORM DEC-P11
           ADD HV-AMT TO PK-P11
           MOVE PK-P11 TO HV-ZAN
           PERFORM ENC-P11
           MOVE PK-HEX TO HV-ZAN-HX
           EXEC SQL
               UPDATE KOUZA SET ZANDAKA = HEXTORAW(:HV-ZAN-HX)
                WHERE KOUZA_NO = HEXTORAW(:HV-KZ-HEX)
           END-EXEC
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
           IF SQLCODE NOT = 0
               EXEC SQL ROLLBACK END-EXEC
               PERFORM DB-DISCONNECT
               MOVE "txn_failed" TO WK-ERRMSG PERFORM ERR-500
           END-IF
           EXEC SQL COMMIT END-EXEC
           PERFORM DB-DISCONNECT
      *>   受付番号 DEP + YYYYMMDD + '-' + 連番下4桁
           PERFORM MAKE-RCPT
           PERFORM BUILD-JSON
           CALL "CGIRESP" USING RESP
           STOP RUN.
       MAKE-RCPT.
           MOVE SPACES TO RCPT
           MOVE FUNCTION MOD(HV-RSEQ, 10000) TO WK-NUM11-U
           STRING "DEP" DELIMITED SIZE
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
                  '","receipt":"' DELIMITED SIZE
                  FUNCTION TRIM(RCPT) DELIMITED SIZE
                  '","dt":"' DELIMITED SIZE
                  HV-DT DELIMITED SIZE
                  '","afterBal":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-ZAN TO WK-NUM11
           PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  '}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN.
       COPY PFMTNUM.
       COPY PPACK.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM NYUKIN.
