      *>****************************************************************
      *> WONLINE.cpy  -  オンライン CGI 共通ワーク
      *>****************************************************************
       01  RESP-PTR    PIC 9(9) COMP VALUE 1.
       01  NUM-STR     PIC X(13) VALUE SPACES.
       01  UT-RAW      PIC X(256).
       01  UT-RAWLEN   PIC 9(4)  VALUE 0.
       01  UT-MIRROR   PIC X(256).
       01  UT-OUT      PIC X(1024).
       01  UT-OUTLEN   PIC 9(4)  VALUE 0.
       01  WK-ERRMSG   PIC X(256) VALUE SPACES.
