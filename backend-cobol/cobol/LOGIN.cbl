      *>****************************************************************
      *> LOGIN  -  ログイン CGI (拡張)
      *>   POST: branch(店番3桁), acct(口座番号7桁=KOUZA_NO), pw
      *>   KOUZA_EXT の 店番(BRANCH_CODE 3桁)+PW を検証し、口座情報を返す。
      *>   ※ 口座番号=KOUZA_NO は 7桁(PIC 9(7))。店番は別カラム(3桁)。
      *>      フロントも 店番3桁+口座7桁+PW を送る(同一契約)。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOGIN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WCGI.
       COPY WONLINE.
       COPY WDB.
       01  WK-OK       PIC X(1) VALUE 'N'.
       COPY WPACK.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-BR       PIC X(3).
       01  HV-KOUZA    PIC 9(7).
       01  HV-KZ-HEX   PIC X(14).
       01  HV-PW       PIC X(60).
       01  HV-CNT      PIC 9(9).
       01  HV-KANJI    PIC X(20).
       01  HV-KANJI-M  PIC X(60).
       01  HV-SHU      PIC X(01).
       01  HV-TYPE     PIC X(6).
       01  HV-ZAN-HX   PIC X(12).
       01  HV-JOUTAI   PIC X(01).
       EXEC SQL END DECLARE SECTION END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           CALL "CGIINIT" USING CGI-ENV
           MOVE "branch" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE(1:3) TO HV-BR
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
           PERFORM DB-CONNECT
           EXEC SQL
               SELECT COUNT(*) INTO :HV-CNT
                 FROM KOUZA_EXT
                WHERE BRANCH_CODE = RTRIM(:HV-BR)
                  AND KOUZA_NO    = HEXTORAW(:HV-KZ-HEX)
                  AND RTRIM(PASSWORD) = RTRIM(:HV-PW)
           END-EXEC
           IF HV-CNT = 0
               PERFORM DB-DISCONNECT
               MOVE "invalid_login" TO WK-ERRMSG PERFORM ERR-409
           END-IF
           EXEC SQL
               SELECT K.MEIGI_KANJI, K.SHUBETSU, RAWTOHEX(K.ZANDAKA),
                      K.JOUTAI, X.KANJI_UTF8, X.ACCT_TYPE
                 INTO :HV-KANJI, :HV-SHU, :HV-ZAN-HX, :HV-JOUTAI,
                      :HV-KANJI-M, :HV-TYPE
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
           MOVE HV-KANJI TO UT-RAW MOVE 20 TO UT-RAWLEN
           MOVE HV-KANJI-M TO UT-MIRROR
           CALL "RAWUTF8" USING UT-RAW UT-RAWLEN UT-MIRROR
                                UT-OUT UT-OUTLEN
           MOVE HV-KOUZA TO WK-KOUZA-Z
           STRING '{"ok":true,"kouza":"' DELIMITED SIZE
                  WK-KOUZA-Z DELIMITED SIZE
                  '","branch":"' DELIMITED SIZE
                  HV-BR DELIMITED SIZE
                  '","meigiKanji":"' DELIMITED SIZE
                  UT-OUT(1:UT-OUTLEN) DELIMITED SIZE
                  '","shubetsu":"' DELIMITED SIZE
                  HV-SHU DELIMITED SIZE
                  '","type":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-TYPE) DELIMITED SIZE
                  '","joutai":"' DELIMITED SIZE
                  HV-JOUTAI DELIMITED SIZE
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
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM LOGIN.
