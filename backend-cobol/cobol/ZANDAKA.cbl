      *>****************************************************************
      *> ZANDAKA  -  残高照会 CGI (全RAW版)
      *>   GET/POST: kouza=NNNNNNN。名義=JEF RAW→UTF8, 種別/状態=JEF RAW→UTF8。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ZANDAKA.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WCGI.
       COPY WONLINE.
       COPY WDB.
       01  WK-FOUND    PIC X(1) VALUE 'N'.
       COPY WPACK.
       COPY WTXT.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KOUZA    PIC 9(7).
       01  HV-KZ-HEX   PIC X(14).
       01  HV-KANJI    PIC X(20).
       01  HV-KANA     PIC X(20).
       01  HV-SHU-HX   PIC X(4).
       01  HV-ZAN-HX   PIC X(12).
       01  HV-JOU-HX   PIC X(4).
       01  HV-KANJI-M  PIC X(60).
       01  HV-KANA-M   PIC X(60).
       EXEC SQL END DECLARE SECTION END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           CALL "CGIINIT" USING CGI-ENV
           MOVE "kouza" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           IF CP-FOUND NOT = 'Y'
               MOVE "missing_kouza" TO WK-ERRMSG
               PERFORM ERR-400
           END-IF
           MOVE FUNCTION NUMVAL(CP-VALUE) TO HV-KOUZA
           MOVE HV-KOUZA TO KY-STR(1:7)
           MOVE 7 TO KY-N
           PERFORM ENC-KEY
           MOVE KY-HEX(1:14) TO HV-KZ-HEX
           PERFORM DB-CONNECT
           EXEC SQL
               SELECT K.MEIGI_KANJI, K.MEIGI_KANA, RAWTOHEX(K.SHUBETSU),
                      RAWTOHEX(K.ZANDAKA), RAWTOHEX(K.JOUTAI),
                      X.KANJI_UTF8, X.KANA_UTF8
                 INTO :HV-KANJI, :HV-KANA, :HV-SHU-HX,
                      :HV-ZAN-HX, :HV-JOU-HX, :HV-KANJI-M, :HV-KANA-M
                 FROM KOUZA K, KOUZA_EXT X
                WHERE X.KOUZA_NO = K.KOUZA_NO
                  AND K.KOUZA_NO = HEXTORAW(:HV-KZ-HEX)
           END-EXEC
           IF SQLCODE = 0
               MOVE 'Y' TO WK-FOUND
           END-IF
           PERFORM DB-DISCONNECT
           IF WK-FOUND NOT = 'Y'
               MOVE "kouza_not_found" TO WK-ERRMSG
               PERFORM ERR-404
           END-IF
           PERFORM BUILD-JSON
           CALL "CGIRESP" USING RESP
           STOP RUN.
      *>-------------------------------------------------------------
       BUILD-JSON.
           MOVE 1 TO RESP-PTR
           MOVE SPACES TO RESP-BUF
           MOVE HV-KANJI TO UT-RAW
           MOVE 20 TO UT-RAWLEN
           MOVE HV-KANJI-M TO UT-MIRROR
           CALL "RAWUTF8" USING UT-RAW UT-RAWLEN UT-MIRROR
                                UT-OUT UT-OUTLEN
           MOVE HV-KOUZA TO WK-KOUZA-Z
           STRING '{"ok":true,"kouza":"' DELIMITED SIZE
                  WK-KOUZA-Z DELIMITED SIZE
                  '","meigiKanji":"' DELIMITED SIZE
                  UT-OUT(1:UT-OUTLEN) DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-KANA TO UT-RAW
           MOVE 20 TO UT-RAWLEN
           MOVE HV-KANA-M TO UT-MIRROR
           CALL "RAWUTF8" USING UT-RAW UT-RAWLEN UT-MIRROR
                                UT-OUT UT-OUTLEN
           STRING '","meigiKana":"' DELIMITED SIZE
                  UT-OUT(1:UT-OUTLEN) DELIMITED SIZE
                  '","shubetsu":"' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-SHU-HX TO TX-HEX
           MOVE FUNCTION STORED-CHAR-LENGTH(HV-SHU-HX) TO TX-HLEN
           PERFORM DEC-TXT
           STRING TX-UTF8(1:TX-ULEN) DELIMITED SIZE
                  '","zandaka":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-ZAN-HX TO PK-HEX
           PERFORM DEC-P11
           MOVE PK-P11 TO WK-NUM11
           PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  ',"joutai":"' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-JOU-HX TO TX-HEX
           MOVE FUNCTION STORED-CHAR-LENGTH(HV-JOU-HX) TO TX-HLEN
           PERFORM DEC-TXT
           STRING TX-UTF8(1:TX-ULEN) DELIMITED SIZE
                  '"}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN.
       COPY PFMTNUM.
       COPY PPACK.
       COPY PTXT.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM ZANDAKA.
