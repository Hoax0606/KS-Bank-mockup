      *>****************************************************************
      *> NIPPOBAT  -  取引日報 (区分別 件数・金額 集計)
      *>   TORIHIKI を読み、TORIHIKI_KBN(1=入金/2=出金/3=振込)ごとの
      *>   件数と KINGAKU 合計を集計して NIPPO.RPT に出力する。
      *>   通常型直接バインド(RAWTOHEX/COMP-3コーデック廃止)。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. NIPPOBAT.
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
       01  W-KBN       PIC X(1).
       01  W-AMT       PIC 9(11).
       01  C1          PIC 9(7) VALUE 0.
       01  C2          PIC 9(7) VALUE 0.
       01  C3          PIC 9(7) VALUE 0.
       01  S1          PIC 9(15) VALUE 0.
       01  S2          PIC 9(15) VALUE 0.
       01  S3          PIC 9(15) VALUE 0.
       01  L-DTL.
           05 FILLER   PIC X(4) VALUE "KBN=".
           05 L-K      PIC X(1).
           05 FILLER   PIC X(6) VALUE " CNT=".
           05 L-C      PIC 9(7).
           05 FILLER   PIC X(6) VALUE " SUM=".
           05 L-S      PIC 9(15).
       COPY WDB.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KBN      PIC X(1).
       01  HV-KIN      PIC S9(11).
       EXEC SQL END DECLARE SECTION END-EXEC.
       EXEC SQL
           DECLARE C-NP CURSOR FOR
             SELECT TORIHIKI_KBN, KINGAKU
               FROM TORIHIKI
       END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           MOVE "./data/NIPPO.RPT" TO OUT-PATH
           MOVE SPACES TO WK-ENV
           ACCEPT WK-ENV FROM ENVIRONMENT "NIPPO_OUT"
               ON EXCEPTION MOVE SPACES TO WK-ENV
           END-ACCEPT
           IF WK-ENV NOT = SPACES
               MOVE WK-ENV TO OUT-PATH
           END-IF
           PERFORM DB-CONNECT
           OPEN OUTPUT F-OUT
           EXEC SQL OPEN C-NP END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL
                   FETCH C-NP INTO :HV-KBN, :HV-KIN
               END-EXEC
               IF SQLCODE = 0
                   PERFORM ACCUM
               END-IF
           END-PERFORM
           EXEC SQL CLOSE C-NP END-EXEC
           MOVE "1" TO L-K
           MOVE C1 TO L-C
           MOVE S1 TO L-S
           WRITE REP-REC FROM L-DTL
           MOVE "2" TO L-K
           MOVE C2 TO L-C
           MOVE S2 TO L-S
           WRITE REP-REC FROM L-DTL
           MOVE "3" TO L-K
           MOVE C3 TO L-C
           MOVE S3 TO L-S
           WRITE REP-REC FROM L-DTL
           CLOSE F-OUT
           PERFORM DB-DISCONNECT
           DISPLAY "[NIPPOBAT] done nyukin=" C1 " shukkin=" C2
                   " furikomi=" C3 UPON SYSERR
           STOP RUN.
       ACCUM.
           MOVE HV-KBN TO W-KBN
           MOVE HV-KIN TO W-AMT
           EVALUATE W-KBN
             WHEN "1"
               ADD 1 TO C1
               ADD W-AMT TO S1
             WHEN "2"
               ADD 1 TO C2
               ADD W-AMT TO S2
             WHEN "3"
               ADD 1 TO C3
               ADD W-AMT TO S3
           END-EVALUATE.
       COPY PDBCONB.
       END PROGRAM NIPPOBAT.
