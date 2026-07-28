      *>****************************************************************
      *> ZANDAKA  -  残高照会 CGI (オンライン 5種の1)
      *>   GET/POST: kouza=NNNNNNN (口座番号7桁)
      *>   応答(UTF-8 JSON):
      *>     {"ok":true,"kouza":"1000123","meigiKanji":"…",
      *>      "meigiKana":"…","shubetsu":"1","zandaka":523400,"joutai":"0"}
      *>   名義は KOUZA.MEIGI_KANJI(CP930 RAW原本) を TEAMEC で UTF-8 化。
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
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KOUZA    PIC 9(7).
       01  HV-KZ-HEX   PIC X(14).
       01  HV-KANJI    PIC X(20).
       01  HV-KANA     PIC X(20).
       01  HV-SHU      PIC X(01).
       01  HV-ZAN-HX   PIC X(12).
       01  HV-JOUTAI   PIC X(01).
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
               SELECT K.MEIGI_KANJI, K.MEIGI_KANA, K.SHUBETSU,
                      RAWTOHEX(K.ZANDAKA), K.JOUTAI,
                      X.KANJI_UTF8, X.KANA_UTF8
                 INTO :HV-KANJI, :HV-KANA, :HV-SHU,
                      :HV-ZAN-HX, :HV-JOUTAI, :HV-KANJI-M, :HV-KANA-M
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
      *>   名義漢字 RAW -> UTF-8
           MOVE HV-KANJI TO UT-RAW
           MOVE 20 TO UT-RAWLEN
           MOVE HV-KANJI-M TO UT-MIRROR
           CALL "RAWUTF8" USING UT-RAW UT-RAWLEN UT-MIRROR
                                UT-OUT UT-OUTLEN
           STRING '{"ok":true,"kouza":"' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-KOUZA TO WK-KOUZA-Z
           STRING WK-KOUZA-Z DELIMITED SIZE
                  '","meigiKanji":"' DELIMITED SIZE
                  UT-OUT(1:UT-OUTLEN) DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
      *>   名義カナ RAW -> UTF-8
           MOVE HV-KANA TO UT-RAW
           MOVE 20 TO UT-RAWLEN
           MOVE HV-KANA-M TO UT-MIRROR
           CALL "RAWUTF8" USING UT-RAW UT-RAWLEN UT-MIRROR
                                UT-OUT UT-OUTLEN
           STRING '","meigiKana":"' DELIMITED SIZE
                  UT-OUT(1:UT-OUTLEN) DELIMITED SIZE
                  '","shubetsu":"' DELIMITED SIZE
                  HV-SHU DELIMITED SIZE
                  '","zandaka":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-ZAN-HX TO PK-HEX
           PERFORM DEC-P11
           MOVE PK-P11 TO WK-NUM11
           PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  ',"joutai":"' DELIMITED SIZE
                  HV-JOUTAI DELIMITED SIZE
                  '"}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN.
       COPY PFMTNUM.
       COPY PPACK.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM ZANDAKA.
