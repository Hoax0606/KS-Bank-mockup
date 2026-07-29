      *> 범용 텍스트 JEF EBCDIC 코덱 작업영역 (UI=UTF-8 / DB=RAW)
      *>   ENC-TXT: TX-UTF8(1:TX-ULEN) -> JEF hex (TX-HEX/TX-HLEN)  HEXTORAW용
      *>   DEC-TXT: TX-HEX(1:TX-HLEN)=RAWTOHEX결과 -> UTF-8(TX-UTF8/TX-ULEN)
       01  TX-UTF8   PIC X(2048).
       01  TX-HEX    PIC X(4096).
       01  TX-ULEN   PIC 9(4).
       01  TX-HLEN   PIC 9(4).
       01  TX-JM     PIC X.
