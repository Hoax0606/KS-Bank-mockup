      *>****************************************************************
      *> HOLDINGS  -  保有口座 CGI (拡張)
      *>   GET: kouza -> その口座の保有情報を配列で返す。
      *>   ※ ASIS 契約(当方設計)では 1ログイン=1口座 を基本とし、
      *>     同一名義の複数口座グルーピングは未定(§8 相当)。ここでは
      *>     指定口座を 1要素配列で返す最小実装。拡張時は顧客IDで束ねる。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. HOLDINGS.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WCGI.
       COPY WONLINE.
       COPY WDB.
       01  WK-CNT      PIC 9(9) VALUE 0.
       COPY WPACK.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KOUZA    PIC 9(7).
       01  HV-KZ-HEX   PIC X(14).
       01  HV-KANJI    PIC X(20).
       01  HV-KANJI-M  PIC X(60).
       01  HV-SHU      PIC X(01).
       01  HV-TYPE     PIC X(6).
       01  HV-ZAN      PIC S9(11) COMP-3.
       01  HV-ZAN-HX   PIC X(12).
       01  HV-JOUTAI   PIC X(01).
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
           MOVE HV-KOUZA TO KY-STR(1:7)
           MOVE 7 TO KY-N
           PERFORM ENC-KEY
           MOVE KY-HEX(1:14) TO HV-KZ-HEX
           PERFORM DB-CONNECT
           MOVE 0 TO HV-CNT
           EXEC SQL
               SELECT COUNT(*) INTO :HV-CNT
                 FROM KOUZA WHERE KOUZA_NO = HEXTORAW(:HV-KZ-HEX)
           END-EXEC
           IF HV-CNT = 0
               PERFORM DB-DISCONNECT
               MOVE "kouza_not_found" TO WK-ERRMSG PERFORM ERR-404
           END-IF
           EXEC SQL
               SELECT K.MEIGI_KANJI, K.SHUBETSU, RAWTOHEX(K.ZANDAKA),
                      K.JOUTAI, X.KANJI_UTF8, X.ACCT_TYPE,
                      X.BRANCH_CODE, X.IS_PRIMARY
                 INTO :HV-KANJI, :HV-SHU, :HV-ZAN-HX, :HV-JOUTAI,
                      :HV-KANJI-M, :HV-TYPE, :HV-BR, :HV-PRIM
                 FROM KOUZA K, KOUZA_EXT X
                WHERE X.KOUZA_NO = K.KOUZA_NO
                  AND K.KOUZA_NO = HEXTORAW(:HV-KZ-HEX)
           END-EXEC
           PERFORM DB-DISCONNECT
           PERFORM BUILD-JSON
           CALL "CGIRESP" USING RESP
           STOP RUN.
       BUILD-JSON.
           MOVE 1 TO RESP-PTR MOVE SPACES TO RESP-BUF
           MOVE HV-KANJI TO UT-RAW MOVE 20 TO UT-RAWLEN
           MOVE HV-KANJI-M TO UT-MIRROR
           CALL "RAWUTF8" USING UT-RAW UT-RAWLEN UT-MIRROR
                                UT-OUT UT-OUTLEN
           MOVE HV-KOUZA TO WK-KOUZA-Z
           STRING '{"ok":true,"holdings":[{"kouza":"' DELIMITED SIZE
                  WK-KOUZA-Z DELIMITED SIZE
                  '","branch":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-BR) DELIMITED SIZE
                  '","meigiKanji":"' DELIMITED SIZE
                  UT-OUT(1:UT-OUTLEN) DELIMITED SIZE
                  '","shubetsu":"' DELIMITED SIZE
                  HV-SHU DELIMITED SIZE
                  '","type":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-TYPE) DELIMITED SIZE
                  '","joutai":"' DELIMITED SIZE
                  HV-JOUTAI DELIMITED SIZE
                  '","isPrimary":"' DELIMITED SIZE
                  HV-PRIM DELIMITED SIZE
                  '","zandaka":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-ZAN-HX TO PK-HEX
           PERFORM DEC-P11
           MOVE PK-P11 TO WK-NUM11
           PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  '}]}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN.
       COPY PFMTNUM.
       COPY PPACK.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM HOLDINGS.
