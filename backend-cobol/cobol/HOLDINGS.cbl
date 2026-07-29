      *>****************************************************************
      *> HOLDINGS  -  保有口座 CGI (全RAW版)
      *>   GET: kouza -> 指定口座を1要素配列で返す。全項目 JEF RAW→UTF8 復号。
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
       COPY WTXT.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KOUZA    PIC 9(7).
       01  HV-KZ-HEX   PIC X(14).
       01  HV-KANJI    PIC X(20).
       01  HV-KANJI-M  PIC X(60).
       01  HV-SHU-HX   PIC X(4).
       01  HV-TYPE-HX  PIC X(24).
       01  HV-ZAN-HX   PIC X(12).
       01  HV-JOU-HX   PIC X(4).
       01  HV-BR-HX    PIC X(8).
       01  HV-PRIM-HX  PIC X(4).
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
               SELECT K.MEIGI_KANJI, RAWTOHEX(K.SHUBETSU),
                      RAWTOHEX(K.ZANDAKA), RAWTOHEX(K.JOUTAI),
                      X.KANJI_UTF8, RAWTOHEX(X.ACCT_TYPE),
                      RAWTOHEX(X.BRANCH_CODE), RAWTOHEX(X.IS_PRIMARY)
                 INTO :HV-KANJI, :HV-SHU-HX, :HV-ZAN-HX, :HV-JOU-HX,
                      :HV-KANJI-M, :HV-TYPE-HX, :HV-BR-HX, :HV-PRIM-HX
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
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-BR-HX TO TX-HEX
           MOVE FUNCTION STORED-CHAR-LENGTH(HV-BR-HX) TO TX-HLEN
           PERFORM DEC-TXT
           STRING TX-UTF8(1:TX-ULEN) DELIMITED SIZE
                  '","meigiKanji":"' DELIMITED SIZE
                  UT-OUT(1:UT-OUTLEN) DELIMITED SIZE
                  '","shubetsu":"' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-SHU-HX TO TX-HEX
           MOVE FUNCTION STORED-CHAR-LENGTH(HV-SHU-HX) TO TX-HLEN
           PERFORM DEC-TXT
           STRING TX-UTF8(1:TX-ULEN) DELIMITED SIZE
                  '","type":"' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-TYPE-HX TO TX-HEX
           MOVE FUNCTION STORED-CHAR-LENGTH(HV-TYPE-HX) TO TX-HLEN
           PERFORM DEC-TXT
           STRING TX-UTF8(1:TX-ULEN) DELIMITED SIZE
                  '","joutai":"' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-JOU-HX TO TX-HEX
           MOVE FUNCTION STORED-CHAR-LENGTH(HV-JOU-HX) TO TX-HLEN
           PERFORM DEC-TXT
           STRING TX-UTF8(1:TX-ULEN) DELIMITED SIZE
                  '","isPrimary":"' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-PRIM-HX TO TX-HEX
           MOVE FUNCTION STORED-CHAR-LENGTH(HV-PRIM-HX) TO TX-HLEN
           PERFORM DEC-TXT
           STRING TX-UTF8(1:TX-ULEN) DELIMITED SIZE
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
       COPY PTXT.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM HOLDINGS.
