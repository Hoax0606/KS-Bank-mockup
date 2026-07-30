      *>****************************************************************
      *> LOGIN  -  ログイン CGI (通常型/Shift-JIS DB版)
      *>   POST: branch(店番3桁), acct(口座番号7桁=KOUZA_NO), pw
      *>   全列を通常型で直接照合/取得(RAW/JEF/COMP-3 コーデック廃止)。
      *>   ※ DB は JA16SJIS 保存だが、GixSQL ドライバが取得時に UTF-8 へ
      *>     変換する(NLS_LANG は無視)。よって日本語列は UTF-8 バイトで
      *>     PIC X に入り、そのまま JSON(UTF-8)へ出力する。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOGIN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WCGI.
       COPY WONLINE.
       COPY WDB.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-BR       PIC X(3).
       01  HV-KOUZA    PIC 9(7).
       01  HV-PW       PIC X(60).
       01  HV-CNT      PIC 9(9).
       01  HV-KANJI    PIC X(40).
       01  HV-SHU      PIC X(1).
       01  HV-ZAN      PIC S9(11).
       01  HV-JOU      PIC X(1).
       01  HV-TYPE     PIC X(20).
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
                  AND KOUZA_NO    = :HV-KOUZA
                  AND PASSWORD    = RTRIM(:HV-PW)
           END-EXEC
           IF HV-CNT = 0
               PERFORM DB-DISCONNECT
               MOVE "invalid_login" TO WK-ERRMSG PERFORM ERR-409
           END-IF
           EXEC SQL
               SELECT K.MEIGI_KANJI, K.SHUBETSU,
                      K.ZANDAKA, K.JOUTAI, X.ACCT_TYPE
                 INTO :HV-KANJI, :HV-SHU, :HV-ZAN, :HV-JOU, :HV-TYPE
                 FROM KOUZA K, KOUZA_EXT X
                WHERE X.KOUZA_NO = K.KOUZA_NO
                  AND K.KOUZA_NO = :HV-KOUZA
           END-EXEC
           PERFORM DB-DISCONNECT
           PERFORM BUILD-JSON
           CALL "CGIRESP" USING RESP
           STOP RUN.
       BUILD-JSON.
           MOVE 1 TO RESP-PTR
           MOVE SPACES TO RESP-BUF
           MOVE HV-KOUZA TO WK-KOUZA-Z
           STRING '{"ok":true,"kouza":"' DELIMITED SIZE
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
                  '","zandaka":' DELIMITED SIZE
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
       END PROGRAM LOGIN.
