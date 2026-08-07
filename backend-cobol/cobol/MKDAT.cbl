      *>****************************************************************
      *> MKDAT  -  当日取引抽出 (通常型/Shift-JIS DB版)
      *>   DB の TORIHIKI を読み、97byte固定 ネイティブの TORIHIKI.DAT を
      *>   生成する。各列を通常型のホスト変数で受け取り、レコード項目へ
      *>   そのまま MOVE(数字=ASCII表示, 金額=COMP-3, 摘要=Shift-JIS)。
      *>   口座番号は 7->10 桁へ前ゼロ埋め(PIC 9(10))。YAKANBAT の入力。
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
       FD  F-OUT RECORD CONTAINS 97 CHARACTERS.
      *>   ★2026-08 확인된 버그 수정: RECORD CONTAINS가 없으면 EXEC SQL
      *>   FETCH 루프와 얽혀 특정 건수(9건+)에서 레코드 1건이 조용히
      *>   누락됨(GnuCOBOL이 레코드 길이를 묵시적으로 잘못 추정하는 것으로
      *>   보임). 명시적으로 길이를 지정해 해결.
       COPY WTRDAT.
       WORKING-STORAGE SECTION.
       01  OUT-PATH   PIC X(256).
       01  FS         PIC X(2).
       01  N-OUT      PIC 9(6) VALUE 0.
       COPY WDB.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-ID      PIC 9(12).
       01  HV-KZ      PIC 9(7).
       01  HV-DT      PIC X(14).
       01  HV-KBN     PIC X(1).
       01  HV-KIN     PIC S9(11).
       01  HV-AITE    PIC 9(7).
       01  HV-TES     PIC S9(5).
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
           INITIALIZE TR-DAT-REC
           MOVE HV-ID  TO TD-ID
           MOVE HV-KZ  TO TD-KOUZA-NO
           MOVE HV-DT  TO TD-NICHIJI
           MOVE HV-KBN TO TD-KBN
           MOVE HV-KIN TO TD-KINGAKU
           MOVE SPACES TO TD-EXT
           IF IND-AITE >= 0
               MOVE HV-AITE TO TD-AITE-KOUZA
           END-IF
           IF IND-TES >= 0
               MOVE HV-TES TO TD-TESURYO
           END-IF
           IF IND-TEK >= 0
               MOVE HV-TEK TO TD-TEKIYOU
           END-IF.
       COPY PDBCONB.
       END PROGRAM MKDAT.
