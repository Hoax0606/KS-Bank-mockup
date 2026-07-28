      *>****************************************************************
      *> YAKANBAT  -  日次夜間バッチ (§7)  [オーケストレータ]
      *>   (1) CALL "SORTDAT" : TORIHIKI.DAT を口座番号で整列(→TORIHIKI.SORTED)
      *>   (2) 整列済を control break で口座別反映 + REPORT.WORK 生成 + KOUZA 更新
      *>   (3) CALL "SORTRPT" : REPORT.WORK を名義カナEBCDIC順で整列し MEISAI.RPT
      *>   ※ gixpp は SD(SORT記述)を解析できないため、SORT は SORTDAT/SORTRPT
      *>     (EXEC SQL を含まない純 COBOL モジュール)へ分離して CALL する。
      *>   ★結定打★ 1:利息切り捨て(普通のみ) 2:カナEBCDIC順(SORTRPT)
      *>            3:名義漢字 X(20) 20byte境界 4:COMP-3(パック10進)
      *>   出力はUTF-8変換しない(EBCDIC原本=現新比較の入力)。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. YAKANBAT.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT F-SDAT  ASSIGN TO "TORIHIKI.SORTED"
               ORGANIZATION IS SEQUENTIAL FILE STATUS IS FS-SDAT.
           SELECT F-RPTW  ASSIGN TO "REPORT.WORK"
               ORGANIZATION IS SEQUENTIAL FILE STATUS IS FS-RPTW.
       DATA DIVISION.
       FILE SECTION.
       FD  F-SDAT.
       01  DAT-REC        PIC X(97).
       FD  F-RPTW.
       01  RPTW-REC.
           05  RPTW-KANA   PIC X(20).      *> 名義カナ EBCDIC(ソートキー)
           05  RPTW-SEQ    PIC 9(6).       *> 投入順(安定化)
           05  RPTW-BODY   PIC X(58).      *> 明細レコード(D or T)
       WORKING-STORAGE SECTION.
       01  FS-SDAT        PIC X(2).
       01  FS-RPTW        PIC X(2).
       01  EOF-SW         PIC X(1) VALUE 'N'.
       01  SEQ-CNT        PIC 9(6) VALUE 0.
      *>-- control break 制御 --------------------------------------
       01  CUR-KOUZA      PIC 9(10) VALUE 0.
       01  HAVE-ACCT      PIC X(1) VALUE 'N'.
       01  ACC-BAL        PIC S9(13) VALUE 0.
       01  ACC-FEE        PIC S9(13) VALUE 0.
       01  ACC-INT        PIC S9(13) VALUE 0.
       01  ACC-SHU        PIC X(1)  VALUE '1'.
       01  ACC-KANJI      PIC X(20).
       01  ACC-KANA       PIC X(20).
      *>-- DAT レコード解析 ----------------------------------------
       01  P-ID           PIC 9(12).
       01  P-KOUZA        PIC 9(10).
       01  P-NICHIJI      PIC X(14).
       01  P-KBN          PIC X(01).
       01  P-KINGAKU      PIC S9(11) COMP-3.
       01  P-AITE         PIC 9(10).
       01  P-TESURYO      PIC S9(05) COMP-3.
       01  P-TEKIYOU      PIC X(40).
      *>-- COMP-3 抽出/変換ワーク ----------------------------------
       01  C3-6.
           05  C3-6X       PIC X(6).
       01  C3-6N REDEFINES C3-6  PIC S9(11) COMP-3.
       01  C3-3.
           05  C3-3X       PIC X(3).
       01  C3-3N REDEFINES C3-3  PIC S9(05) COMP-3.
       01  EB-IO.
           05  EB-MODE     PIC X(1).
           05  EB-LEN      PIC 9(4).
           05  EB-BUF      PIC X(64).
       01  WK-DIV         PIC S9(15).
       COPY WMEISAI.
       COPY WDB.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  DB-KOUZA       PIC 9(10).
       01  DB-KANJI       PIC X(20).
       01  DB-KANA        PIC X(20).
       01  DB-SHU         PIC X(01).
       01  DB-ZAN         PIC S9(11) COMP-3.
       01  DB-CONF        PIC S9(11) COMP-3.
       01  DB-TID         PIC 9(12).
       01  DB-DT          PIC X(14).
       01  DB-KBN         PIC X(01).
       01  DB-KIN         PIC S9(11) COMP-3.
       01  DB-AITE        PIC 9(10).
       01  DB-TES         PIC S9(05) COMP-3.
       01  DB-TEK         PIC X(40).
       EXEC SQL END DECLARE SECTION END-EXEC.
       PROCEDURE DIVISION.
      *>   ★バッチは独立ステップで実行する(run_batch.sh)★
      *>     GnuCOBOL の SORT 動詞は Oracle(GixSQL)使用後の同一プロセスで
      *>     呼ぶとクラッシュするため、SORT は別実行体 SORTDAT/SORTRPT に
      *>     分離し、シェルで順に起動する(古典 JCL のステップ分割相当):
      *>       (1) MKDAT     当日取引 TORIHIKI.DAT 生成
      *>       (2) SORTDAT   口座番号で整列 -> TORIHIKI.SORTED
      *>       (3) YAKANBAT  ← 本プログラム: 反映+更新+REPORT.WORK 生成
      *>       (4) SORTRPT   名義カナEBCDIC順に整列 -> MEISAI.RPT(結定打2)
       MAIN.
           DISPLAY "[YAKANBAT] start (reads TORIHIKI.SORTED)"
           PERFORM DB-CONNECT
           PERFORM PROCESS-SORTED
           PERFORM DB-DISCONNECT
           DISPLAY "[YAKANBAT] done (wrote REPORT.WORK)"
           STOP RUN.
      *>=============================================================
       PROCESS-SORTED.
           OPEN INPUT F-SDAT
           OPEN OUTPUT F-RPTW
           MOVE 'N' TO EOF-SW HAVE-ACCT
           MOVE 0 TO SEQ-CNT
           PERFORM UNTIL EOF-SW = 'Y'
               READ F-SDAT INTO DAT-REC
                   AT END MOVE 'Y' TO EOF-SW
                   NOT AT END
                       PERFORM PARSE-DAT
                       IF HAVE-ACCT = 'N'
                           PERFORM START-ACCT
                       ELSE
                           IF P-KOUZA NOT = CUR-KOUZA
                               PERFORM BREAK-ACCT
                               PERFORM START-ACCT
                           END-IF
                       END-IF
                       PERFORM APPLY-TXN
               END-READ
           END-PERFORM
           IF HAVE-ACCT = 'Y'
               PERFORM BREAK-ACCT
           END-IF
           CLOSE F-SDAT F-RPTW.
      *>-- DAT 1件を native へ解析(表示数字は EBCDIC->native, COMP-3直接)
       PARSE-DAT.
           MOVE DAT-REC(1:12) TO EB-BUF
           MOVE 'T' TO EB-MODE MOVE 12 TO EB-LEN
           CALL "EBCDIG" USING EB-IO
           MOVE EB-BUF(1:12) TO P-ID
           MOVE DAT-REC(13:10) TO EB-BUF MOVE 10 TO EB-LEN
           CALL "EBCDIG" USING EB-IO
           MOVE EB-BUF(1:10) TO P-KOUZA
           MOVE DAT-REC(23:14) TO EB-BUF MOVE 14 TO EB-LEN
           CALL "EBCDIG" USING EB-IO
           MOVE EB-BUF(1:14) TO P-NICHIJI
           MOVE DAT-REC(37:1) TO EB-BUF MOVE 1 TO EB-LEN
           CALL "EBCDIG" USING EB-IO
           MOVE EB-BUF(1:1) TO P-KBN
           MOVE DAT-REC(38:6) TO C3-6X
           MOVE C3-6N TO P-KINGAKU
           MOVE 0 TO P-AITE MOVE 0 TO P-TESURYO
           IF P-KBN = '3'
               MOVE DAT-REC(44:10) TO EB-BUF MOVE 10 TO EB-LEN
               MOVE 'T' TO EB-MODE
               CALL "EBCDIG" USING EB-IO
               MOVE EB-BUF(1:10) TO P-AITE
               MOVE DAT-REC(54:3) TO C3-3X
               MOVE C3-3N TO P-TESURYO
           END-IF
           MOVE DAT-REC(58:40) TO P-TEKIYOU.
      *>-- 口座処理開始: KOUZA マスタ取得 -------------------------
       START-ACCT.
           MOVE P-KOUZA TO CUR-KOUZA
           MOVE 'Y' TO HAVE-ACCT
           MOVE 0 TO ACC-FEE ACC-INT
           MOVE P-KOUZA TO DB-KOUZA
           EXEC SQL
               SELECT MEIGI_KANJI, MEIGI_KANA, SHUBETSU, ZANDAKA
                 INTO :DB-KANJI, :DB-KANA, :DB-SHU, :DB-ZAN
                 FROM KOUZA WHERE KOUZA_NO = :DB-KOUZA
           END-EXEC
           IF SQLCODE = 0
               MOVE DB-KANJI TO ACC-KANJI
               MOVE DB-KANA  TO ACC-KANA
               MOVE DB-SHU   TO ACC-SHU
               MOVE DB-ZAN   TO ACC-BAL
           ELSE
               MOVE SPACES TO ACC-KANJI ACC-KANA
               MOVE '1' TO ACC-SHU
               MOVE 0 TO ACC-BAL
               DISPLAY "  WARN kouza not in master: " P-KOUZA
           END-IF.
      *>-- 1取引を残高へ反映 + D レコード生成 + TORIHIKI 追記 ------
       APPLY-TXN.
           EVALUATE P-KBN
               WHEN '1' ADD P-KINGAKU TO ACC-BAL
               WHEN '2' SUBTRACT P-KINGAKU FROM ACC-BAL
               WHEN '3'
                   SUBTRACT P-KINGAKU FROM ACC-BAL
                   SUBTRACT P-TESURYO FROM ACC-BAL
                   ADD P-TESURYO TO ACC-FEE
           END-EVALUATE
           MOVE SPACES TO MEISAI-D
           MOVE X'C4'      TO MD-KUBUN           *> EBCDIC 'D'
           MOVE CUR-KOUZA  TO MD-KOUZA-NO
           MOVE ACC-KANJI  TO MD-MEIGI-KANJI     *> 20byte RAW(結定打3)
           MOVE P-NICHIJI  TO MD-TORIHIKI-DT
           MOVE P-KBN      TO MD-KBN
           MOVE P-KINGAKU  TO MD-KINGAKU
           MOVE ACC-BAL    TO MD-ZANDAKA-GO
           PERFORM ENC-D-DISPLAY
           PERFORM RELEASE-RPTW-D
           PERFORM INSERT-TORIHIKI.
      *>-- 口座 break: 利息/確定残高 + KOUZA 更新 + T レコード -----
       BREAK-ACCT.
           MOVE 0 TO ACC-INT
           IF ACC-SHU = '1' AND ACC-BAL > 0
               MOVE ACC-BAL TO WK-DIV
               COMPUTE ACC-INT =
                   FUNCTION INTEGER-PART(WK-DIV / 365000)
           END-IF
           ADD ACC-INT TO ACC-BAL
           MOVE CUR-KOUZA TO DB-KOUZA
           MOVE ACC-BAL   TO DB-CONF
           EXEC SQL
               UPDATE KOUZA SET ZANDAKA = :DB-CONF
                WHERE KOUZA_NO = :DB-KOUZA
           END-EXEC
           EXEC SQL COMMIT END-EXEC
           MOVE SPACES TO MEISAI-T
           MOVE X'E3'     TO MT-KUBUN            *> EBCDIC 'T'
           MOVE CUR-KOUZA TO MT-KOUZA-NO
           MOVE ACC-INT   TO MT-RISOKU
           MOVE ACC-FEE   TO MT-TESURYO-GK
           MOVE ACC-BAL   TO MT-KAKUTEI-ZAN
           MOVE ALL X'40' TO MT-FILLER
           PERFORM ENC-T-DISPLAY
           PERFORM RELEASE-RPTW-T
           MOVE 'N' TO HAVE-ACCT.
      *>-- 表示数字を EBCDIC へ(参照修飾でレコード上を直接変換) ---
       ENC-D-DISPLAY.
           MOVE 'F' TO EB-MODE
           MOVE 10 TO EB-LEN MOVE MEISAI-D(2:10) TO EB-BUF
           CALL "EBCDIG" USING EB-IO
           MOVE EB-BUF(1:10) TO MEISAI-D(2:10)
           MOVE 14 TO EB-LEN MOVE MEISAI-D(32:14) TO EB-BUF
           CALL "EBCDIG" USING EB-IO
           MOVE EB-BUF(1:14) TO MEISAI-D(32:14)
           MOVE 1 TO EB-LEN MOVE MEISAI-D(46:1) TO EB-BUF
           CALL "EBCDIG" USING EB-IO
           MOVE EB-BUF(1:1) TO MEISAI-D(46:1).
       ENC-T-DISPLAY.
           MOVE 'F' TO EB-MODE
           MOVE 10 TO EB-LEN MOVE MEISAI-T(2:10) TO EB-BUF
           CALL "EBCDIG" USING EB-IO
           MOVE EB-BUF(1:10) TO MEISAI-T(2:10).
      *>-- レポートワーク RELEASE(名義カナ EBCDIC をキーに) -------
       RELEASE-RPTW-D.
           ADD 1 TO SEQ-CNT
           MOVE ACC-KANA  TO RPTW-KANA
           MOVE SEQ-CNT   TO RPTW-SEQ
           MOVE MEISAI-D  TO RPTW-BODY
           WRITE RPTW-REC.
       RELEASE-RPTW-T.
           ADD 1 TO SEQ-CNT
           MOVE ACC-KANA  TO RPTW-KANA
           MOVE SEQ-CNT   TO RPTW-SEQ
           MOVE MEISAI-T  TO RPTW-BODY
           WRITE RPTW-REC.
      *>-- TORIHIKI へ 1件 INSERT ---------------------------------
       INSERT-TORIHIKI.
           EXEC SQL
               SELECT SEQ_TORIHIKI.NEXTVAL INTO :DB-TID FROM DUAL
           END-EXEC
           MOVE CUR-KOUZA TO DB-KOUZA
           MOVE P-NICHIJI TO DB-DT
           MOVE P-KBN     TO DB-KBN
           MOVE P-KINGAKU TO DB-KIN
           MOVE P-TEKIYOU TO DB-TEK
           IF P-KBN = '3'
               MOVE P-AITE    TO DB-AITE
               MOVE P-TESURYO TO DB-TES
               EXEC SQL
                   INSERT INTO TORIHIKI
                     (TORIHIKI_ID, KOUZA_NO, TORIHIKI_DT, TORIHIKI_KBN,
                      KINGAKU, AITE_KOUZA, TESURYO, TEKIYOU)
                   VALUES
                     (:DB-TID, :DB-KOUZA, :DB-DT, :DB-KBN,
                      :DB-KIN, :DB-AITE, :DB-TES, :DB-TEK)
               END-EXEC
           ELSE
               EXEC SQL
                   INSERT INTO TORIHIKI
                     (TORIHIKI_ID, KOUZA_NO, TORIHIKI_DT, TORIHIKI_KBN,
                      KINGAKU, AITE_KOUZA, TESURYO, TEKIYOU)
                   VALUES
                     (:DB-TID, :DB-KOUZA, :DB-DT, :DB-KBN,
                      :DB-KIN, NULL, NULL, :DB-TEK)
               END-EXEC
           END-IF.
       COPY PDBCONB.
       END PROGRAM YAKANBAT.
