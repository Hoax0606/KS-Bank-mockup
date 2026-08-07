      *>****************************************************************
      *> WCGI.cpy  -  CGI 共通ワーク(要求パース + 応答バッファ)
      *>   要求: REQUEST-METHOD / QUERY_STRING / CONTENT_LENGTH / stdin body
      *>   応答: HTTP ヘッダ + JSON バディ(Shift-JIS確定、2026-08から。旧 CP930/
      *>   RAW 前提の記述は §0-§9 初期設計の名残で無効 — CGIRESP.cbl 参照)。
      *>****************************************************************
       01  CGI-ENV.
           05  CGI-METHOD       PIC X(8).             *> GET / POST
           05  CGI-QUERY        PIC X(4096).          *> QUERY_STRING
           05  CGI-CLEN         PIC 9(9)  VALUE 0.    *> CONTENT_LENGTH
           05  CGI-BODY         PIC X(8192).          *> POST body(raw)
           05  CGI-BODY-LEN     PIC 9(9)  VALUE 0.
      *>-- 抽出した 1 パラメータ ------------------------------------
       01  CGI-PARAM.
           05  CP-NAME          PIC X(32).
           05  CP-VALUE         PIC X(512).
           05  CP-FOUND         PIC X(1)  VALUE 'N'.  *> Y=見つかった
      *>-- 応答バッファ --------------------------------------------
       01  RESP.
           05  RESP-BUF         PIC X(16384) VALUE SPACES.
           05  RESP-LEN         PIC 9(9)     VALUE 0.
           05  RESP-STATUS      PIC X(3)     VALUE '200'.
      *>-- 数値編集ワーク ------------------------------------------
       01  WK-EDIT.
           05  WK-NUM11         PIC S9(11).
           05  WK-NUM11-Z       PIC -(11)9.           *> 表示編集(符号+数値)
           05  WK-NUM11-U       PIC 9(11).
           05  WK-KOUZA-Z       PIC 9(7).
