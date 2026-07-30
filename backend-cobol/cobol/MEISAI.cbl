      *>****************************************************************
      *> MEISAI  -  取引明細照会 CGI (オンライン 5種の1)
      *>   GET: kouza, [kbn=all|1|2|3], [from=YYYYMMDD], [to=YYYYMMDD]
      *>   取引後残高(afterBal)を累積計算し、新しい順に JSON 配列で返す。
      *>   通常型/Shift-JIS DB版: 金額/口座=NUMBER, 摘要=VARCHAR2(UTF-8) 直接。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MEISAI.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WCGI.
       COPY WONLINE.
       COPY WDB.
       01  WK-FILT-KBN  PIC X(1)  VALUE 'A'.   *> A=all / 1 / 2 / 3
       01  WK-FROM      PIC X(8)  VALUE SPACES.
       01  WK-TO        PIC X(8)  VALUE SPACES.
       01  WK-TMP       PIC X(16).
       01  N            PIC 9(4) COMP VALUE 0.
       01  I            PIC 9(4) COMP VALUE 0.
       01  WK-SUM       PIC S9(13) VALUE 0.
       01  WK-RUN       PIC S9(13) VALUE 0.
       01  WK-DELTA     PIC S9(13) VALUE 0.
       01  WK-OPENING   PIC S9(13) VALUE 0.
       01  FIRST-ROW    PIC X(1) VALUE 'Y'.
       01  ROWS-TBL.
           05  RW OCCURS 1000 TIMES INDEXED BY RX.
               10  RW-DT     PIC X(14).
               10  RW-KBN    PIC X(01).
               10  RW-KIN    PIC S9(11).
               10  RW-TES    PIC S9(05).
               10  RW-TEK    PIC X(80).
               10  RW-AFTER  PIC S9(11).
               10  RW-AITE   PIC S9(7).
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KOUZA    PIC 9(7).
       01  HV-DT       PIC X(14).
       01  HV-KBN      PIC X(01).
       01  HV-KIN      PIC S9(11).
       01  HV-TES      PIC S9(05).
       01  HV-TEK      PIC X(80).
       01  HV-AITE     PIC S9(7).
       01  HV-ZAN      PIC S9(11).
       01  HV-CNT      PIC 9(9).
       EXEC SQL END DECLARE SECTION END-EXEC.
       EXEC SQL
           DECLARE C-MEISAI CURSOR FOR
             SELECT TORIHIKI_DT, TORIHIKI_KBN, KINGAKU,
                    NVL(TESURYO,0), TEKIYOU, NVL(AITE_KOUZA,0)
               FROM TORIHIKI
              WHERE KOUZA_NO = :HV-KOUZA
              ORDER BY TORIHIKI_DT ASC, TORIHIKI_ID ASC
       END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           CALL "CGIINIT" USING CGI-ENV
           MOVE "kouza" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           IF CP-FOUND NOT = 'Y'
               MOVE "missing_kouza" TO WK-ERRMSG PERFORM ERR-400
           END-IF
           MOVE FUNCTION NUMVAL(CP-VALUE) TO HV-KOUZA
           PERFORM READ-FILTERS
           PERFORM DB-CONNECT
      *>   口座存在確認 + 現残高
           EXEC SQL
               SELECT COUNT(*) INTO :HV-CNT
                 FROM KOUZA WHERE KOUZA_NO = :HV-KOUZA
           END-EXEC
           IF HV-CNT = 0
               PERFORM DB-DISCONNECT
               MOVE "kouza_not_found" TO WK-ERRMSG PERFORM ERR-404
           END-IF
           EXEC SQL
               SELECT ZANDAKA INTO :HV-ZAN
                 FROM KOUZA WHERE KOUZA_NO = :HV-KOUZA
           END-EXEC
      *>   全明細を昇順で取得・保持し、符号付き合計を算出
           MOVE 0 TO N WK-SUM
           EXEC SQL OPEN C-MEISAI END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0 OR N >= 1000
               EXEC SQL
                   FETCH C-MEISAI
                     INTO :HV-DT, :HV-KBN, :HV-KIN, :HV-TES,
                          :HV-TEK, :HV-AITE
               END-EXEC
               IF SQLCODE = 0
                   ADD 1 TO N
                   MOVE HV-DT  TO RW-DT(N)
                   MOVE HV-KBN TO RW-KBN(N)
                   MOVE HV-KIN TO RW-KIN(N)
                   MOVE HV-TES TO RW-TES(N)
                   MOVE HV-TEK TO RW-TEK(N)
                   MOVE HV-AITE TO RW-AITE(N)
                   PERFORM CALC-DELTA
                   ADD WK-DELTA TO WK-SUM
               END-IF
           END-PERFORM
           EXEC SQL CLOSE C-MEISAI END-EXEC
           PERFORM DB-DISCONNECT
      *>   期首残高 = 現残高 - 符号付き合計、以後 afterBal を昇順で確定
           COMPUTE WK-OPENING = HV-ZAN - WK-SUM
           MOVE WK-OPENING TO WK-RUN
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > N
               MOVE RW-KIN(I) TO HV-KIN
               MOVE RW-TES(I) TO HV-TES
               MOVE RW-KBN(I) TO HV-KBN
               PERFORM CALC-DELTA
               ADD WK-DELTA TO WK-RUN
               MOVE WK-RUN TO RW-AFTER(I)
           END-PERFORM
           PERFORM BUILD-JSON
           CALL "CGIRESP" USING RESP
           STOP RUN.
      *>-------------------------------------------------------------
       CALC-DELTA.
           EVALUATE HV-KBN
               WHEN '1' MOVE HV-KIN TO WK-DELTA
               WHEN '2' COMPUTE WK-DELTA = 0 - HV-KIN
               WHEN '3' COMPUTE WK-DELTA = 0 - (HV-KIN + HV-TES)
               WHEN OTHER MOVE 0 TO WK-DELTA
           END-EVALUATE.
       READ-FILTERS.
           MOVE 'A' TO WK-FILT-KBN
           MOVE "kbn" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           IF CP-FOUND = 'Y' AND CP-VALUE(1:1) NOT = SPACE
               IF CP-VALUE(1:3) = "all"
                   MOVE 'A' TO WK-FILT-KBN
               ELSE
                   MOVE CP-VALUE(1:1) TO WK-FILT-KBN
               END-IF
           END-IF
           MOVE "from" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           IF CP-FOUND = 'Y' PERFORM NORM-FROM END-IF
           MOVE "to" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           IF CP-FOUND = 'Y' PERFORM NORM-TO END-IF.
       NORM-FROM.
           MOVE SPACES TO WK-TMP
           MOVE CP-VALUE TO WK-TMP
           INSPECT WK-TMP REPLACING ALL "-" BY " "
           INSPECT WK-TMP REPLACING ALL "/" BY " "
           MOVE FUNCTION TRIM(WK-TMP) TO WK-FROM.
       NORM-TO.
           MOVE SPACES TO WK-TMP
           MOVE CP-VALUE TO WK-TMP
           INSPECT WK-TMP REPLACING ALL "-" BY " "
           INSPECT WK-TMP REPLACING ALL "/" BY " "
           MOVE FUNCTION TRIM(WK-TMP) TO WK-TO.
      *>-------------------------------------------------------------
       BUILD-JSON.
           MOVE 1 TO RESP-PTR
           MOVE SPACES TO RESP-BUF
           MOVE HV-KOUZA TO WK-KOUZA-Z
           STRING '{"ok":true,"kouza":"' DELIMITED SIZE
                  WK-KOUZA-Z DELIMITED SIZE
                  '","rows":[' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE 'Y' TO FIRST-ROW
      *>   新しい順(降順)に出力。フィルタ適用。
           PERFORM VARYING I FROM N BY -1 UNTIL I < 1
               IF WK-FILT-KBN = 'A' OR WK-FILT-KBN = RW-KBN(I)
                   IF (WK-FROM = SPACES OR RW-DT(I)(1:8) >= WK-FROM)
                    AND (WK-TO = SPACES OR RW-DT(I)(1:8) <= WK-TO)
                       PERFORM EMIT-ROW
                   END-IF
               END-IF
           END-PERFORM
           STRING ']}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN.
       EMIT-ROW.
           IF FIRST-ROW = 'Y'
               MOVE 'N' TO FIRST-ROW
           ELSE
               STRING ',' DELIMITED SIZE
                      INTO RESP-BUF WITH POINTER RESP-PTR
           END-IF
           STRING '{"date":"' DELIMITED SIZE
                  RW-DT(I)(1:4) DELIMITED SIZE
                  '-' DELIMITED SIZE
                  RW-DT(I)(5:2) DELIMITED SIZE
                  '-' DELIMITED SIZE
                  RW-DT(I)(7:2) DELIMITED SIZE
                  '","kbn":"' DELIMITED SIZE
                  RW-KBN(I) DELIMITED SIZE
                  '","kingaku":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE RW-KIN(I) TO WK-NUM11
           PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  ',"afterBal":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE RW-AFTER(I) TO WK-NUM11
           PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  ',"aite":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE RW-AITE(I) TO WK-NUM11
           PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  ',"memo":"' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
      *>   摘要(VARCHAR2/UTF-8)をそのまま出力。空/LOW-VALUES は空文字。
           IF RW-TEK(I) NOT = SPACES AND RW-TEK(I) NOT = LOW-VALUES
               STRING FUNCTION TRIM(RW-TEK(I)) DELIMITED SIZE
                      INTO RESP-BUF WITH POINTER RESP-PTR
           END-IF
           STRING '"}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR.
       COPY PFMTNUM.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM MEISAI.
