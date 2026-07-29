      *>****************************************************************
      *> SIGNUP  -  新規口座開設 CGI (拡張)
      *>   POST: kanji, kana, type, branch, pw, birth, sex, zip, addr,
      *>         phone, email, job
      *>   動的帯域(SEQ_KOUZA_DYN, 7桁 9000001~)で採番。
      *>   MEIGI_KANJI/KANA は SQL 側 KANJI2EBC/KANA2EBC(デモ・エンコーダ)
      *>   で RAW 生成。UTF-8 ミラーも KOUZA_EXT に保持。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SIGNUP.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WCGI.
       COPY WONLINE.
       COPY WDB.
       01  WK-NOW      PIC X(21).
       01  JC-MODE     PIC X.
       01  JC-INLEN    PIC 9(4).
       01  JC-OUTLEN   PIC 9(4).
       COPY WPACK.
       COPY WTXT.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KANJI-U  PIC X(60).
       01  HV-KANA-U   PIC X(60).
       01  HV-BR       PIC X(3).
       01  HV-TYPE     PIC X(6).
       01  HV-PW       PIC X(60).
       01  HV-SHU      PIC X(1).
       01  HV-KAI      PIC X(8).
       01  HV-NEWNO    PIC 9(7).
       01  HV-NEWNO-HEX PIC X(14).
       01  HV-BIRTH    PIC X(10).
       01  HV-SEX      PIC X(6).
       01  HV-ZIP      PIC X(7).
       01  HV-ADDR     PIC X(200).
       01  HV-PHONE    PIC X(13).
       01  HV-EMAIL    PIC X(120).
       01  HV-JOB      PIC X(40).
       01  HV-KANJI-HEX PIC X(40).
       01  HV-KANA-HEX  PIC X(40).
       01  HV-SHU-HX   PIC X(4).
       01  HV-KAI-HX   PIC X(20).
       01  HV-BR-HX    PIC X(8).
       01  HV-TYPE-HX  PIC X(24).
       01  HV-PW-HX    PIC X(128).
       01  HV-JOU-HX   PIC X(2) VALUE 'F0'.
       01  HV-PRIM-HX  PIC X(2) VALUE 'D5'.
       EXEC SQL END DECLARE SECTION END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           CALL "CGIINIT" USING CGI-ENV
           MOVE "kanji"  TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE TO HV-KANJI-U
           MOVE "kana"   TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE TO HV-KANA-U
           MOVE "branch" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE(1:3) TO HV-BR
           MOVE "type"   TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE(1:6) TO HV-TYPE
           MOVE "pw"     TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE TO HV-PW
           MOVE "birth"  TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE(1:10) TO HV-BIRTH
           MOVE "sex"    TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE(1:6) TO HV-SEX
           MOVE "zip"    TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE(1:7) TO HV-ZIP
           MOVE "addr"   TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE TO HV-ADDR
           MOVE "phone"  TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE(1:13) TO HV-PHONE
           MOVE "email"  TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE TO HV-EMAIL
           MOVE "job"    TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE TO HV-JOB
           IF HV-KANJI-U = SPACES OR HV-PW = SPACES
               MOVE "missing_required" TO WK-ERRMSG PERFORM ERR-400
           END-IF
      *>   種別 -> SHUBETSU(1=普通系 / 2=当座)。CHECK は 1/2 のみ。
           IF HV-TYPE(1:6) = "当座  " OR HV-TYPE(1:2) = "当"
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
           MOVE HV-NEWNO TO KY-STR(1:7)
           MOVE 7 TO KY-N
           PERFORM ENC-KEY
           MOVE KY-HEX(1:14) TO HV-NEWNO-HEX
      *>   名義(UTF-8) -> JEF EBCDIC RAW(20byte,0x40パディング) の HEX を
      *>   JEF4J 変換サービス(C ブリッジ JEFCONV 'E')で生成し HEXTORAW で格納。
           MOVE 'E' TO JC-MODE
           MOVE FUNCTION STORED-CHAR-LENGTH(HV-KANJI-U) TO JC-INLEN
           MOVE ALL '40' TO HV-KANJI-HEX
           CALL "JEFCONV" USING JC-MODE HV-KANJI-U JC-INLEN
                                HV-KANJI-HEX JC-OUTLEN
           MOVE 'E' TO JC-MODE
           MOVE FUNCTION STORED-CHAR-LENGTH(HV-KANA-U) TO JC-INLEN
           MOVE ALL '40' TO HV-KANA-HEX
           CALL "JEFCONV" USING JC-MODE HV-KANA-U JC-INLEN
                                HV-KANA-HEX JC-OUTLEN
           MOVE HV-SHU TO TX-UTF8
           MOVE 1 TO TX-ULEN
           PERFORM ENC-TXT
           MOVE TX-HEX(1:TX-HLEN) TO HV-SHU-HX
           MOVE HV-KAI TO TX-UTF8
           MOVE 8 TO TX-ULEN
           PERFORM ENC-TXT
           MOVE TX-HEX(1:TX-HLEN) TO HV-KAI-HX
           EXEC SQL
               INSERT INTO KOUZA
                 (KOUZA_NO, MEIGI_KANJI, MEIGI_KANA, SHUBETSU,
                  ZANDAKA, KAISETSU_BI, JOUTAI)
               VALUES
                 (HEXTORAW(:HV-NEWNO-HEX),
                  HEXTORAW(:HV-KANJI-HEX),
                  HEXTORAW(:HV-KANA-HEX),
                  HEXTORAW(RTRIM(:HV-SHU-HX)),
                  HEXTORAW('00000000000C'),
                  HEXTORAW(RTRIM(:HV-KAI-HX)),
                  HEXTORAW(:HV-JOU-HX))
           END-EXEC
           IF SQLCODE NOT = 0
               EXEC SQL ROLLBACK END-EXEC
               PERFORM DB-DISCONNECT
               MOVE "signup_failed" TO WK-ERRMSG PERFORM ERR-500
           END-IF
      *>   必須列のみ INSERT(プロフィール列は NULL 可)。長い列並びは
      *>   gixpp がカンマを落とす不具合を誘発するため最小限にする。
           MOVE HV-BR TO TX-UTF8
           MOVE 3 TO TX-ULEN
           PERFORM ENC-TXT
           MOVE TX-HEX(1:TX-HLEN) TO HV-BR-HX
           MOVE HV-TYPE TO TX-UTF8
           MOVE FUNCTION STORED-CHAR-LENGTH(HV-TYPE) TO TX-ULEN
           PERFORM ENC-TXT
           MOVE TX-HEX(1:TX-HLEN) TO HV-TYPE-HX
           MOVE HV-PW TO TX-UTF8
           MOVE FUNCTION STORED-CHAR-LENGTH(HV-PW) TO TX-ULEN
           PERFORM ENC-TXT
           MOVE TX-HEX(1:TX-HLEN) TO HV-PW-HX
           EXEC SQL
               INSERT INTO KOUZA_EXT
                 (KOUZA_NO, BRANCH_CODE, ACCT_TYPE, PASSWORD,
                  IS_PRIMARY, KANJI_UTF8, KANA_UTF8)
               VALUES
                 (HEXTORAW(:HV-NEWNO-HEX),
                  HEXTORAW(RTRIM(:HV-BR-HX)),
                  HEXTORAW(RTRIM(:HV-TYPE-HX)),
                  HEXTORAW(RTRIM(:HV-PW-HX)),
                  HEXTORAW(:HV-PRIM-HX),
                  :HV-KANJI-U, :HV-KANA-U)
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
                  HV-BR DELIMITED SIZE
                  '","type":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-TYPE) DELIMITED SIZE
                  '","shubetsu":"' DELIMITED SIZE
                  HV-SHU DELIMITED SIZE
                  '"}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN.
       COPY PFMTNUM.
       COPY PPACK.
       COPY PTXT.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM SIGNUP.
