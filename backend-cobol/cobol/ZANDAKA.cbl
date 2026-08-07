      *>****************************************************************
      *> ZANDAKA  -  残高照会 CGI (通常型/Shift-JIS DB版)
      *>   GET/POST: kouza=NNNNNNN。名義/種別/状態を通常列から直接取得。
      *>   日本語列は Shift-JIS バイトで PIC X に入り、そのまま JSON へ出力。
      *>****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ZANDAKA.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY WCGI.
       COPY WONLINE.
       COPY WDB.
       01  WK-FOUND    PIC X(1) VALUE 'N'.
       EXEC SQL BEGIN DECLARE SECTION END-EXEC.
       01  HV-KOUZA    PIC 9(7).
       01  HV-KANJI    PIC X(40).
       01  HV-KANA     PIC X(40).
       01  HV-SHU      PIC X(1).
       01  HV-ZAN      PIC S9(11).
       01  HV-JOU      PIC X(1).
       EXEC SQL END DECLARE SECTION END-EXEC.
       PROCEDURE DIVISION.
       MAIN.
           CALL "CGIINIT" USING CGI-ENV
           MOVE "kouza" TO CP-NAME
           CALL "CGIPARM" USING CGI-ENV CGI-PARAM
           IF CP-FOUND NOT = 'Y'
               MOVE "missing_kouza" TO WK-ERRMSG
               PERFORM ERR-400
           END-IF
           MOVE FUNCTION NUMVAL(CP-VALUE) TO HV-KOUZA
           PERFORM DB-CONNECT
           EXEC SQL
               SELECT MEIGI_KANJI, MEIGI_KANA, SHUBETSU,
                      ZANDAKA, JOUTAI
                 INTO :HV-KANJI, :HV-KANA, :HV-SHU,
                      :HV-ZAN, :HV-JOU
                 FROM KOUZA
                WHERE KOUZA_NO = :HV-KOUZA
           END-EXEC
           IF SQLCODE = 0
               MOVE 'Y' TO WK-FOUND
           END-IF
           PERFORM DB-DISCONNECT
           IF WK-FOUND NOT = 'Y'
               MOVE "kouza_not_found" TO WK-ERRMSG
               PERFORM ERR-404
           END-IF
           PERFORM BUILD-JSON
           CALL "CGIRESP" USING RESP
           STOP RUN.
      *>-------------------------------------------------------------
       BUILD-JSON.
           MOVE 1 TO RESP-PTR
           MOVE SPACES TO RESP-BUF
           MOVE HV-KOUZA TO WK-KOUZA-Z
           STRING '{"ok":true,"kouza":"' DELIMITED SIZE
                  WK-KOUZA-Z DELIMITED SIZE
                  '","meigiKanji":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-KANJI) DELIMITED SIZE
                  '","meigiKana":"' DELIMITED SIZE
                  FUNCTION TRIM(HV-KANA) DELIMITED SIZE
                  '","shubetsu":"' DELIMITED SIZE
                  HV-SHU DELIMITED SIZE
                  '","zandaka":' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           MOVE HV-ZAN TO WK-NUM11
           PERFORM FMT-NUM
           STRING FUNCTION TRIM(NUM-STR) DELIMITED SIZE
                  ',"joutai":"' DELIMITED SIZE
                  HV-JOU DELIMITED SIZE
                  '"}' DELIMITED SIZE
                  INTO RESP-BUF WITH POINTER RESP-PTR
           SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN.
       COPY PFMTNUM.
       COPY PDBCON.
       COPY PERRJSON.
       END PROGRAM ZANDAKA.
