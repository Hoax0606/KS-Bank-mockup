      *>****************************************************************
      *> LOGIN  -  ログイン CGI (全RAW版)
      *>   POST: branch(店番3桁), acct(口座番号7桁=KOUZA_NO), pw
      *>   店番/PW を JEF 符号化して RAW 比較。SHUBETSU/JOUTAI/ACCT_TYPE
      *>   は RAW を読み JEF 復号して UTF-8 で返す。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOGIN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WCGI.
       COPY WONLINE.
       COPY WDB.
       01  WK-OK       PIC X(1) VALUE 'N'.
       01  WK-SHU-U    PIC X(8).
       01  WK-SHU-L    PIC 9(4).
       01  WK-JOU-U    PIC X(8).
       01  WK-JOU-L    PIC 9(4).
       01  WK-TYPE-U   PIC X(48).
       01  WK-TYPE-L   PIC 9(4).
       COPY WPACK.
       COPY WTXT.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-BR       PIC X(3).
       01  HV-BR-HX    PIC X(8).
       01  HV-KOUZA    PIC 9(7).
       01  HV-KZ-HEX   PIC X(14).
       01  HV-PW       PIC X(60).
       01  HV-PW-HX    PIC X(128).
       01  HV-CNT      PIC 9(9).
       01  HV-KANJI    PIC X(20).
       01  HV-KANJI-M  PIC X(60).
       01  HV-SHU-HX   PIC X(4).
       01  HV-TYPE-HX  PIC X(24).
       01  HV-ZAN-HX   PIC X(12).
       01  HV-JOU-HX   PIC X(4).
       EXEC SQL END DECLARE SECTION END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           CALL "CGIINIT" USING CGI-ENV
           MOVE "branch" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE(1:3) TO HV-BR
           MOVE HV-BR TO TX-UTF8
           MOVE 3 TO TX-ULEN
           PERFORM ENC-TXT
           MOVE TX-HEX(1:TX-HLEN) TO HV-BR-HX
           MOVE "acct" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE FUNCTION NUMVAL(CP-VALUE) TO HV-KOUZA
           MOVE HV-KOUZA TO KY-STR(1:7)
           MOVE 7 TO KY-N
           PERFORM ENC-KEY
           MOVE KY-HEX(1:14) TO HV-KZ-HEX
           MOVE "pw" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE TO HV-PW
           IF HV-PW = SPACES
               MOVE "invalid_login" TO WK-ERRMSG PERFORM ERR-409
           END-IF
           MOVE HV-PW TO TX-UTF8
           MOVE FUNCTION STORED-CHAR-LENGTH(HV-PW) TO TX-ULEN
           PERFORM ENC-TXT
           MOVE TX-HEX(1:TX-HLEN) TO HV-PW-HX
           PERFORM DB-CONNECT
           EXEC SQL
               SELECT COUNT(*) INTO :HV-CNT
                 FROM KOUZA_EXT
                WHERE BRANCH_CODE = HEXTORAW(RTRIM(:HV-BR-HX))
                  AND KOUZA_NO    = HEXTORAW(:HV-KZ-HEX)
                  AND PASSWORD    = HEXTORAW(RTRIM(:HV-PW-HX))
           END-EXEC
           IF HV-CNT = 0
               PERFORM DB-DISCONNECT
               MOVE "invalid_login" TO WK-ERRMSG PERFORM ERR-409
           END-IF
           EXEC SQL
               SELECT K.MEIGI_KANJI, RAWTOHEX(K.SHUBETSU),
                      RAWTOHEX(K.ZANDAKA), RAWTOHEX(K.JOUTAI),
                      X.KANJI_UTF8, RAWTOHEX(X.ACCT_TYPE)
                 INTO :HV-KANJI, :HV-SHU-HX, :HV-ZAN-HX, :HV-JOU-HX,
                      :HV-KANJI-M, :HV-TYPE-HX
                 FROM KOUZA K, KOUZA_EXT X
                WHERE X.KOUZA_NO = K.KOUZA_NO
                  AND K.KOUZA_NO = HEXTORAW(:HV-KZ-HEX)
           END-EXEC
           PERFORM DB-DISCONNECT
           PERFORM BUILD-JSON
           CALL "CGIRESP" USING RESP
           STOP RUN.
       BUILD-JSON.
           MOVE 1 TO RESP-PTR
           MOVE SPACES TO RESP-BUF
           MOVE HV-KANJI TO UT-RAW
           MOVE 20 TO UT-RAWLEN
           MOVE HV-KANJI-M TO UT-MIRROR
           CALL "RAWUTF8" USING UT-RAW UT-RAWLEN UT-MIRROR
                                UT-OUT UT-OUTLEN
           MOVE HV-SHU-HX TO TX-HEX
           MOVE FUNCTION STORED-CHAR-LENGTH(HV-SHU-HX) TO TX-HLEN
           PERFORM DEC-TXT
           MOVE TX-UTF8(1:TX-ULEN) TO WK-SHU-U
           MOVE TX-ULEN TO WK-SHU-L
           MOVE HV-JOU-HX TO TX-HEX
           MOVE FUNCTION STORED-CHAR-LENGTH(HV-JOU-HX) TO TX-HLEN
           PERFORM DEC-TXT
           MOVE TX-UTF8(1:TX-ULEN) TO WK-JOU-U
           MOVE TX-ULEN TO WK-JOU-L
           MOVE HV-TYPE-HX TO TX-HEX
           MOVE FUNCTION STORED-CHAR-LENGTH(HV-TYPE-HX) TO TX-HLEN
           PERFORM DEC-TXT
           MOVE TX-UTF8(1:TX-ULEN) TO WK-TYPE-U
           MOVE TX-ULEN TO WK-TYPE-L
           MOVE HV-KOUZA TO WK-KOUZA-Z
           STRING '{"ok":true,"kouza":"' DELIMITED SIZE
                  WK-KOUZA-Z DELIMITED SIZE
                  '","branch":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-BR) DELIMITED SIZE
                  '","meigiKanji":"' DELIMITED SIZE
                  UT-OUT(1:UT-OUTLEN) DELIMITED SIZE
                  '","shubetsu":"' DELIMITED SIZE
                  WK-SHU-U(1:WK-SHU-L) DELIMITED SIZE
                  '","type":"' DELIMITED SIZE
                  WK-TYPE-U(1:WK-TYPE-L) DELIMITED SIZE
                  '","joutai":"' DELIMITED SIZE
                  WK-JOU-U(1:WK-JOU-L) DELIMITED SIZE
                  '","zandaka":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-ZAN-HX TO PK-HEX
           PERFORM DEC-P11
           MOVE PK-P11 TO WK-NUM11
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
       END PROGRAM LOGIN.
