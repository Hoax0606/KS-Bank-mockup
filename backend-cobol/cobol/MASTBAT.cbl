      *>****************************************************************
      *> MASTBAT  -  口座マスタ一覧表
      *>   KOUZA を口座番号順に読み、口座番号・種別・状態・開設日・残高を
      *>   復号して KOUZA.LST に一覧出力する(監査/照合用)。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MASTBAT.
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
       01  L-DTL.
           05 FILLER   PIC X(5) VALUE "ACCT=".
           05 L-ACCT   PIC X(7).
           05 FILLER   PIC X(5) VALUE " TYP=".
           05 L-SHU    PIC X(1).
           05 FILLER   PIC X(4) VALUE " ST=".
           05 L-JOU    PIC X(1).
           05 FILLER   PIC X(6) VALUE " OPEN=".
           05 L-DATE   PIC X(8).
           05 FILLER   PIC X(5) VALUE " BAL=".
           05 L-BAL    PIC 9(11).
       COPY WDB.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KZ       PIC 9(7).
       01  HV-SHU      PIC X(1).
       01  HV-JOU      PIC X(1).
       01  HV-KAI      PIC X(8).
       01  HV-ZAN      PIC S9(11).
       01  IND-ZAN     PIC S9(4) COMP.
       EXEC SQL END DECLARE SECTION END-EXEC.
       EXEC SQL
           DECLARE C-MS CURSOR FOR
             SELECT KOUZA_NO, SHUBETSU, JOUTAI, KAISETSU_BI, ZANDAKA
               FROM KOUZA
              ORDER BY KOUZA_NO
       END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           MOVE "./data/KOUZA.LST" TO OUT-PATH
           MOVE SPACES TO WK-ENV
           ACCEPT WK-ENV FROM ENVIRONMENT "MAST_OUT"
               ON EXCEPTION MOVE SPACES TO WK-ENV
           END-ACCEPT
           IF WK-ENV NOT = SPACES
               MOVE WK-ENV TO OUT-PATH
           END-IF
           PERFORM DB-CONNECT
           OPEN OUTPUT F-OUT
           EXEC SQL OPEN C-MS END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL
                   FETCH C-MS INTO :HV-KZ, :HV-SHU,
                        :HV-JOU, :HV-KAI, :HV-ZAN:IND-ZAN
               END-EXEC
               IF SQLCODE = 0
                   PERFORM EMIT
               END-IF
           END-PERFORM
           EXEC SQL CLOSE C-MS END-EXEC
           CLOSE F-OUT
           PERFORM DB-DISCONNECT
           DISPLAY "[MASTBAT] listed " N-OUT " accounts" UPON SYSERR
           STOP RUN.
       EMIT.
           MOVE HV-KZ  TO L-ACCT
           MOVE HV-SHU TO L-SHU
           MOVE HV-JOU TO L-JOU
           MOVE HV-KAI TO L-DATE
           IF IND-ZAN < 0
               MOVE 0 TO L-BAL
           ELSE
               MOVE HV-ZAN TO L-BAL
           END-IF
           WRITE REP-REC FROM L-DTL
           ADD 1 TO N-OUT.
       COPY PDBCONB.
       END PROGRAM MASTBAT.
