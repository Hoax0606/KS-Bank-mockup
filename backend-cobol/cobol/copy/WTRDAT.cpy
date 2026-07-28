      *>****************************************************************
      *> WTRDAT.cpy  -  当日取引 入力ファイル TORIHIKI.DAT レコード (§4.1)
      *>   固定長 97 byte / EBCDIC(CP930)。COMP-3 byte = floor(桁/2)+1。
      *>   TR-EXT は 種別で再定義(REDEFINES=結定打):
      *>     入金/出金 => 未使用(空白)。振込 => 相手口座+手数料 に再解釈。
      *>****************************************************************
       01  TR-DAT-REC.
           05  TD-ID            PIC 9(12).            *> 1-12   (12)
           05  TD-KOUZA-NO      PIC 9(10).            *> 13-22  (10)
           05  TD-NICHIJI       PIC X(14).            *> 23-36  (14) YYYYMMDDHHMMSS
           05  TD-KBN           PIC X(01).            *> 37     (1) 1=入金 2=出金 3=振込
           05  TD-KINGAKU       PIC S9(11) COMP-3.    *> 38-43  (6)
           05  TD-EXT           PIC X(14).            *> 44-57  (14) 種別別 再定義領域
           05  TD-EXT-FURIKOMI  REDEFINES TD-EXT.     *> ---- REDEFINES(結定打) ----
              10 TD-AITE-KOUZA  PIC 9(10).            *> 44-53  (10)
              10 TD-TESURYO     PIC S9(05) COMP-3.    *> 54-56  (3)
              10 FILLER         PIC X(01).            *> 57     (1)
           05  TD-TEKIYOU       PIC X(40).            *> 58-97  (40) 漢字・カナ混在
      *> レコード長 = 12+10+14+1+6+14+40 = 97 byte
