      *>****************************************************************
      *> TEAMENC  -  文字コード変換サブプログラム (§2 / §8.6)
      *>
      *>   固定インタフェース(呼出元と共有: copy/WENCODE.cpy):
      *>     ENC-MODE 'C' : CP930(EBCDIC) -> CP932(Shift_JIS 相当)
      *>     ENC-MODE 'U' : CP930 -> CP932 -> UTF-8   (オンライン応答用)
      *>     ENC-IN / ENC-IN-LEN  : 入力バイト列(RAW原本)
      *>     ENC-OUT / ENC-OUT-LEN: 出力バイト列
      *>     ENC-RC   : 0=全マップ成功 / 4=未マップ字あり(代替字 U+3013 〓)
      *>
      *>   ★ 本実装は「デモ用エンコーダ」。§8.6 のとおりチーム・エンコーダ
      *>     (DataBridge 等)差替を前提とする。ここで固定するのは
      *>       (1) 呼出インタフェース
      *>       (2) SO(0x0E)/SI(0x0F) シフト状態の厳密な取り回し
      *>       (3) SBCS(ASCII/カナ) の変換
      *>     DBCS(漢字)はデモ辞書 + 未マップ検出。全 cp300 対応は差替側。
      *>
      *>   SO/SI 仕様: SI状態(初期)=1byte SBCS。SO(0x0E)で2byte DBCSへ、
      *>              SI(0x0F)で SBCS へ戻る。SO/SI 自体は出力しない。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEAMENC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WK.
           05  I              PIC 9(4) COMP VALUE 1.
           05  J              PIC 9(4) COMP VALUE 1.
           05  SHIFT-STATE    PIC X(1) VALUE 'S'.   *> S=SBCS D=DBCS
           05  B1             PIC X(1).
           05  B1N            PIC 9(3) COMP.
           05  B2             PIC X(1).
           05  B2N            PIC 9(3) COMP.
           05  CODEPOINT      PIC 9(6) COMP VALUE 0.
           05  MAPPED         PIC X(1) VALUE 'Y'.
           05  MAPPED-LOCAL   PIC X(1) VALUE 'Y'.
      *>-- EBCDIC(CP930 SBCS/IBM-290系) -> Unicode 変換表(必要範囲) ----
      *>   添字 = EBCDICバイト値+1。値 = Unicodeコードポイント(0=未定義)。
       01  SBCS-TBL.
           05  FILLER PIC 9(6) COMP OCCURS 256 TIMES.
       01  SBCS-TBL-R REDEFINES SBCS-TBL.
           05  SBCS-CP PIC 9(6) COMP OCCURS 256 TIMES.
      *>   DBCS(漢字)デモ辞書は LOOKUP-DBCS 内にインラインで保持
      *>   (実データ表示は KOUZA_EXT の UTF-8 ミラーを権威とする)。
       LINKAGE SECTION.
       COPY WENCODE.
       PROCEDURE DIVISION USING ENC-IO.
       MAIN.
           PERFORM INIT-SBCS
           MOVE 1 TO J
           MOVE 'S' TO SHIFT-STATE
           MOVE 'Y' TO MAPPED
           MOVE 1 TO I
           PERFORM UNTIL I > ENC-IN-LEN
               MOVE ENC-IN(I:1) TO B1
               EVALUATE TRUE
      *>          SO: SBCS -> DBCS へ(バイトは出力しない)
                   WHEN B1 = X'0E'
                       MOVE 'D' TO SHIFT-STATE
                       ADD 1 TO I
      *>          SI: DBCS -> SBCS へ
                   WHEN B1 = X'0F'
                       MOVE 'S' TO SHIFT-STATE
                       ADD 1 TO I
      *>          SBCS 1byte
                   WHEN SHIFT-STATE = 'S'
                       MOVE FUNCTION ORD(B1) TO B1N
                       SUBTRACT 1 FROM B1N
                       MOVE SBCS-CP(B1N + 1) TO CODEPOINT
                       IF CODEPOINT = 0
                           MOVE 63 TO CODEPOINT   *> '?' 未定義
                           MOVE 'N' TO MAPPED
                       END-IF
                       PERFORM EMIT-CP
                       ADD 1 TO I
      *>          DBCS 2byte
                   WHEN OTHER
                       IF I + 1 > ENC-IN-LEN
                           MOVE 12307 TO CODEPOINT  *> 〓 U+3013
                           MOVE 'N' TO MAPPED
                           PERFORM EMIT-CP
                           ADD 1 TO I
                       ELSE
                           MOVE ENC-IN(I + 1:1) TO B2
                           PERFORM LOOKUP-DBCS
                           PERFORM EMIT-CP
                           ADD 2 TO I
                       END-IF
               END-EVALUATE
           END-PERFORM
           SUBTRACT 1 FROM J GIVING ENC-OUT-LEN
           IF MAPPED = 'Y'
               MOVE 0 TO ENC-RC
           ELSE
               MOVE 4 TO ENC-RC
           END-IF
           GOBACK.

      *>-------------------------------------------------------------
      *> DBCS 辞書引き(デモ範囲)。未登録は 〓(U+3013)。
      *>   ※ 実データは KOUZA_EXT.KANJI_UTF8 ミラーを権威フォールバック
      *>     とする(README 参照)。ここは変換機構の実証。
      *>-------------------------------------------------------------
       LOOKUP-DBCS.
           MOVE 12307 TO CODEPOINT      *> 既定=〓
           MOVE 'N' TO MAPPED-LOCAL
      *>   デモ辞書(cp300 の一部)。必要字は差替側で拡張。
      *>   例) 全角スペース cp300 X'4040' -> U+3000
           IF ENC-IN(I:1) = X'40' AND B2 = X'40'
               MOVE 12288 TO CODEPOINT
               MOVE 'Y' TO MAPPED-LOCAL
           END-IF
           IF MAPPED-LOCAL = 'N'
               MOVE 'N' TO MAPPED
           END-IF.

      *>-------------------------------------------------------------
      *> Unicode コードポイント -> UTF-8(mode 'U') / そのまま(mode 'C')
      *>   mode 'C' は CP932 バイト列だが、デモでは UTF-8 と同経路で近似
      *>   出力(検証・ログ用途)。オンライン応答は 'U' を使用。
      *>-------------------------------------------------------------
       EMIT-CP.
           EVALUATE TRUE
               WHEN CODEPOINT < 128
                   MOVE FUNCTION CHAR(CODEPOINT + 1) TO ENC-OUT(J:1)
                   ADD 1 TO J
               WHEN CODEPOINT < 2048
      *>           2byte UTF-8: 110xxxxx 10xxxxxx
                   DIVIDE CODEPOINT BY 64 GIVING B1N
                   ADD 192 TO B1N
                   MOVE FUNCTION CHAR(B1N + 1) TO ENC-OUT(J:1)
                   MOVE FUNCTION MOD(CODEPOINT, 64) TO B2N
                   ADD 128 TO B2N
                   MOVE FUNCTION CHAR(B2N + 1) TO ENC-OUT(J + 1:1)
                   ADD 2 TO J
               WHEN OTHER
      *>           3byte UTF-8: 1110xxxx 10xxxxxx 10xxxxxx
                   DIVIDE CODEPOINT BY 4096 GIVING B1N
                   ADD 224 TO B1N
                   MOVE FUNCTION CHAR(B1N + 1) TO ENC-OUT(J:1)
                   DIVIDE CODEPOINT BY 64 GIVING B2N
                   MOVE FUNCTION MOD(B2N, 64) TO B2N
                   ADD 128 TO B2N
                   MOVE FUNCTION CHAR(B2N + 1) TO ENC-OUT(J + 1:1)
                   MOVE FUNCTION MOD(CODEPOINT, 64) TO B2N
                   ADD 128 TO B2N
                   MOVE FUNCTION CHAR(B2N + 1) TO ENC-OUT(J + 2:1)
                   ADD 3 TO J
           END-EVALUATE.

      *>-------------------------------------------------------------
      *> SBCS 変換表初期化(EBCDIC CP930 の必要範囲 -> Unicode)
      *>   invariant EBCDIC: 空白/数字/英大小/一部記号。
      *>-------------------------------------------------------------
       INIT-SBCS.
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > 256
               MOVE 0 TO SBCS-CP(I)
           END-PERFORM
           MOVE 32   TO SBCS-CP(65)     *> X'40' 空白
      *>   数字 0-9 : EBCDIC X'F0'..'F9' = 240..249
           PERFORM VARYING I FROM 0 BY 1 UNTIL I > 9
               COMPUTE SBCS-CP(240 + I + 1) = 48 + I
           END-PERFORM
      *>   英大文字 A-I X'C1'..'C9', J-R X'D1'..'D9', S-Z X'E2'..'E9'
           PERFORM VARYING I FROM 0 BY 1 UNTIL I > 8
               COMPUTE SBCS-CP(193 + I + 1) = 65 + I
               COMPUTE SBCS-CP(209 + I + 1) = 74 + I
           END-PERFORM
           PERFORM VARYING I FROM 0 BY 1 UNTIL I > 7
               COMPUTE SBCS-CP(226 + I + 1) = 83 + I
           END-PERFORM
      *>   英小文字 a-i X'81'..'89', j-r X'91'..'99', s-z X'A2'..'A9'
           PERFORM VARYING I FROM 0 BY 1 UNTIL I > 8
               COMPUTE SBCS-CP(129 + I + 1) = 97 + I
               COMPUTE SBCS-CP(145 + I + 1) = 106 + I
           END-PERFORM
           PERFORM VARYING I FROM 0 BY 1 UNTIL I > 7
               COMPUTE SBCS-CP(162 + I + 1) = 115 + I
           END-PERFORM
      *>   一部記号
           MOVE 46 TO SBCS-CP(76)      *> X'4B' .
           MOVE 45 TO SBCS-CP(97)      *> X'60' -
           MOVE 47 TO SBCS-CP(98)      *> X'61' /
           MOVE 44 TO SBCS-CP(108)     *> X'6B' ,
           .
