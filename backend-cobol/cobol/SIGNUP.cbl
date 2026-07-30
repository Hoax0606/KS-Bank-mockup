      *>****************************************************************
      *> SIGNUP  -  新規口座開設 CGI (通常型/Shift-JIS DB版)
      *>   POST: kanji, kana, type, branch, pw, birth, sex, zip, addr,
      *>         phone, email, job
      *>   動的帯域(SEQ_KOUZA_DYN, 7桁 9000001~)で採番。
      *>   名義等は UTF-8 のまま INSERT(GixSQL→OCI が DB の JA16SJIS へ変換)。
      *>   ※ プロフィール列は NULL 可のため必須列のみ INSERT。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SIGNUP.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WCGI.
       COPY WONLINE.
       COPY WDB.
       01  WK-NOW      PIC X(21).
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KANJI    PIC X(60).
       01  HV-KANA     PIC X(60).
       01  HV-BR       PIC X(3).
       01  HV-TYPE     PIC X(20).
       01  HV-PW       PIC X(60).
       01  HV-SHU      PIC X(1).
       01  HV-KAI      PIC X(8).
       01  HV-NEWNO    PIC 9(7).
       EXEC SQL END DECLARE SECTION END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           CALL "CGIINIT" USING CGI-ENV
           MOVE "kanji"  TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE TO HV-KANJI
           MOVE "kana"   TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE TO HV-KANA
           MOVE "branch" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE(1:3) TO HV-BR
           MOVE "type"   TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE TO HV-TYPE
           MOVE "pw"     TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE TO HV-PW
           IF HV-KANJI = SPACES OR HV-PW = SPACES
               MOVE "missing_required" TO WK-ERRMSG PERFORM ERR-400
           END-IF
      *>   種別 -> SHUBETSU(2=当座 / それ以外=1=普通系)。CHECK は 1/2 のみ。
           IF HV-TYPE(1:6) = "当座"
               MOVE '2' TO HV-SHU
           ELSE
               MOVE '1' TO HV-SHU
           END-IF
           MOVE FUNCTION CURRENT-DATE TO WK-NOW
           MOVE WK-NOW(1:8) TO HV-KAI
           PERFORM DB-CONNECT
           EXEC SQL
               SELECT SEQ_KOUZA_DYN.NEXTVAL INTO :HV-NEWNO FROM DUAL
           END-EXEC
           EXEC SQL
               INSERT INTO KOUZA
                 (KOUZA_NO, MEIGI_KANJI, MEIGI_KANA, SHUBETSU,
                  ZANDAKA, KAISETSU_BI, JOUTAI)
               VALUES
                 (:HV-NEWNO, RTRIM(:HV-KANJI), RTRIM(:HV-KANA),
                  :HV-SHU, 0, :HV-KAI, '0')
           END-EXEC
           IF SQLCODE NOT = 0
               EXEC SQL ROLLBACK END-EXEC
               PERFORM DB-DISCONNECT
               MOVE "signup_failed" TO WK-ERRMSG PERFORM ERR-500
           END-IF
           EXEC SQL
               INSERT INTO KOUZA_EXT
                 (KOUZA_NO, BRANCH_CODE, ACCT_TYPE,
                  PASSWORD, IS_PRIMARY)
               VALUES
                 (:HV-NEWNO, RTRIM(:HV-BR), RTRIM(:HV-TYPE),
                  RTRIM(:HV-PW), 'N')
           END-EXEC
           IF SQLCODE NOT = 0
               EXEC SQL ROLLBACK END-EXEC
               PERFORM DB-DISCONNECT
               MOVE "signup_failed" TO WK-ERRMSG PERFORM ERR-500
           END-IF
           EXEC SQL COMMIT END-EXEC
           PERFORM DB-DISCONNECT
           PERFORM BUILD-JSON
           CALL "CGIRESP" USING RESP
           STOP RUN.
       BUILD-JSON.
           MOVE 1 TO RESP-PTR
           MOVE SPACES TO RESP-BUF
           MOVE HV-NEWNO TO WK-KOUZA-Z
           STRING '{"ok":true,"kouza":"' DELIMITED SIZE
                  WK-KOUZA-Z DELIMITED SIZE
                  '","branch":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-BR) DELIMITED SIZE
                  '","type":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-TYPE) DELIMITED SIZE
                  '","shubetsu":"' DELIMITED SIZE
                  HV-SHU DELIMITED SIZE
                  '"}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN.
       COPY PFMTNUM.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM SIGNUP.
