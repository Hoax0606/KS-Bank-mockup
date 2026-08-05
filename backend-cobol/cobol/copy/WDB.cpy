      *>****************************************************************
      *> WDB.cpy  -  GixSQL DB 接続用ホスト変数 + SQLCA
      *>   接続情報は環境変数から取得。
      *>     ORA_CONN = oracle://oracle:1521/XEPDB1 形式
      *>     ORA_USER / ORA_PASS
      *>   ※ DB는 JA16SJIS 저장이나 GixSQL 드라이버가 UTF-8로 강제 변환하여
      *>     일본어 열은 UTF-8 바이트로 취득된다(NLS_LANG 무시).
      *>****************************************************************
       01  DBCONN.
           05  DB-CONN   PIC X(128).
           05  DB-USER   PIC X(64).
           05  DB-PASS   PIC X(64).
       EXEC SQL INCLUDE SQLCA END-EXEC.
