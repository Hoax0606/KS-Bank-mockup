      *>****************************************************************
      *> PDBCONB.cpy  -  バッチ用 DB 接続/切断(SYSERR にログ, 失敗時停止)
      *>****************************************************************
       DB-CONNECT.
           MOVE SPACES TO DB-CONN DB-USER DB-PASS
           ACCEPT DB-CONN FROM ENVIRONMENT "ORA_CONN"
           ACCEPT DB-USER FROM ENVIRONMENT "ORA_USER"
           ACCEPT DB-PASS FROM ENVIRONMENT "ORA_PASS"
           EXEC SQL
               CONNECT TO :DB-CONN USER :DB-USER USING :DB-PASS
           END-EXEC
           IF SQLCODE NOT = 0
               DISPLAY "[YAKANBAT] DB connect failed SQLCODE=" SQLCODE
               STOP RUN
           END-IF.
       DB-DISCONNECT.
      *>   COMMIT のみ(WORK RELEASE は GixSQL/ODPI で以降の処理を止めるため回避)。
           EXEC SQL COMMIT END-EXEC.
