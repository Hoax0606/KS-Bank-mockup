      *>****************************************************************
      *> MKDAT  -  当日取引抽出 (オプション1: 実データ)
      *>   DB の TORIHIKI(RAW)を読み、97byte固定 EBCDIC の TORIHIKI.DAT を
      *>   生成する。TORIHIKI 各列は既に EBCDIC/COMP-3/存10進 RAW なので、
      *>   バイトをそのままレコード位置へ配置(口座番号は 7->10 桁に 0xF0 パディング)。
      *>   バッチ(YAKANBAT)の入力。オンライン発生の実取引がそのまま流れる。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MKDAT.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT F-OUT ASSIGN TO OUT-PATH
               ORGANIZATION IS SEQUENTIAL FILE STATUS IS FS.
       DATA DIVISION.
       FILE SECTION.
       FD  F-OUT.
       COPY WTRDAT.
       WORKING-STORAGE SECTION.
       01  OUT-PATH   PIC X(256).
       01  FS         PIC X(2).
       01  N-OUT      PIC 9(6) VALUE 0.
       01  PAD3       PIC X(3) VALUE X'F0F0F0'.
       COPY WDB.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-ID      PIC X(12).
       01  HV-KZ      PIC X(7).
       01  HV-DT      PIC X(14).
       01  HV-KBN     PIC X(1).
       01  HV-KIN     PIC X(6).
       01  HV-AITE    PIC X(7).
       01  HV-TES     PIC X(3).
       01  HV-TEK     PIC X(40).
       01  IND-AITE   PIC S9(4) COMP.
       01  IND-TES    PIC S9(4) COMP.
       01  IND-TEK    PIC S9(4) COMP.
       EXEC SQL END DECLARE SECTION END-EXEC.
       EXEC SQL
           DECLARE C-TR CURSOR FOR
             SELECT TORIHIKI_ID, KOUZA_NO, TORIHIKI_DT, TORIHIKI_KBN,
                    KINGAKU, AITE_KOUZA, TESURYO, TEKIYOU
               FROM TORIHIKI
              ORDER BY KOUZA_NO, TORIHIKI_ID
       END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           MOVE "./data/TORIHIKI.DAT" TO OUT-PATH
           ACCEPT OUT-PATH FROM ENVIRONMENT "DAT_IN"
           PERFORM DB-CONNECT
           OPEN OUTPUT F-OUT
           EXEC SQL OPEN C-TR END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL
                   FETCH C-TR
                     INTO :HV-ID, :HV-KZ, :HV-DT, :HV-KBN,
                          :HV-KIN, :HV-AITE:IND-AITE,
                          :HV-TES:IND-TES, :HV-TEK:IND-TEK
               END-EXEC
               IF SQLCODE = 0
                   PERFORM BUILD-REC
                   WRITE TR-DAT-REC
                   ADD 1 TO N-OUT
               END-IF
           END-PERFORM
           EXEC SQL CLOSE C-TR END-EXEC
           CLOSE F-OUT
           PERFORM DB-DISCONNECT
           DISPLAY "[MKDAT] extracted " N-OUT " recs from TORIHIKI"
                   UPON SYSERR
           STOP RUN.
       BUILD-REC.
           MOVE ALL X'40' TO TR-DAT-REC
           MOVE HV-ID  TO TR-DAT-REC(1:12)
           MOVE PAD3   TO TR-DAT-REC(13:3)
           MOVE HV-KZ  TO TR-DAT-REC(16:7)
           MOVE HV-DT  TO TR-DAT-REC(23:14)
           MOVE HV-KBN TO TR-DAT-REC(37:1)
           MOVE HV-KIN TO TR-DAT-REC(38:6)
           IF IND-AITE >= 0
               MOVE PAD3    TO TR-DAT-REC(44:3)
               MOVE HV-AITE TO TR-DAT-REC(47:7)
           END-IF
           IF IND-TES >= 0
               MOVE HV-TES TO TR-DAT-REC(54:3)
           END-IF
           IF IND-TEK >= 0
               MOVE HV-TEK TO TR-DAT-REC(58:40)
           END-IF.
       COPY PDBCONB.
       END PROGRAM MKDAT.
