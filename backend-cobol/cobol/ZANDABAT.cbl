      *>****************************************************************
      *> ZANDABAT  -  日次残高一覧 (全口座)
      *>   KOUZA(RAW)を口座番号順に読み、口座番号(存10進)・種別・状態・
      *>   残高(COMP-3)を復号して ZANDAKA.RPT に一覧出力する。
      *>   復号は純 COBOL コーデック(DEC-KEY / DEC-P11)のみ。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ZANDABAT.
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
       01  N-OUT       PIC 9(6) VALUE 0.
       01  T-BAL       PIC 9(15) VALUE 0.
       01  L-DTL.
           05 L-ACCT   PIC X(7).
           05 FILLER   PIC X(1) VALUE SPACE.
           05 L-SHU    PIC X(1).
           05 FILLER   PIC X(1) VALUE SPACE.
           05 L-JOU    PIC X(1).
           05 FILLER   PIC X(1) VALUE SPACE.
           05 L-BAL    PIC 9(11).
       01  L-TOT.
           05 FILLER   PIC X(7) VALUE "TOTAL  ".
           05 FILLER   PIC X(4) VALUE "BAL=".
           05 L-TB     PIC 9(15).
       COPY WPACK.
       COPY WDB.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KZ-HX    PIC X(14).
       01  HV-SHU-HX   PIC X(2).
       01  HV-JOU-HX   PIC X(2).
       01  HV-ZAN-HX   PIC X(12).
       01  IND-ZAN     PIC S9(4) COMP.
       EXEC SQL END DECLARE SECTION END-EXEC.
       EXEC SQL
           DECLARE C-ZD CURSOR FOR
             SELECT RAWTOHEX(KOUZA_NO), RAWTOHEX(SHUBETSU),
                    RAWTOHEX(JOUTAI), RAWTOHEX(ZANDAKA)
               FROM KOUZA
              ORDER BY KOUZA_NO
       END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           MOVE "./data/ZANDAKA.RPT" TO OUT-PATH
           MOVE SPACES TO WK-ENV
           ACCEPT WK-ENV FROM ENVIRONMENT "ZANDA_OUT"
               ON EXCEPTION MOVE SPACES TO WK-ENV
           END-ACCEPT
           IF WK-ENV NOT = SPACES
               MOVE WK-ENV TO OUT-PATH
           END-IF
           PERFORM DB-CONNECT
           OPEN OUTPUT F-OUT
           EXEC SQL OPEN C-ZD END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL
                   FETCH C-ZD INTO :HV-KZ-HX, :HV-SHU-HX,
                        :HV-JOU-HX, :HV-ZAN-HX:IND-ZAN
               END-EXEC
               IF SQLCODE = 0
                   PERFORM EMIT
               END-IF
           END-PERFORM
           EXEC SQL CLOSE C-ZD END-EXEC
           MOVE T-BAL TO L-TB
           WRITE REP-REC FROM L-TOT
           CLOSE F-OUT
           PERFORM DB-DISCONNECT
           DISPLAY "[ZANDABAT] listed " N-OUT " accounts, totalBal="
                   T-BAL UPON SYSERR
           STOP RUN.
       EMIT.
           MOVE HV-KZ-HX TO KY-HEX(1:14)
           MOVE 7 TO KY-N
           PERFORM DEC-KEY
           MOVE KY-STR(1:7) TO L-ACCT
           MOVE HV-SHU-HX(2:1) TO L-SHU
           MOVE HV-JOU-HX(2:1) TO L-JOU
           IF IND-ZAN < 0
               MOVE 0 TO L-BAL
           ELSE
               MOVE HV-ZAN-HX TO PK-HEX(1:12)
               PERFORM DEC-P11
               MOVE PK-P11 TO L-BAL
               ADD PK-P11 TO T-BAL
           END-IF
           WRITE REP-REC FROM L-DTL
           ADD 1 TO N-OUT.
       COPY PPACK.
       COPY PDBCONB.
       END PROGRAM ZANDABAT.
