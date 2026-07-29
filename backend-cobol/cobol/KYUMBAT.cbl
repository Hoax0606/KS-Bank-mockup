      *>****************************************************************
      *> KYUMBAT  -  休眠口座抽出
      *>   取引実績(TORIHIKI)が一件も無い口座を抽出し、KYUMIN.RPT に
      *>   口座番号一覧を出力する(デモ簡易版: 無取引=休眠候補)。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. KYUMBAT.
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
           05 FILLER   PIC X(9) VALUE "DORMANT= ".
           05 L-ACCT   PIC X(7).
       COPY WPACK.
       COPY WDB.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KZ-HX    PIC X(14).
       EXEC SQL END DECLARE SECTION END-EXEC.
       EXEC SQL
           DECLARE C-KY CURSOR FOR
             SELECT RAWTOHEX(K.KOUZA_NO)
               FROM KOUZA K
              WHERE NOT EXISTS
                (SELECT 1 FROM TORIHIKI T
                  WHERE T.KOUZA_NO = K.KOUZA_NO)
              ORDER BY K.KOUZA_NO
       END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           MOVE "./data/KYUMIN.RPT" TO OUT-PATH
           MOVE SPACES TO WK-ENV
           ACCEPT WK-ENV FROM ENVIRONMENT "KYUM_OUT"
               ON EXCEPTION MOVE SPACES TO WK-ENV
           END-ACCEPT
           IF WK-ENV NOT = SPACES
               MOVE WK-ENV TO OUT-PATH
           END-IF
           PERFORM DB-CONNECT
           OPEN OUTPUT F-OUT
           EXEC SQL OPEN C-KY END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL FETCH C-KY INTO :HV-KZ-HX END-EXEC
               IF SQLCODE = 0
                   MOVE HV-KZ-HX TO KY-HEX(1:14)
                   MOVE 7 TO KY-N
                   PERFORM DEC-KEY
                   MOVE KY-STR(1:7) TO L-ACCT
                   WRITE REP-REC FROM L-DTL
                   ADD 1 TO N-OUT
               END-IF
           END-PERFORM
           EXEC SQL CLOSE C-KY END-EXEC
           CLOSE F-OUT
           PERFORM DB-DISCONNECT
           DISPLAY "[KYUMBAT] dormant accounts=" N-OUT UPON SYSERR
           STOP RUN.
       COPY PPACK.
       COPY PDBCONB.
       END PROGRAM KYUMBAT.
