      *>****************************************************************
      *> NOTICE  -  お知らせ CGI (全RAW版)
      *>   GET  : 有効なお知らせ一覧(新しい順) 日付/タグ/タイトルを JEF 復号
      *>   POST : title,[body],[tag] -> JEF 符号化して追加
      *>   NOTICE_DATE=RAW(8) EBCDIC 'YYYYMMDD', IS_ACTIVE='Y'(=JEF 'E8')。
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
       01  WK-TAG      PIC X(60).
       01  WK-DATE     PIC X(8).
       01  WK-DT8      PIC X(8).
       COPY WPACK.
       COPY WTXT.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-TITLE-HX PIC X(1200).
       01  HV-BODY-HX  PIC X(4000).
       01  HV-TAG-HX   PIC X(120).
       01  HV-DATE-HX  PIC X(20).
       01  HV-ACT-HX   PIC X(2) VALUE 'E8'.
       01  HV-NID      PIC 9(12).
       01  HV-NID-HEX  PIC X(24).
       01  C-DATE-HX   PIC X(20).
       01  C-TAG-HX    PIC X(120).
       01  C-TITLE-HX  PIC X(1200).
       EXEC SQL END DECLARE SECTION END-EXEC.
       EXEC SQL
           DECLARE C-NOTICE CURSOR FOR
             SELECT RAWTOHEX(NOTICE_DATE), RAWTOHEX(TAG),
                    RAWTOHEX(TITLE)
               FROM NOTICE_ASIS WHERE IS_ACTIVE = HEXTORAW(:HV-ACT-HX)
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
                     INTO :C-DATE-HX, :C-TAG-HX, :C-TITLE-HX
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
           MOVE C-DATE-HX TO TX-HEX
           MOVE FUNCTION STORED-CHAR-LENGTH(C-DATE-HX) TO TX-HLEN
           PERFORM DEC-TXT
           MOVE TX-UTF8(1:8) TO WK-DT8
           STRING '{"date":"' DELIMITED SIZE
                  WK-DT8(1:4) DELIMITED SIZE
                  '/' DELIMITED SIZE
                  WK-DT8(5:2) DELIMITED SIZE
                  '/' DELIMITED SIZE
                  WK-DT8(7:2) DELIMITED SIZE
                  '","tag":"' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE C-TAG-HX TO TX-HEX
           MOVE FUNCTION STORED-CHAR-LENGTH(C-TAG-HX) TO TX-HLEN
           PERFORM DEC-TXT
           STRING TX-UTF8(1:TX-ULEN) DELIMITED SIZE
                  '","title":"' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE C-TITLE-HX TO TX-HEX
           MOVE FUNCTION STORED-CHAR-LENGTH(C-TITLE-HX) TO TX-HLEN
           PERFORM DEC-TXT
           STRING TX-UTF8(1:TX-ULEN) DELIMITED SIZE
                  '"}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR.
       DO-CREATE.
           MOVE "title" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE TO WK-TITLE
           IF WK-TITLE = SPACES
               MOVE "missing_title" TO WK-ERRMSG PERFORM ERR-400
           END-IF
           MOVE WK-TITLE TO TX-UTF8
           MOVE FUNCTION STORED-CHAR-LENGTH(WK-TITLE) TO TX-ULEN
           PERFORM ENC-TXT
           MOVE TX-HEX(1:TX-HLEN) TO HV-TITLE-HX
           MOVE "body" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE CP-VALUE TO WK-BODY
           MOVE "tag" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           IF CP-FOUND = 'Y' MOVE CP-VALUE TO WK-TAG
           ELSE MOVE "新着" TO WK-TAG END-IF
           MOVE WK-TAG TO TX-UTF8
           MOVE FUNCTION STORED-CHAR-LENGTH(WK-TAG) TO TX-ULEN
           PERFORM ENC-TXT
           MOVE TX-HEX(1:TX-HLEN) TO HV-TAG-HX
           MOVE FUNCTION CURRENT-DATE(1:8) TO WK-DATE
           MOVE WK-DATE TO TX-UTF8
           MOVE 8 TO TX-ULEN
           PERFORM ENC-TXT
           MOVE TX-HEX(1:TX-HLEN) TO HV-DATE-HX
           EXEC SQL
               SELECT SEQ_NOTICE_ASIS.NEXTVAL INTO :HV-NID FROM DUAL
           END-EXEC
           MOVE HV-NID TO KY-STR(1:12)
           MOVE 12 TO KY-N
           PERFORM ENC-KEY
           MOVE KY-HEX(1:24) TO HV-NID-HEX
           MOVE SPACES TO HV-BODY-HX
           IF WK-BODY NOT = SPACES
               MOVE WK-BODY TO TX-UTF8
               MOVE FUNCTION STORED-CHAR-LENGTH(WK-BODY) TO TX-ULEN
               PERFORM ENC-TXT
               MOVE TX-HEX(1:TX-HLEN) TO HV-BODY-HX
           END-IF
           IF HV-BODY-HX = SPACES
             EXEC SQL
               INSERT INTO NOTICE_ASIS
                 (NOTICE_ID, NOTICE_DATE, TAG, TITLE, BODY, IS_ACTIVE)
               VALUES
                 (HEXTORAW(:HV-NID-HEX),
                  HEXTORAW(RTRIM(:HV-DATE-HX)),
                  HEXTORAW(RTRIM(:HV-TAG-HX)),
                  HEXTORAW(RTRIM(:HV-TITLE-HX)),
                  NULL, HEXTORAW(:HV-ACT-HX))
             END-EXEC
           ELSE
             EXEC SQL
               INSERT INTO NOTICE_ASIS
                 (NOTICE_ID, NOTICE_DATE, TAG, TITLE, BODY, IS_ACTIVE)
               VALUES
                 (HEXTORAW(:HV-NID-HEX),
                  HEXTORAW(RTRIM(:HV-DATE-HX)),
                  HEXTORAW(RTRIM(:HV-TAG-HX)),
                  HEXTORAW(RTRIM(:HV-TITLE-HX)),
                  HEXTORAW(RTRIM(:HV-BODY-HX)),
                  HEXTORAW(:HV-ACT-HX))
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
       COPY PPACK.
       COPY PTXT.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM NOTICE.
