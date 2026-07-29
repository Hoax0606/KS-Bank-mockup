      *>****************************************************************
      *> TOKEBAT  -  統計サマリ
      *>   口座マスタから 口座数・種別内訳(普通/当座)・凍結数・総残高を、
      *>   TORIHIKI から 取引総件数を集計し TOKEI.RPT に出力する。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TOKEBAT.
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
       01  N-ACCT      PIC 9(7) VALUE 0.
       01  N-FUTSU     PIC 9(7) VALUE 0.
       01  N-TOUZA     PIC 9(7) VALUE 0.
       01  N-FROZEN    PIC 9(7) VALUE 0.
       01  T-BAL       PIC 9(15) VALUE 0.
       01  L1.
           05 FILLER   PIC X(11) VALUE "ACCOUNTS  =".
           05 L1V      PIC 9(7).
       01  L2.
           05 FILLER   PIC X(11) VALUE "FUTSU(1)  =".
           05 L2V      PIC 9(7).
       01  L3.
           05 FILLER   PIC X(11) VALUE "TOUZA(2)  =".
           05 L3V      PIC 9(7).
       01  L4.
           05 FILLER   PIC X(11) VALUE "FROZEN(9) =".
           05 L4V      PIC 9(7).
       01  L5.
           05 FILLER   PIC X(11) VALUE "TOTAL BAL =".
           05 L5V      PIC 9(15).
       01  L6.
           05 FILLER   PIC X(11) VALUE "TXN COUNT =".
           05 L6V      PIC 9(9).
       COPY WPACK.
       COPY WDB.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-SHU-HX   PIC X(2).
       01  HV-JOU-HX   PIC X(2).
       01  HV-ZAN-HX   PIC X(12).
       01  IND-ZAN     PIC S9(4) COMP.
       01  HV-TX       PIC 9(9).
       EXEC SQL END DECLARE SECTION END-EXEC.
       EXEC SQL
           DECLARE C-TK CURSOR FOR
             SELECT RAWTOHEX(SHUBETSU), RAWTOHEX(JOUTAI),
                    RAWTOHEX(ZANDAKA)
               FROM KOUZA
       END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           MOVE "./data/TOKEI.RPT" TO OUT-PATH
           MOVE SPACES TO WK-ENV
           ACCEPT WK-ENV FROM ENVIRONMENT "TOKE_OUT"
               ON EXCEPTION MOVE SPACES TO WK-ENV
           END-ACCEPT
           IF WK-ENV NOT = SPACES
               MOVE WK-ENV TO OUT-PATH
           END-IF
           PERFORM DB-CONNECT
           OPEN OUTPUT F-OUT
           EXEC SQL OPEN C-TK END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL
                   FETCH C-TK INTO :HV-SHU-HX, :HV-JOU-HX,
                        :HV-ZAN-HX:IND-ZAN
               END-EXEC
               IF SQLCODE = 0
                   PERFORM ACCUM
               END-IF
           END-PERFORM
           EXEC SQL CLOSE C-TK END-EXEC
           EXEC SQL
               SELECT COUNT(*) INTO :HV-TX FROM TORIHIKI
           END-EXEC
           MOVE N-ACCT  TO L1V
           WRITE REP-REC FROM L1
           MOVE N-FUTSU TO L2V
           WRITE REP-REC FROM L2
           MOVE N-TOUZA TO L3V
           WRITE REP-REC FROM L3
           MOVE N-FROZEN TO L4V
           WRITE REP-REC FROM L4
           MOVE T-BAL   TO L5V
           WRITE REP-REC FROM L5
           MOVE HV-TX   TO L6V
           WRITE REP-REC FROM L6
           CLOSE F-OUT
           PERFORM DB-DISCONNECT
           DISPLAY "[TOKEBAT] accounts=" N-ACCT " totalBal=" T-BAL
                   " txn=" HV-TX UPON SYSERR
           STOP RUN.
       ACCUM.
           ADD 1 TO N-ACCT
           IF HV-SHU-HX(2:1) = "1"
               ADD 1 TO N-FUTSU
           END-IF
           IF HV-SHU-HX(2:1) = "2"
               ADD 1 TO N-TOUZA
           END-IF
           IF HV-JOU-HX(2:1) = "9"
               ADD 1 TO N-FROZEN
           END-IF
           IF IND-ZAN >= 0
               MOVE HV-ZAN-HX TO PK-HEX(1:12)
               PERFORM DEC-P11
               ADD PK-P11 TO T-BAL
           END-IF.
       COPY PPACK.
       COPY PDBCONB.
       END PROGRAM TOKEBAT.
