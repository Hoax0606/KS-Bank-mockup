      *>****************************************************************
      *> PFMTNUM.cpy  -  S9(11) 数値 -> JSON用最小表記(符号付き, 前ゼロ無)
      *>   入力: WK-NUM11(WCGI), 出力: NUM-STR(WONLINE)
      *>****************************************************************
       FMT-NUM.
           MOVE WK-NUM11 TO WK-NUM11-Z
           MOVE FUNCTION TRIM(WK-NUM11-Z) TO NUM-STR.
