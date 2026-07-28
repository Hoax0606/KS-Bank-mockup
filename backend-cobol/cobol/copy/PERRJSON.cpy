      *>****************************************************************
      *> PERRJSON.cpy  -  エラー応答(JSON)共通手続き
      *>   WK-ERRMSG にエラーキーを入れて ERR-xxx を PERFORM。
      *>   {"ok":false,"error":"..."} を出力し STOP RUN。
      *>****************************************************************
       ERR-400.
           MOVE '400' TO RESP-STATUS
           PERFORM ERR-EMIT.
       ERR-404.
           MOVE '404' TO RESP-STATUS
           PERFORM ERR-EMIT.
       ERR-409.
           MOVE '409' TO RESP-STATUS
           PERFORM ERR-EMIT.
       ERR-500.
           MOVE '500' TO RESP-STATUS
           PERFORM ERR-EMIT.
       ERR-EMIT.
           MOVE SPACES TO RESP-BUF
           MOVE 1 TO RESP-PTR
           STRING '{"ok":false,"error":"' DELIMITED SIZE
                  FUNCTION TRIM(WK-ERRMSG) DELIMITED SIZE
                  '"}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN
           CALL "CGIRESP" USING RESP
           STOP RUN.
