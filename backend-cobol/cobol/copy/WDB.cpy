      *>****************************************************************
      *> WDB.cpy  -  GixSQL DB 接続用ホスト変数 + SQLCA
      *>   接続情報は環境変数から取得。
      *>     ORA_CONN = oracle://oracle:1521/XEPDB1 形式
      *>     ORA_USER / ORA_PASS
      *>   ※ 2026-08부터: Instant Client를 Basic(비-Lite)으로 교체해 NLS_LANG이
      *>     실제로 적용된다. DB는 JA16SJIS 저장, NLS_LANG=JA16SJISTILDE라
      *>     일본어 열은 이제 진짜 Shift-JIS 바이트로 취득된다(과거엔 Basic Lite에
      *>     문자셋 변환 데이터가 없어 UTF-8로 강제됐었음 — 폐기된 서술).
      *>     쓰기 경로(SIGNUP/NOTICE)는 브라우저가 보내는 UTF-8을 UTF2SJIS.c로
      *>     명시적으로 변환한 뒤 바인드한다.
      *>****************************************************************
       01  DBCONN.
           05  DB-CONN   PIC X(128).
           05  DB-USER   PIC X(64).
           05  DB-PASS   PIC X(64).
       EXEC SQL INCLUDE SQLCA END-EXEC.
