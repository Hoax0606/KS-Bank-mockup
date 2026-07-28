      *>****************************************************************
      *> RAWUTF8  -  CP930 RAW 原本 -> UTF-8 表示文字列(オンライン応答用)
      *>   §6 の変換経路 CP930->CP932->UTF-8 を TEAMENC('U') で実行。
      *>   TEAMENC が未マップ(RC=4)を返した場合は、KOUZA_EXT の
      *>   UTF-8 ミラー(MIRROR-IN)を権威フォールバックとして採用する。
      *>   → デモは常に正しく描画しつつ、RAW原本 と 変換機構を保持(§8.6)。
      *>
      *>   USING: RU-RAW    PIC X(nn)   CP930 バイト原本
      *>          RU-RAWLEN PIC 9(4)    有効バイト長
      *>          RU-MIRROR PIC X(nn)   UTF-8 ミラー(なければ SPACES)
      *>          RU-OUT    PIC X(nnn)  結果 UTF-8
      *>          RU-OUTLEN PIC 9(4)    結果バイト長
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. RAWUTF8.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WENCODE.
       01  MLEN         PIC 9(4) COMP.
       01  JC-MODE      PIC X VALUE 'D'.
       LINKAGE SECTION.
       01  RU-RAW       PIC X(256).
       01  RU-RAWLEN    PIC 9(4).
       01  RU-MIRROR    PIC X(256).
       01  RU-OUT       PIC X(1024).
       01  RU-OUTLEN    PIC 9(4).
       PROCEDURE DIVISION USING RU-RAW RU-RAWLEN RU-MIRROR
                                RU-OUT RU-OUTLEN.
       RU-MAIN.
           MOVE SPACES TO RU-OUT
           MOVE 'D' TO JC-MODE
      *>   JEF RAW 原本 -> UTF-8(JEF4J 変換サービスへ C ブリッジ経由)
           CALL "JEFCONV" USING JC-MODE RU-RAW RU-RAWLEN
                                RU-OUT RU-OUTLEN
           IF RETURN-CODE = 0 AND RU-OUTLEN > 0
      *>       末尾の空白(0x40 パディング由来)を除去
               MOVE FUNCTION STORED-CHAR-LENGTH(RU-OUT(1:RU-OUTLEN))
                    TO RU-OUTLEN
           END-IF
           IF RETURN-CODE NOT = 0 OR RU-OUTLEN = 0
      *>       サービス不可/空 -> UTF-8 ミラーを権威フォールバック
               MOVE FUNCTION STORED-CHAR-LENGTH(RU-MIRROR) TO MLEN
               IF MLEN > 0
                   MOVE RU-MIRROR(1:MLEN) TO RU-OUT
                   MOVE MLEN TO RU-OUTLEN
               ELSE
                   MOVE 0 TO RU-OUTLEN
               END-IF
           END-IF
           GOBACK.
       END PROGRAM RAWUTF8.
