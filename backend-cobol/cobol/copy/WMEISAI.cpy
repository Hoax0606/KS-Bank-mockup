      *>****************************************************************
      *> WMEISAI.cpy  -  明細レポート出力 MEISAI.RPT レコード (§4.2)
      *>   全レコード 58 byte 固定(確定)。EBCDIC(CP930)無変換出力。
      *>   D=明細行(58byte), T=口座合計(実内容29byte+空白29byte=58byte)。
      *>   D と T は先頭 1byte のレコード区分で判別。両者を同一 58byte 枠で扱う。
      *>****************************************************************
       01  MEISAI-REC.
           05  MR-KUBUN         PIC X(01).            *> 'D' or 'T'
           05  MR-BODY          PIC X(57).
      *>-- D レコード(明細, 58 byte) --------------------------------
       01  MEISAI-D.
           05  MD-KUBUN         PIC X(01).            *> 1  'D'
           05  MD-KOUZA-NO      PIC 9(10).            *> 2-11  (10)
           05  MD-MEIGI-KANJI   PIC X(20).            *> 12-31 (20) SO/SI mixed
           05  MD-TORIHIKI-DT   PIC X(14).            *> 32-45 (14)
           05  MD-KBN           PIC X(01).            *> 46    (1)
           05  MD-KINGAKU       PIC S9(11) COMP-3.    *> 47-52 (6)
           05  MD-ZANDAKA-GO    PIC S9(11) COMP-3.    *> 53-58 (6) 取引後残高
      *> 1+10+20+14+1+6+6 = 58 byte
      *>-- T レコード(口座合計, 実内容29byte + 空白29byte = 58 byte) -
       01  MEISAI-T.
           05  MT-KUBUN         PIC X(01).            *> 1  'T'
           05  MT-KOUZA-NO      PIC 9(10).            *> 2-11  (10)
           05  MT-RISOKU        PIC S9(11) COMP-3.    *> 12-17 (6) 利息(結定打1)
           05  MT-TESURYO-GK    PIC S9(11) COMP-3.    *> 18-23 (6) 手数料合計
           05  MT-KAKUTEI-ZAN   PIC S9(11) COMP-3.    *> 24-29 (6) 確定残高
           05  MT-FILLER        PIC X(29).            *> 30-58 (29) 空白パディング
      *> (1+10+6+6+6)=29  +29 空白 = 58 byte
