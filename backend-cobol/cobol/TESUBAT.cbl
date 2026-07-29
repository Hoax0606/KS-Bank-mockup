      *>****************************************************************
      *> TESUBAT  -  振込手数料 集計
      *>   TORIHIKI の TESURYO(振込のみ, COMP-3 RAW(3))を集計し、
      *>   件数と手数料合計を TESURYO.RPT に出力する。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TESUBAT.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT F-OUT ASSIGN TO OUT-PATH
               ORGANIZATION IS LINE SEQUENTIAL FILE STATUS IS FS.
       DATA DIVISION.
       FILE SECTION.
       FD  F-OUT.
       01  REP-REC     PIC X(80).
       WORKING-STORAGE SECTION.
       01  OUT-PATH    PIC X(256).
       01  WK-ENV      PIC X(256).
       01  FS          PIC X(2).
       01  T-CNT       PIC 9(7) VALUE 0.
       01  T-SUM       PIC 9(13) VALUE 0.
       01  L-TOT.
           05 FILLER   PIC X(10) VALUE "FEE COUNT=".
           05 L-C      PIC 9(7).
           05 FILLER   PIC X(7) VALUE " TOTAL=".
           05 L-S      PIC 9(13).
       COPY WPACK.
       COPY WDB.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-TES-HX   PIC X(6).
       EXEC SQL END DECLARE SECTION END-EXEC.
       EXEC SQL
           DECLARE C-TS CURSOR FOR
             SELECT RAWTOHEX(TESURYO)
               FROM TORIHIKI
              WHERE TESURYO IS NOT NULL
       END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           MOVE "./data/TESURYO.RPT" TO OUT-PATH
           MOVE SPACES TO WK-ENV
           ACCEPT WK-ENV FROM ENVIRONMENT "TESU_OUT"
               ON EXCEPTION MOVE SPACES TO WK-ENV
           END-ACCEPT
           IF WK-ENV NOT = SPACES
               MOVE WK-ENV TO OUT-PATH
           END-IF
           PERFORM DB-CONNECT
           OPEN OUTPUT F-OUT
           EXEC SQL OPEN C-TS END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL FETCH C-TS INTO :HV-TES-HX END-EXEC
               IF SQLCODE = 0
                   ADD 1 TO T-CNT
                   MOVE HV-TES-HX TO PK-HEX(1:6)
                   PERFORM DEC-P5
                   ADD PK-P5 TO T-SUM
               END-IF
           END-PERFORM
           EXEC SQL CLOSE C-TS END-EXEC
           MOVE T-CNT TO L-C
           MOVE T-SUM TO L-S
           WRITE REP-REC FROM L-TOT
           CLOSE F-OUT
           PERFORM DB-DISCONNECT
           DISPLAY "[TESUBAT] fee count=" T-CNT " total=" T-SUM
                   UPON SYSERR
           STOP RUN.
       COPY PPACK.
       COPY PDBCONB.
       END PROGRAM TESUBAT.
