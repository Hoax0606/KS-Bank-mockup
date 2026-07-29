      *> 텍스트 JEF EBCDIC 인코드/디코드 문단 (JEFCONV 브리지 경유)
       ENC-TXT.
           MOVE 'E' TO TX-JM
           CALL "JEFCONV" USING TX-JM TX-UTF8 TX-ULEN TX-HEX TX-HLEN.
       DEC-TXT.
           MOVE 'H' TO TX-JM
           CALL "JEFCONV" USING TX-JM TX-HEX TX-HLEN TX-UTF8 TX-ULEN.
