      *>****************************************************************
      *> CGIINIT  -  CGI 要求取得(REQUEST_METHOD/QUERY_STRING/CONTENT_LENGTH
      *>             + POST stdin body)。呼出元と copy/WCGI.cpy を共有。
      *>   ※ 動的 CALL 解決のため 1ファイル=1プログラム(ファイル名=PROGRAM-ID)。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CGIINIT.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT STDIN-F ASSIGN TO "/dev/stdin"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS.
       DATA DIVISION.
       FILE SECTION.
       FD  STDIN-F.
       01  STDIN-LINE   PIC X(8192).
       WORKING-STORAGE SECTION.
       01  FS           PIC X(2) VALUE "00".
       01  CLEN-A       PIC X(9) VALUE SPACES.
       01  MORE         PIC X(1) VALUE 'Y'.
       01  BPOS         PIC 9(9) COMP VALUE 1.
       01  LN           PIC 9(9) COMP VALUE 0.
       LINKAGE SECTION.
       COPY WCGI.
       PROCEDURE DIVISION USING CGI-ENV.
       INIT-MAIN.
           MOVE SPACES TO CGI-METHOD CGI-QUERY CGI-BODY
           MOVE 0 TO CGI-CLEN CGI-BODY-LEN
           ACCEPT CGI-METHOD FROM ENVIRONMENT "REQUEST_METHOD"
           ACCEPT CGI-QUERY  FROM ENVIRONMENT "QUERY_STRING"
           ACCEPT CLEN-A     FROM ENVIRONMENT "CONTENT_LENGTH"
           INSPECT CLEN-A REPLACING ALL SPACES BY '0'
           IF CLEN-A NOT = ALL '0'
               MOVE FUNCTION NUMVAL(CLEN-A) TO CGI-CLEN
           END-IF
           IF CGI-METHOD = "POST" AND CGI-CLEN > 0
               PERFORM READ-BODY
           END-IF
           GOBACK.
       READ-BODY.
           OPEN INPUT STDIN-F
           IF FS = "00"
               MOVE 1 TO BPOS
               PERFORM UNTIL BPOS > CGI-CLEN OR MORE = 'N'
                   MOVE SPACES TO STDIN-LINE
                   READ STDIN-F
                       AT END MOVE 'N' TO MORE
                       NOT AT END
                           MOVE FUNCTION STORED-CHAR-LENGTH(STDIN-LINE)
                                TO LN
                           IF LN > 0
                               MOVE STDIN-LINE(1:LN)
                                    TO CGI-BODY(BPOS:LN)
                               ADD LN TO BPOS
                           END-IF
                   END-READ
               END-PERFORM
               CLOSE STDIN-F
               SUBTRACT 1 FROM BPOS GIVING CGI-BODY-LEN
           END-IF.
       END PROGRAM CGIINIT.
