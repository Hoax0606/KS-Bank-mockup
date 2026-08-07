      *>****************************************************************
      *> NOTICE  -  お知らせ CGI (通常型/Shift-JIS DB版)
      *>   GET  : 有効なお知らせ一覧(新しい順) 日付/タグ/タイトルを直接取得
      *>   POST : title,[body],[tag] -> UTF2SJIS(glibc iconv)で Shift-JIS に
      *>          変換してから追加(ブラウザは常に UTF-8 で送るため)。
      *>   NOTICE_DATE=CHAR(8) 'YYYYMMDD', IS_ACTIVE='Y'。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. NOTICE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WCGI.
       COPY WONLINE.
       COPY WDB.
       01  FIRST-ROW   PIC X(1) VALUE 'Y'.
       01  WK-TITLE    PIC X(600).
       01  WK-BODY     PIC X(2000).
       01  WK-TAG      PIC X(30).
       01  WK-DATE     PIC X(8).
      *>   ブラウザは title/body/tag を常に UTF-8 で送る(encodeURIComponentの
      *>   仕様上変更不能)。DB へは Shift-JIS で書く必要があるため、ここで
      *>   明示的に変換する(UTF2SJIS.c, glibc iconv 直呼び)。
       01  UC-OUT      PIC X(2000).
       01  UC-INLEN    PIC 9(4).
       01  UC-OUTLEN   PIC 9(4).
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-TITLE    PIC X(600).
       01  HV-BODY     PIC X(2000).
       01  HV-TAG      PIC X(30).
       01  HV-DATE     PIC X(8).
       01  HV-ACT      PIC X(1) VALUE 'Y'.
       01  HV-NID      PIC 9(12).
       01  C-DATE      PIC X(8).
       01  C-TAG       PIC X(30).
       01  C-TITLE     PIC X(600).
       EXEC SQL END DECLARE SECTION END-EXEC.
       EXEC SQL
           DECLARE C-NOTICE CURSOR FOR
             SELECT NOTICE_DATE, TAG, TITLE
               FROM NOTICE_ASIS WHERE IS_ACTIVE = :HV-ACT
              ORDER BY NOTICE_DATE DESC, NOTICE_ID DESC
       END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           CALL "CGIINIT" USING CGI-ENV
           PERFORM DB-CONNECT
           IF CGI-METHOD = "POST"
               PERFORM DO-CREATE
           ELSE
               PERFORM DO-LIST
           END-IF
           PERFORM DB-DISCONNECT
           CALL "CGIRESP" USING RESP
           STOP RUN.
       DO-LIST.
           MOVE 1 TO RESP-PTR MOVE SPACES TO RESP-BUF
           STRING '{"ok":true,"notices":[' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE 'Y' TO FIRST-ROW
           EXEC SQL OPEN C-NOTICE END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL
                   FETCH C-NOTICE
                     INTO :C-DATE, :C-TAG, :C-TITLE
               END-EXEC
               IF SQLCODE = 0 PERFORM EMIT-NOTICE END-IF
           END-PERFORM
           EXEC SQL CLOSE C-NOTICE END-EXEC
           STRING ']}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN.
       EMIT-NOTICE.
           IF FIRST-ROW = 'Y' MOVE 'N' TO FIRST-ROW
           ELSE STRING ',' DELIMITED SIZE
                       INTO RESP-BUF WITH POINTER RESP-PTR
           END-IF
           STRING '{"date":"' DELIMITED SIZE
                  C-DATE(1:4) DELIMITED SIZE
                  '/' DELIMITED SIZE
                  C-DATE(5:2) DELIMITED SIZE
                  '/' DELIMITED SIZE
                  C-DATE(7:2) DELIMITED SIZE
                  '","tag":"' DELIMITED SIZE
                  FUNCTION TRIM(C-TAG) DELIMITED SIZE
                  '","title":"' DELIMITED SIZE
                  FUNCTION TRIM(C-TITLE) DELIMITED SIZE
                  '"}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR.
       DO-CREATE.
           MOVE "title" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE TO WK-TITLE
           IF WK-TITLE = SPACES
               MOVE "missing_title" TO WK-ERRMSG PERFORM ERR-400
           END-IF
           MOVE WK-TITLE TO HV-TITLE
           MOVE "body" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE TO WK-BODY
           MOVE WK-BODY TO HV-BODY
           MOVE "tag" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           IF CP-FOUND = 'Y' MOVE CP-VALUE TO WK-TAG
           ELSE MOVE "新着" TO WK-TAG END-IF
           MOVE WK-TAG TO HV-TAG
           MOVE FUNCTION CURRENT-DATE(1:8) TO WK-DATE
           MOVE WK-DATE TO HV-DATE
      *>   UTF-8(ブラウザ送信/既定値リテラル共通) -> Shift-JIS(DB 格納) 変換
           MOVE SPACES TO UC-OUT MOVE 600 TO UC-INLEN UC-OUTLEN
           CALL "UTF2SJIS" USING HV-TITLE UC-INLEN UC-OUT UC-OUTLEN
           IF RETURN-CODE NOT = 0
               MOVE "invalid_text_encoding" TO WK-ERRMSG PERFORM ERR-400
           END-IF
           MOVE UC-OUT TO HV-TITLE
           MOVE SPACES TO UC-OUT MOVE 2000 TO UC-INLEN UC-OUTLEN
           CALL "UTF2SJIS" USING HV-BODY UC-INLEN UC-OUT UC-OUTLEN
           IF RETURN-CODE NOT = 0
               MOVE "invalid_text_encoding" TO WK-ERRMSG PERFORM ERR-400
           END-IF
           MOVE UC-OUT TO HV-BODY
           MOVE SPACES TO UC-OUT MOVE 30 TO UC-INLEN UC-OUTLEN
           CALL "UTF2SJIS" USING HV-TAG UC-INLEN UC-OUT UC-OUTLEN
           IF RETURN-CODE NOT = 0
               MOVE "invalid_text_encoding" TO WK-ERRMSG PERFORM ERR-400
           END-IF
           MOVE UC-OUT TO HV-TAG
           EXEC SQL
               SELECT SEQ_NOTICE_ASIS.NEXTVAL INTO :HV-NID FROM DUAL
           END-EXEC
           IF WK-BODY = SPACES
             EXEC SQL
               INSERT INTO NOTICE_ASIS
                 (NOTICE_ID, NOTICE_DATE, TAG, TITLE, BODY, IS_ACTIVE)
               VALUES
                 (:HV-NID, :HV-DATE, RTRIM(:HV-TAG),
                  RTRIM(:HV-TITLE), NULL, :HV-ACT)
             END-EXEC
           ELSE
             EXEC SQL
               INSERT INTO NOTICE_ASIS
                 (NOTICE_ID, NOTICE_DATE, TAG, TITLE, BODY, IS_ACTIVE)
               VALUES
                 (:HV-NID, :HV-DATE, RTRIM(:HV-TAG),
                  RTRIM(:HV-TITLE), RTRIM(:HV-BODY), :HV-ACT)
             END-EXEC
           END-IF
           IF SQLCODE NOT = 0
               EXEC SQL ROLLBACK END-EXEC
               PERFORM DB-DISCONNECT
               MOVE "notice_failed" TO WK-ERRMSG PERFORM ERR-500
           END-IF
           EXEC SQL COMMIT END-EXEC
           MOVE 1 TO RESP-PTR MOVE SPACES TO RESP-BUF
           MOVE HV-NID TO WK-NUM11
           PERFORM FMT-NUM
           STRING '{"ok":true,"noticeId":' DELIMITED SIZE
                  FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  '}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN.
       COPY PFMTNUM.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM NOTICE.
