      *>****************************************************************
      *> CGIRESP  -  HTTP ヘッダ + JSON バディ(UTF-8確定)を stdout へ出力。
      *>   ※ 1ファイル=1プログラム(動的 CALL 解決のため)。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CGIRESP.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       LINKAGE SECTION.
       COPY WCGI.
       PROCEDURE DIVISION USING RESP.
       RESP-MAIN.
      *>   CGI ヘッダ + 空行(LF のみ)+ ボディ。DISPLAY の自動改行や
      *>   " " による空白混入を避け、X"0A" で厳密に組み立てる。
      *>   (空行に空白が入ると nginx が invalid header で 502 になる)
           DISPLAY "Status: " RESP-STATUS X"0A"
                   "Content-Type: application/json; charset=UTF-8" X"0A"
                   "Cache-Control: no-store" X"0A"
                   X"0A"
               WITH NO ADVANCING
           IF RESP-LEN > 0
               DISPLAY RESP-BUF(1:RESP-LEN) WITH NO ADVANCING
           ELSE
               DISPLAY "{}" WITH NO ADVANCING
           END-IF
           GOBACK.
       END PROGRAM CGIRESP.
