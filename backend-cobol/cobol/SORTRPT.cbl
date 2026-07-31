      *>****************************************************************
      *> SORTRPT  -  明細ワークを名義カナ順で整列し MEISAI.RPT 出力
      *>   gixpp が SD を解析できないため SORT を本モジュールに分離。
      *>   入力 : REPORT.WORK (164byte = kana60 + seq6 + body98)
      *>   出力 : RPT_OUT(既定 ./data/MEISAI.RPT, 98byte固定, ネイティブ)
      *>   名義カナ(UTF-8バイト昇順)で整列。※旧 EBCDIC 照合は廃止。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SORTRPT.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT F-RPTW ASSIGN TO "REPORT.WORK"
               ORGANIZATION IS SEQUENTIAL FILE STATUS IS FS-RPTW.
           SELECT F-SRPT ASSIGN TO "REPORT.SORTED"
               ORGANIZATION IS SEQUENTIAL FILE STATUS IS FS-SRPT.
           SELECT SW2    ASSIGN TO "sw2.tmp".
           SELECT F-RPT  ASSIGN TO RPT-PATH
               ORGANIZATION IS SEQUENTIAL FILE STATUS IS FS-RPT.
       DATA DIVISION.
       FILE SECTION.
       FD  F-RPTW.
       01  RPTW-REC       PIC X(164).
       FD  F-SRPT.
       01  SRPT-REC.
           05  FILLER      PIC X(66).      *> kana60 + seq6
           05  SRPT-BODY   PIC X(98).      *> 明細レコード(D/T)
       SD  SW2.
       01  SW2-REC.
           05  SW2-KANA    PIC X(60).      *> 名義カナ(UTF-8)ソートキー
           05  SW2-SEQ     PIC 9(6).       *> 投入順(安定化)
           05  FILLER      PIC X(98).
       FD  F-RPT.
       01  RPT-REC        PIC X(98).
       WORKING-STORAGE SECTION.
       01  RPT-PATH       PIC X(256).
       01  FS-RPTW        PIC X(2).
       01  FS-SRPT        PIC X(2).
       01  FS-RPT         PIC X(2).
       01  EOF-RP         PIC X(1) VALUE 'N'.
       PROCEDURE DIVISION.
       MAIN.
           MOVE "./data/MEISAI.RPT" TO RPT-PATH
           ACCEPT RPT-PATH FROM ENVIRONMENT "RPT_OUT"
           SORT SW2 ON ASCENDING KEY SW2-KANA SW2-SEQ
                USING F-RPTW GIVING F-SRPT
      *>   98byte 固定で書き出し(ネイティブ)
           OPEN INPUT F-SRPT
           OPEN OUTPUT F-RPT
           MOVE 'N' TO EOF-RP
           PERFORM UNTIL EOF-RP = 'Y'
               READ F-SRPT
                   AT END MOVE 'Y' TO EOF-RP
                   NOT AT END
                       MOVE SRPT-BODY TO RPT-REC
                       WRITE RPT-REC
               END-READ
           END-PERFORM
           CLOSE F-SRPT F-RPT
           GOBACK.
       END PROGRAM SORTRPT.
