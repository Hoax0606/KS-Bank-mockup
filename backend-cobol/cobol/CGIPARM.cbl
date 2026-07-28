      *>****************************************************************
      *> CGIPARM  -  name を query/body から探し URLデコードして CP-VALUE へ。
      *>   query -> body の順に走査。'name=value&...'。'+'=空白, %XX=16進。
      *>   ※ 1ファイル=1プログラム(動的 CALL 解決のため)。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CGIPARM.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  SRC          PIC X(12288).
       01  SRC-LEN      PIC 9(9) COMP.
       01  I            PIC 9(9) COMP.
       01  NMLEN        PIC 9(4) COMP.
       01  HEXPAIR      PIC X(2).
       01  HEXVAL       PIC 9(3) COMP.
       01  HEXDIG       PIC 9(3) COMP.
       01  HEXC         PIC X(1).
       01  HEXREF       PIC X(16) VALUE "0123456789ABCDEF".
       01  HEXK         PIC 9(3) COMP.
       01  TARGET       PIC X(66).
       01  TLEN         PIC 9(4) COMP.
       01  MATCHPOS     PIC 9(9) COMP.
       01  OUTPOS       PIC 9(9) COMP.
       01  CHX          PIC X(1).
       01  PREVCH       PIC X(1).
       LINKAGE SECTION.
       COPY WCGI.
       PROCEDURE DIVISION USING CGI-ENV CGI-PARAM.
       PARM-MAIN.
           MOVE SPACES TO CP-VALUE
           MOVE 'N' TO CP-FOUND
           MOVE SPACES TO TARGET
           MOVE FUNCTION STORED-CHAR-LENGTH(CP-NAME) TO NMLEN
           IF NMLEN = 0 GOBACK END-IF
           STRING CP-NAME(1:NMLEN) DELIMITED SIZE
                  "="            DELIMITED SIZE INTO TARGET
           COMPUTE TLEN = NMLEN + 1
      *>   1) QUERY_STRING
           MOVE CGI-QUERY TO SRC
           MOVE FUNCTION STORED-CHAR-LENGTH(SRC) TO SRC-LEN
           PERFORM SCAN
           IF CP-FOUND = 'Y' GOBACK END-IF
      *>   2) POST body
           MOVE SPACES TO SRC
           MOVE CGI-BODY(1:CGI-BODY-LEN) TO SRC
           MOVE CGI-BODY-LEN TO SRC-LEN
           PERFORM SCAN
           GOBACK.
       SCAN.
           MOVE 0 TO MATCHPOS
           PERFORM VARYING I FROM 1 BY 1
                   UNTIL I > SRC-LEN OR MATCHPOS > 0
               IF I = 1
                   MOVE '&' TO PREVCH
               ELSE
                   MOVE SRC(I - 1:1) TO PREVCH
               END-IF
               IF PREVCH = '&'
                  AND I + TLEN - 1 <= SRC-LEN
                  AND SRC(I:TLEN) = TARGET(1:TLEN)
                   COMPUTE MATCHPOS = I + TLEN
               END-IF
           END-PERFORM
           IF MATCHPOS = 0 THEN
               CONTINUE
           ELSE
               MOVE 'Y' TO CP-FOUND
               MOVE 1 TO OUTPOS
               PERFORM VARYING I FROM MATCHPOS BY 1
                       UNTIL I > SRC-LEN OR SRC(I:1) = '&'
                   MOVE SRC(I:1) TO CHX
                   EVALUATE TRUE
                       WHEN CHX = '+'
                           MOVE ' ' TO CP-VALUE(OUTPOS:1)
                           ADD 1 TO OUTPOS
                       WHEN CHX = '%' AND I + 2 <= SRC-LEN
                           MOVE SRC(I + 1:2) TO HEXPAIR
                           PERFORM HEX2BIN
                           MOVE FUNCTION CHAR(HEXVAL + 1)
                                TO CP-VALUE(OUTPOS:1)
                           ADD 1 TO OUTPOS
                           ADD 2 TO I
                       WHEN OTHER
                           MOVE CHX TO CP-VALUE(OUTPOS:1)
                           ADD 1 TO OUTPOS
                   END-EVALUATE
               END-PERFORM
           END-IF.
       HEX2BIN.
           MOVE FUNCTION UPPER-CASE(HEXPAIR) TO HEXPAIR
           MOVE HEXPAIR(1:1) TO HEXC
           PERFORM HEXDIGIT
           COMPUTE HEXVAL = HEXDIG * 16
           MOVE HEXPAIR(2:1) TO HEXC
           PERFORM HEXDIGIT
           ADD HEXDIG TO HEXVAL.
       HEXDIGIT.
           MOVE 0 TO HEXDIG
           PERFORM VARYING HEXK FROM 1 BY 1 UNTIL HEXK > 16
               IF HEXREF(HEXK:1) = HEXC
                   COMPUTE HEXDIG = HEXK - 1
                   MOVE 17 TO HEXK
               END-IF
           END-PERFORM.
       END PROGRAM CGIPARM.
