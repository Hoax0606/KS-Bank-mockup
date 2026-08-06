      *>****************************************************************
      *> HOLDINGS  -  保有口座 CGI (通常型/Shift-JIS DB版)
      *>   GET: kouza -> 指定口座を1要素配列で返す。全項目 通常列から直接。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. HOLDINGS.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WCGI.
       COPY WONLINE.
       COPY WDB.
       01  WK-CNT      PIC 9(9) VALUE 0.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KOUZA    PIC 9(7).
       01  HV-KANJI    PIC X(40).
       01  HV-SHU      PIC X(1).
       01  HV-TYPE     PIC X(20).
       01  HV-ZAN      PIC S9(11).
       01  HV-JOU      PIC X(1).
       01  HV-BR       PIC X(3).
       01  HV-PRIM     PIC X(1).
       01  HV-CNT      PIC 9(9).
      *> 会員情報(会員情報画面) — KOUZA_EXT プロフィール。新規口座は未入力で NULL。
      *>   MKDAT.cbl と同じ NULL インジケータ方式(IND-*)を使う。
      *>   ※ SELECT 列に NVL(...) を書くと GixSQL 1.0.20b の列パーサが数を誤認識し
      *>     "ResParams(N) and fields(N-1) are different" で毎回失敗する
      *>     (実測確認済み)。原列をそのまま取り、NULL 判定は INDICATOR で行う。
       01  HV-BIRTH    PIC X(10).
       01  HV-SEX      PIC X(6).
       01  HV-ZIP      PIC X(7).
       01  HV-ADDR     PIC X(200).
       01  HV-PHONE    PIC X(13).
       01  HV-EMAIL    PIC X(120).
       01  HV-JOB      PIC X(40).
       01  IND-BIRTH   PIC S9(4) COMP.
       01  IND-SEX     PIC S9(4) COMP.
       01  IND-ZIP     PIC S9(4) COMP.
       01  IND-ADDR    PIC S9(4) COMP.
       01  IND-PHONE   PIC S9(4) COMP.
       01  IND-EMAIL   PIC S9(4) COMP.
       01  IND-JOB     PIC S9(4) COMP.
       EXEC SQL END DECLARE SECTION END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           CALL "CGIINIT" USING CGI-ENV
           MOVE "kouza" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           MOVE FUNCTION NUMVAL(CP-VALUE) TO HV-KOUZA
           PERFORM DB-CONNECT
           MOVE 0 TO HV-CNT
           EXEC SQL
               SELECT COUNT(*) INTO :HV-CNT
                 FROM KOUZA WHERE KOUZA_NO = :HV-KOUZA
           END-EXEC
           IF HV-CNT = 0
               PERFORM DB-DISCONNECT
               MOVE "kouza_not_found" TO WK-ERRMSG PERFORM ERR-404
           END-IF
           EXEC SQL
               SELECT K.MEIGI_KANJI, K.SHUBETSU,
                      K.ZANDAKA, K.JOUTAI,
                      X.ACCT_TYPE, X.BRANCH_CODE, X.IS_PRIMARY,
                      X.BIRTH, X.SEX, X.ZIP, X.ADDR,
                      X.PHONE, X.EMAIL, X.JOB
                 INTO :HV-KANJI, :HV-SHU, :HV-ZAN, :HV-JOU,
                      :HV-TYPE, :HV-BR, :HV-PRIM,
                      :HV-BIRTH:IND-BIRTH, :HV-SEX:IND-SEX,
                      :HV-ZIP:IND-ZIP, :HV-ADDR:IND-ADDR,
                      :HV-PHONE:IND-PHONE, :HV-EMAIL:IND-EMAIL,
                      :HV-JOB:IND-JOB
                 FROM KOUZA K, KOUZA_EXT X
                WHERE X.KOUZA_NO = K.KOUZA_NO
                  AND K.KOUZA_NO = :HV-KOUZA
           END-EXEC
      *>   新規口座は KOUZA_EXT のプロフィール列が NULL — 空欄として返す
           IF IND-BIRTH < 0 MOVE SPACES TO HV-BIRTH END-IF
           IF IND-SEX   < 0 MOVE SPACES TO HV-SEX   END-IF
           IF IND-ZIP   < 0 MOVE SPACES TO HV-ZIP   END-IF
           IF IND-ADDR  < 0 MOVE SPACES TO HV-ADDR  END-IF
           IF IND-PHONE < 0 MOVE SPACES TO HV-PHONE END-IF
           IF IND-EMAIL < 0 MOVE SPACES TO HV-EMAIL END-IF
           IF IND-JOB   < 0 MOVE SPACES TO HV-JOB   END-IF
           PERFORM DB-DISCONNECT
           PERFORM BUILD-JSON
           CALL "CGIRESP" USING RESP
           STOP RUN.
       BUILD-JSON.
           MOVE 1 TO RESP-PTR MOVE SPACES TO RESP-BUF
           MOVE HV-KOUZA TO WK-KOUZA-Z
           STRING '{"ok":true,"holdings":[{"kouza":"' DELIMITED SIZE
                  WK-KOUZA-Z DELIMITED SIZE
                  '","branch":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-BR) DELIMITED SIZE
                  '","meigiKanji":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-KANJI) DELIMITED SIZE
                  '","shubetsu":"' DELIMITED SIZE
                  HV-SHU DELIMITED SIZE
                  '","type":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-TYPE) DELIMITED SIZE
                  '","joutai":"' DELIMITED SIZE
                  HV-JOU DELIMITED SIZE
                  '","isPrimary":"' DELIMITED SIZE
                  HV-PRIM DELIMITED SIZE
                  '","zandaka":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-ZAN TO WK-NUM11
           PERFORM FMT-NUM
      *>   会員情報(会員情報画面) — 新規口座は未入力で空文字のまま返る
      *>   ★zandaka は数値(無引用)なので、直前を閉じる '"' を付けない — ',' のみ★
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  ',"birth":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-BIRTH) DELIMITED SIZE
                  '","sex":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-SEX) DELIMITED SIZE
                  '","zip":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-ZIP) DELIMITED SIZE
                  '","addr":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-ADDR) DELIMITED SIZE
                  '","phone":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-PHONE) DELIMITED SIZE
                  '","email":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-EMAIL) DELIMITED SIZE
                  '","job":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-JOB) DELIMITED SIZE
                  '"}]}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN.
       COPY PFMTNUM.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM HOLDINGS.
