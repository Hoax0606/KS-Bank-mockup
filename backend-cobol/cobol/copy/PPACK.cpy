      *> COMP-3 packed <-> HEX (PK-NB bytes, PK-BYTES <-> PK-HEX)
       BYTES-TO-HEX.
           MOVE SPACES TO PK-HEX
           PERFORM VARYING PK-I FROM 1 BY 1 UNTIL PK-I > PK-NB
             COMPUTE PK-BYV = FUNCTION ORD(PK-BYTES(PK-I:1)) - 1
             DIVIDE PK-BYV BY 16 GIVING PK-HN REMAINDER PK-LN
             MOVE PK-HXT(PK-HN + 1:1) TO PK-HEX(2 * PK-I - 1:1)
             MOVE PK-HXT(PK-LN + 1:1) TO PK-HEX(2 * PK-I:1)
           END-PERFORM.
       HEX-TO-BYTES.
           MOVE SPACES TO PK-BYTES
           PERFORM VARYING PK-I FROM 1 BY 1 UNTIL PK-I > PK-NB
             MOVE PK-HEX(2 * PK-I - 1:1) TO PK-C1
             PERFORM PK-NIB
             MOVE PK-V1 TO PK-HN
             MOVE PK-HEX(2 * PK-I:1) TO PK-C1
             PERFORM PK-NIB
             MOVE PK-V1 TO PK-LN
             COMPUTE PK-BYV = PK-HN * 16 + PK-LN
             MOVE FUNCTION CHAR(PK-BYV + 1) TO PK-BYTES(PK-I:1)
           END-PERFORM.
       PK-NIB.
           COMPUTE PK-V1 = FUNCTION ORD(PK-C1) - 1
           IF PK-V1 >= 65
               SUBTRACT 55 FROM PK-V1
           ELSE
               SUBTRACT 48 FROM PK-V1
           END-IF.
       ENC-P11.
           MOVE PK-P11X TO PK-BYTES
           MOVE 6 TO PK-NB
           PERFORM BYTES-TO-HEX.
       DEC-P11.
           MOVE 6 TO PK-NB
           PERFORM HEX-TO-BYTES
           MOVE PK-BYTES TO PK-P11X.
       ENC-P5.
           MOVE PK-P5X TO PK-BYTES(1:3)
           MOVE 3 TO PK-NB
           PERFORM BYTES-TO-HEX.
       DEC-P5.
           MOVE 3 TO PK-NB
           PERFORM HEX-TO-BYTES
           MOVE PK-BYTES(1:3) TO PK-P5X.
      *> 이율 S9(3)V999 (4byte=8hex) <-> PK-RATE
       ENC-RATE.
           MOVE PK-RATEX TO PK-BYTES(1:4)
           MOVE 4 TO PK-NB
           PERFORM BYTES-TO-HEX.
       DEC-RATE.
           MOVE 4 TO PK-NB
           PERFORM HEX-TO-BYTES
           MOVE PK-BYTES(1:4) TO PK-RATEX.
      *> 연수 S9(3) (2byte=4hex) <-> PK-Y
       ENC-Y.
           MOVE PK-YX TO PK-BYTES(1:2)
           MOVE 2 TO PK-NB
           PERFORM BYTES-TO-HEX.
       DEC-Y.
           MOVE 2 TO PK-NB
           PERFORM HEX-TO-BYTES
           MOVE PK-BYTES(1:2) TO PK-YX.
      *> 키 값(ASCII digits, KY-STR) <-> 존10진 EBCDIC hex(KY-HEX), KY-N자리
       ENC-KEY.
           MOVE SPACES TO KY-HEX
           PERFORM VARYING KY-I FROM 1 BY 1 UNTIL KY-I > KY-N
             MOVE 'F' TO KY-HEX(2 * KY-I - 1:1)
             MOVE KY-STR(KY-I:1) TO KY-HEX(2 * KY-I:1)
           END-PERFORM.
       DEC-KEY.
           MOVE SPACES TO KY-STR
           PERFORM VARYING KY-I FROM 1 BY 1 UNTIL KY-I > KY-N
             MOVE KY-HEX(2 * KY-I:1) TO KY-STR(KY-I:1)
           END-PERFORM.
