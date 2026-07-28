      *>****************************************************************
      *> PDBCON.cpy  -  DB 接続/切断の共通手続き(PERFORM で使用)
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
               MOVE '500' TO RESP-STATUS
               MOVE '{"ok":false,"error":"db_connect_failed"}'
                    TO RESP-BUF
               MOVE 40 TO RESP-LEN
               CALL "CGIRESP" USING RESP
               STOP RUN
           END-IF.
       DB-DISCONNECT.
           EXEC SQL COMMIT WORK RELEASE END-EXEC.
