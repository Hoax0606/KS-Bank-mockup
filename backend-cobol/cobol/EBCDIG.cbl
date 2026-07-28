      *>****************************************************************
      *> EBCDIG  -  EBCDIC <-> ASCII 数字(および数字系)変換
      *>   パック10進(COMP-3)は EBCDIC/ASCII で同一バイトなので対象外。
      *>   対象は DISPLAY 数字/日時など「表示数字」の 1byte 表現のみ。
      *>     EBCDIC 数字 '0'..'9' = X'F0'..'F9'
      *>     ASCII  数字 '0'..'9' = X'30'..'39'  (差 = 192)
      *>   EB-MODE 'T' : EBCDIC -> ASCII (native)   バッチ入力読取り時
      *>          'F' : ASCII(native) -> EBCDIC      バッチ出力書込み時
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. EBCDIG.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  K   PIC 9(4) COMP.
       01  BV  PIC 9(3) COMP.
       LINKAGE SECTION.
       01  EB-IO.
           05  EB-MODE  PIC X(1).
           05  EB-LEN   PIC 9(4).
           05  EB-BUF   PIC X(64).
       PROCEDURE DIVISION USING EB-IO.
       EB-MAIN.
           PERFORM VARYING K FROM 1 BY 1 UNTIL K > EB-LEN
               MOVE FUNCTION ORD(EB-BUF(K:1)) TO BV
               SUBTRACT 1 FROM BV
               IF EB-MODE = 'T'
                   IF BV >= 240 AND BV <= 249
                       SUBTRACT 192 FROM BV
                       MOVE FUNCTION CHAR(BV + 1) TO EB-BUF(K:1)
                   END-IF
               ELSE
                   IF BV >= 48 AND BV <= 57
                       ADD 192 TO BV
                       MOVE FUNCTION CHAR(BV + 1) TO EB-BUF(K:1)
                   END-IF
               END-IF
           END-PERFORM
           GOBACK.
       END PROGRAM EBCDIG.
