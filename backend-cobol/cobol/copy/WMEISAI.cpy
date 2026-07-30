      *>****************************************************************
      *> WMEISAI.cpy  -  明細レポート出力 MEISAI.RPT レコード (§4.2)
      *>   全レコード 98 byte 固定。ネイティブ(ASCII数字 + COMP-3 + UTF-8)。
      *>   ※ 旧 EBCDIC/JEF 廃止。名義は UTF-8 のため 20桁想定で X(60)確保。
      *>   D=明細行, T=口座合計。先頭 1byte のレコード区分で判別。
      *>   両者を同一 98byte 枠で扱う。
      *>****************************************************************
       01  MEISAI-REC.
           05  MR-KUBUN         PIC X(01).            *> 'D' or 'T'
           05  MR-BODY          PIC X(97).
      *>-- D レコード(明細, 98 byte) --------------------------------
       01  MEISAI-D.
           05  MD-KUBUN         PIC X(01).            *> 1  'D'
           05  MD-KOUZA-NO      PIC 9(10).            *> 2-11  (10)
           05  MD-MEIGI-KANJI   PIC X(60).            *> 12-71 (60) UTF-8
           05  MD-TORIHIKI-DT   PIC X(14).            *> 72-85 (14)
           05  MD-KBN           PIC X(01).            *> 86    (1)
           05  MD-KINGAKU       PIC S9(11) COMP-3.    *> 87-92 (6)
           05  MD-ZANDAKA-GO    PIC S9(11) COMP-3.    *> 93-98 (6) 取引後残高
      *> 1+10+60+14+1+6+6 = 98 byte
      *>-- T レコード(口座合計, 実内容29byte + 空白69byte = 98 byte) -
       01  MEISAI-T.
           05  MT-KUBUN         PIC X(01).            *> 1  'T'
           05  MT-KOUZA-NO      PIC 9(10).            *> 2-11  (10)
           05  MT-RISOKU        PIC S9(11) COMP-3.    *> 12-17 (6) 利息
           05  MT-TESURYO-GK    PIC S9(11) COMP-3.    *> 18-23 (6) 手数料合計
           05  MT-KAKUTEI-ZAN   PIC S9(11) COMP-3.    *> 24-29 (6) 確定残高
           05  MT-FILLER        PIC X(69).            *> 30-98 (69) 空白
      *> (1+10+6+6+6)=29  +69 空白 = 98 byte
