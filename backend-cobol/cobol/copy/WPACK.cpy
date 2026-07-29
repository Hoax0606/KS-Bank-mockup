      *> COMP-3(packed decimal) <-> HEX 코덱용 작업영역 (Phase2a 금액 RAW)
       01  PK-P11    PIC S9(11) COMP-3.
       01  PK-P11X   REDEFINES PK-P11 PIC X(6).
       01  PK-P5     PIC S9(5)  COMP-3.
       01  PK-P5X    REDEFINES PK-P5 PIC X(3).
       01  PK-BYTES  PIC X(6).
       01  PK-HEX    PIC X(12).
       01  PK-NB     PIC 9(2) COMP.
       01  PK-I      PIC 9(4) COMP.
       01  PK-BYV    PIC 9(5).
       01  PK-HN     PIC 9(2).
       01  PK-LN     PIC 9(2).
       01  PK-C1     PIC X.
       01  PK-V1     PIC 9(3).
       01  PK-HXT    PIC X(16) VALUE "0123456789ABCDEF".
      *> 이율(S9(3)V999=6자리→4byte)/연수(S9(3)=3자리→2byte) COMP-3 코덱
       01  PK-RATE   PIC S9(3)V999 COMP-3.
       01  PK-RATEX  REDEFINES PK-RATE PIC X(4).
       01  PK-Y      PIC S9(3) COMP-3.
       01  PK-YX     REDEFINES PK-Y PIC X(2).
      *> 존10진 EBCDIC(키) 코덱 작업영역: 각 자리 'F'+digit
       01  KY-STR    PIC X(18).
       01  KY-HEX    PIC X(36).
       01  KY-N      PIC 9(2) COMP.
       01  KY-I      PIC 9(4) COMP.
