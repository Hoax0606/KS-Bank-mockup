      *>****************************************************************
      *> KTORIHK.cpy  -  取引ジャーナル TORIHIKI レコード定義 (設計書 §3.2)
      *>   相手口座/手数料は振込(区分=3)のときのみ充填。
      *>   摘要(TEKIYOU)は RAW(40) 漢字・カナ混在, SO/SI, gaiji/波ダッシュ。
      *>****************************************************************
       01  TORIHIKI-REC.
           05  TR-TORIHIKI-ID   PIC 9(12).            *> NUMBER(12) PK
           05  TR-KOUZA-NO      PIC 9(7).            *> FK KOUZA
           05  TR-TORIHIKI-DT   PIC X(14).            *> YYYYMMDDHHMMSS
           05  TR-TORIHIKI-KBN  PIC X(01).            *> 1=入金 2=出金 3=振込
           05  TR-KINGAKU       PIC S9(11) COMP-3.    *> 6byte
           05  TR-AITE-KOUZA    PIC 9(7).            *> 振込のみ
           05  TR-TESURYO       PIC S9(05) COMP-3.    *> 3byte 振込のみ
           05  TR-TEKIYOU       PIC X(40).            *> RAW(40) EBCDIC
