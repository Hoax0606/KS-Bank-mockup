      *>****************************************************************
      *> KKOUZA.cpy  -  口座マスタ KOUZA レコード定義 (設計書 §3.1)
      *>   ASIS = EBCDIC(CP930)。名義漢字/カナは RAW を無変換で保持。
      *>   金額は COMP-3。Oracle NUMBER <-> COMP-3, RAW <-> X(n) 無変換通過。
      *>   ※ このレコードは EXEC SQL のホスト変数としても使う(無変換)。
      *>****************************************************************
       01  KOUZA-REC.
           05  KZ-KOUZA-NO      PIC 9(7).            *> NUMBER(7) PK
           05  KZ-MEIGI-KANJI   PIC X(20).            *> RAW(20) SO/SI 込 20byte
           05  KZ-MEIGI-KANA    PIC X(20).            *> RAW(20) ソートキー
           05  KZ-SHUBETSU      PIC X(01).            *> 1=普通 2=当座
           05  KZ-ZANDAKA       PIC S9(11) COMP-3.    *> 6byte
           05  KZ-KAISETSU-BI   PIC 9(08).            *> YYYYMMDD
           05  KZ-JOUTAI        PIC X(01).            *> 0=正常 9=凍結
      *> レコード長 = 7+20+20+1+6+8+1 = 63 byte
