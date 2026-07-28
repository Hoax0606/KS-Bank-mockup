      *>****************************************************************
      *> WDB.cpy  -  GixSQL DB 接続用ホスト変数 + SQLCA
      *>   接続情報は環境変数から取得(Docker/NLS_LANG と併せる)。
      *>     ORA_CONN = //oracle:1521/FREEPDB1 形式
      *>     ORA_USER / ORA_PASS
      *>   ※ NLS_LANG は .._.AL32UTF8 ではなく RAW無変換通過が要点(§2)。
      *>     日本語列は RAW のため文字集合変換を受けない。
      *>****************************************************************
       01  DBCONN.
           05  DB-CONN   PIC X(128).
           05  DB-USER   PIC X(64).
           05  DB-PASS   PIC X(64).
       EXEC SQL INCLUDE SQLCA END-EXEC.
