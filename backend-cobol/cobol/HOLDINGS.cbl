      *>****************************************************************
      *> HOLDINGS  -  保有口座 CGI (通常型/Shift-JIS DB版)
      *>   GET: kouza -> 指定口座を1要素配列で返す。全項目 通常列から直接。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. HOLDINGS.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WCGI.
       COPY WONLINE.
       COPY WDB.
       01  WK-CNT      PIC 9(9) VALUE 0.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KOUZA    PIC 9(7).
       01  HV-KANJI    PIC X(40).
       01  HV-SHU      PIC X(1).
       01  HV-TYPE     PIC X(20).
       01  HV-ZAN      PIC S9(11).
       01  HV-JOU      PIC X(1).
       01  HV-BR       PIC X(3).
       01  HV-PRIM     PIC X(1).
       01  HV-CNT      PIC 9(9).
       EXEC SQL END DECLARE SECTION END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           CALL "CGIINIT" USING CGI-ENV
           MOVE "kouza" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE FUNCTION NUMVAL(CP-VALUE) TO HV-KOUZA
           PERFORM DB-CONNECT
           MOVE 0 TO HV-CNT
           EXEC SQL
               SELECT COUNT(*) INTO :HV-CNT
                 FROM KOUZA WHERE KOUZA_NO = :HV-KOUZA
           END-EXEC
           IF HV-CNT = 0
               PERFORM DB-DISCONNECT
               MOVE "kouza_not_found" TO WK-ERRMSG PERFORM ERR-404
           END-IF
           EXEC SQL
               SELECT K.MEIGI_KANJI, K.SHUBETSU,
                      K.ZANDAKA, K.JOUTAI,
                      X.ACCT_TYPE, X.BRANCH_CODE, X.IS_PRIMARY
                 INTO :HV-KANJI, :HV-SHU, :HV-ZAN, :HV-JOU,
                      :HV-TYPE, :HV-BR, :HV-PRIM
                 FROM KOUZA K, KOUZA_EXT X
                WHERE X.KOUZA_NO = K.KOUZA_NO
                  AND K.KOUZA_NO = :HV-KOUZA
           END-EXEC
           PERFORM DB-DISCONNECT
           PERFORM BUILD-JSON
           CALL "CGIRESP" USING RESP
           STOP RUN.
       BUILD-JSON.
           MOVE 1 TO RESP-PTR MOVE SPACES TO RESP-BUF
           MOVE HV-KOUZA TO WK-KOUZA-Z
           STRING '{"ok":true,"holdings":[{"kouza":"' DELIMITED SIZE
                  WK-KOUZA-Z DELIMITED SIZE
                  '","branch":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-BR) DELIMITED SIZE
                  '","meigiKanji":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-KANJI) DELIMITED SIZE
                  '","shubetsu":"' DELIMITED SIZE
                  HV-SHU DELIMITED SIZE
                  '","type":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-TYPE) DELIMITED SIZE
                  '","joutai":"' DELIMITED SIZE
                  HV-JOU DELIMITED SIZE
                  '","isPrimary":"' DELIMITED SIZE
                  HV-PRIM DELIMITED SIZE
                  '","zandaka":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-ZAN TO WK-NUM11
           PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  '}]}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN.
       COPY PFMTNUM.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM HOLDINGS.
