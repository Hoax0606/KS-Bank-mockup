      *>****************************************************************
      *> NOTICE  -  お知らせ CGI (拡張)
      *>   GET  : 有効なお知らせ一覧(新しい順)
      *>   POST : title, [body], [tag] -> 追加(先頭反映)
      *>   タイトル/タグは UTF-8 のまま NVARCHAR2 へ格納・返却。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. NOTICE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WCGI.
       COPY WONLINE.
       COPY WDB.
       01  FIRST-ROW   PIC X(1) VALUE 'Y'.
       COPY WPACK.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
      *> 挿入用ホスト変数は列サイズ内に収める(CHAR 埋めで ORA-12899 回避)。
       01  HV-TITLE    PIC X(180).
       01  HV-BODY     PIC X(900).
       01  HV-TAG      PIC X(18).
       01  HV-NID      PIC 9(12).
       01  HV-NID-HEX  PIC X(24).
       01  C-DATE      PIC X(10).
       01  C-TAG       PIC X(60).
       01  C-TITLE     PIC X(600).
       EXEC SQL END DECLARE SECTION END-EXEC.
       EXEC SQL
           DECLARE C-NOTICE CURSOR FOR
             SELECT TO_CHAR(NOTICE_DATE,'YYYY/MM/DD'), TAG, TITLE
               FROM NOTICE_ASIS WHERE IS_ACTIVE = 'Y'
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
                   FETCH C-NOTICE INTO :C-DATE, :C-TAG, :C-TITLE
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
                  C-DATE DELIMITED SIZE
                  '","tag":"' DELIMITED SIZE
                  FUNCTION TRIM(C-TAG) DELIMITED SIZE
                  '","title":"' DELIMITED SIZE
                  FUNCTION TRIM(C-TITLE) DELIMITED SIZE
                  '"}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR.
       DO-CREATE.
           MOVE "title" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE TO HV-TITLE
           IF HV-TITLE = SPACES
               MOVE "missing_title" TO WK-ERRMSG PERFORM ERR-400
           END-IF
           MOVE "body" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE TO HV-BODY
           MOVE "tag" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           IF CP-FOUND = 'Y' MOVE CP-VALUE TO HV-TAG
           ELSE MOVE "新着" TO HV-TAG END-IF
           EXEC SQL
               SELECT SEQ_NOTICE_ASIS.NEXTVAL INTO :HV-NID FROM DUAL
           END-EXEC
           MOVE HV-NID TO KY-STR(1:12)
           MOVE 12 TO KY-N
           PERFORM ENC-KEY
           MOVE KY-HEX(1:24) TO HV-NID-HEX
           EXEC SQL
               INSERT INTO NOTICE_ASIS
                 (NOTICE_ID, NOTICE_DATE, TAG, TITLE, BODY, IS_ACTIVE)
               VALUES
                 (HEXTORAW(:HV-NID-HEX), TRUNC(SYSDATE), :HV-TAG,
                  :HV-TITLE, :HV-BODY, 'Y')
           END-EXEC
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
       COPY PPACK.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM NOTICE.
