package com.ksbank.minibank.strict.online.notice;

import java.util.Iterator;
import org.apache.ibatis.cursor.Cursor;
import org.apache.ibatis.session.SqlSessionFactory;
import org.springframework.stereotype.Service;
import com.ksbank.minibank.strict.online.cgi.CGINITService;
import com.ksbank.minibank.strict.online.cgi.CGIPARMService;
import com.ksbank.minibank.strict.online.cgi.CGIRESPService;
import com.ksbank.minibank.strict.online.cgi.WCGIDto;
import com.ksbank.minibank.strict.online.dao.NOTICEDao;
import com.ksbank.minibank.strict.online.db.PDBCONService;
import com.ksbank.minibank.strict.online.dto.CNOTICEDto;
import com.ksbank.minibank.strict.online.dto.NOTICEDto;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.Cobol;
import com.ksbank.minibank.strict.online.util.NumFmt;
import com.ksbank.minibank.strict.online.util.Utf2SjisException;
import com.ksbank.minibank.strict.online.util.Utf2Sjis;

@Service
public class NOTICEServiceImpl implements NOTICEService {

    private final SqlSessionFactory sqlSessionFactory;

    public NOTICEServiceImpl(SqlSessionFactory sqlSessionFactory) {
        this.sqlSessionFactory = sqlSessionFactory;
    }

    public void MAIN(NOTICEDto dto) {
        CGINITService cGINITService = new CGINITService();

        PDBCONService.DB_CONNECT();           // copy 북이라면 이런식으로 할거다 라는 규칙을 미리 세워놓으면 다음번에도 copy 이 나온다면 이런형식으로 하면될것

        if ("POST".equals(WCGIDto.getCGI_METHOD())) {
            DO_CREATE(dto);             // dto 로 받는것이라면 dto 로 받는다는걸 표시를 해두는것임
        } else {
            DO_LIST(dto);
        }

        PDBCONService.DB_DISCONNECT();        // CONNECT 도 있고 , DISCONNECT 도 있으니

        CGIRESPService cGIRESPService = new CGIRESPService(dto.getRESP_BUF().toString());

        // System.exit(0);
        return;
    }

    // DO-LIST.
    private void DO_LIST(NOTICEDto dto) {
        // MOVE 1 TO RESP-PTR MOVE SPACES TO RESP-BUF
        dto.setRESP_PTR(1);
        dto.setRESP_BUF(new StringBuilder());
        // STRING '{"ok":true,"notices":[' DELIMITED SIZE
        //        INTO RESP-BUF WITH POINTER RESP-PTR
        dto.getRESP_BUF().append("{\"ok\":true,\"notices\":[");
        dto.setRESP_PTR(dto.getRESP_BUF().length() + 1);
        dto.setFIRST_ROW("Y");
        
        Cursor<CNOTICEDto> C_NOTICE = sqlSessionFactory.openSession(PDBCONService.CONN())
            .getMapper(NOTICEDao.class).select_01(dto);  //EXEC SQL OPEN C-NOTICE ENDEXEC
            
        Iterator<CNOTICEDto> it = C_NOTICE.iterator();
        int SQLCODE = 0;

        while (SQLCODE ==0) {
            if (it.hasNext()) {
                CNOTICEDto row = it.next();
                dto.setC_DATE(row.getC_DATE());
                dto.setC_TAG(row.getC_TAG());
                dto.setC_TITLE(row.getC_TITLE());
                SQLCODE = 0;
            } else {
                SQLCODE = 100;
            }
            if (SQLCODE == 0) {
                EMIT_NOTICE(dto);
            }
        }
        // EXEC SQL CLOSE C-NOTICE END-EXEC
        try {
            C_NOTICE.close();
        } catch(java.io.IOException e)  {
        }
        dto.getRESP_BUF().append("]}");
        dto.setRESP_PTR(dto.getRESP_BUF().length() + 1);
        dto.setRESP_LEN(dto.getRESP_PTR() - 1);

    }
    // EMIT-NOTICE.
    private void EMIT_NOTICE(NOTICEDto dto) {

        if ("Y".equals(dto.getFIRST_ROW())) {
            dto.setFIRST_ROW("N");            
        }else{
            dto.getRESP_BUF().append(',');
            dto.setRESP_PTR(dto.getRESP_BUF().length() +1);
        }

        dto.getRESP_BUF().append("{\"date\":\"");
        dto.getRESP_BUF().append(dto.getC_DATE(),0,4);
        dto.getRESP_BUF().append('/');
        dto.getRESP_BUF().append(dto.getC_DATE(),4,6);
        dto.getRESP_BUF().append('/');
        dto.getRESP_BUF().append(dto.getC_DATE(),6,8);
        dto.getRESP_BUF().append("\",\"tag\":\"");
        dto.getRESP_BUF().append(Cobol.TRIM(dto.getC_TAG()));
        dto.getRESP_BUF().append("\",\"title\":\"");
        dto.getRESP_BUF().append(Cobol.TRIM(dto.getC_TITLE()));
        dto.getRESP_BUF().append("\"}");
        dto.setRESP_PTR(dto.getRESP_BUF().length() + 1 );
    }
    public void DO_CREATE(NOTICEDto dto) {
        WCGIDto.setCP_NAME("title");
        CGIPARMService cGIPARAMService = new CGIPARMService();
        dto.setWK_TITLE(WCGIDto.getCP_VALUE());
        
        if (dto.getWK_TITLE().isBlank()) {
            throw CgiError.ERR_400("missing_title");
        }
        
        dto.setHV_TITLE(dto.getWK_TITLE());
        WCGIDto.setCP_NAME("body");
        CGIPARMService cGIPARMService = new CGIPARMService();

        dto.setWK_BODY(WCGIDto.getCP_VALUE());
        dto.setHV_BODY(dto.getWK_BODY());
        WCGIDto.setCP_NAME("tag");
        CGIPARMService cGIPARMService2 = new CGIPARMService();

        if("Y".equals(WCGIDto.getCP_FOUND())) {
            dto.setWK_TAG(WCGIDto.getCP_VALUE());
        } else {
            dto.setWK_TAG("新着");
        }
        dto.setHV_TAG(dto.getWK_TAG());
        // MOVE FUNCTION CURRENT-DATE(1:8) TO WK-DATE
        dto.setWK_DATE(Cobol.CURRENT_DATE());
        // MOVE WK-DATE TO HV-DATE
        dto.setHV_DATE(dto.getWK_DATE());

        dto.setUC_OUT("");
        dto.setUC_INLEN(600);
        dto.setUC_OUTLEN(600);

        try {
            dto.setUC_OUT(Utf2Sjis.toDbCharset(dto.getHV_TITLE()));
        } catch(Utf2SjisException e){
            throw CgiError.ERR_400("invalid_text_encoding");
        }
        // MOVE UC-OUT TO HV-TITLE
        dto.setHV_TITLE(dto.getUC_OUT());

        dto.setUC_OUT("");
        dto.setUC_INLEN(2000);
        dto.setUC_OUTLEN(2000);

        try {
            dto.setUC_OUT(Utf2Sjis.toDbCharset(dto.getHV_BODY()));
        } catch(Utf2SjisException e){
            throw CgiError.ERR_400("invalid_text_encoding");
        }
        // MOVE UC-OUT TO HV-BODY
        dto.setHV_BODY(dto.getUC_OUT());

        // MOVE SPACES TO UC-OUT MOVE 30 TO UC-INLEN UC-OUTLEN
        dto.setUC_OUT("");
        dto.setUC_INLEN(30);
        dto.setUC_OUTLEN(30);
        // CALL "UTF2SJIS" USING HV-TAG UC-INLEN UC-OUT UC-OUTLEN
        // IF RETURN-CODE NOT = 0
        //     MOVE "invalid_text_encoding" TO WK-ERRMSG PERFORM ERR-400
        // END-IF
        try {
            dto.setUC_OUT(Utf2Sjis.toDbCharset(dto.getHV_TAG()));
        } catch (Utf2SjisException e) {
            throw CgiError.ERR_400("invalid_text_encoding");
        }
        // MOVE UC-OUT TO HV-TAG
        dto.setHV_TAG(dto.getUC_OUT());

        NOTICEDao dao = sqlSessionFactory.openSession(PDBCONService.CONN()).getMapper(NOTICEDao.class);

        // EXEC SQL SELECT SEQ_NOTICE_ASIS.NEXTVAL INTO :HV-NID FROM DUAL END-EXEC
        // — 공지 ID 채번(실패해도 SQLCODE 체크 안 함, COBOL 원본과 동일)
        try {
            long result = dao.select_02(dto);
            dto.setHV_NID(result);
        } catch (Exception e) {
        }

        // IF WK-BODY = SPACES EXEC SQL INSERT ... NULL ... END-EXEC
        // ELSE EXEC SQL INSERT ... RTRIM(:HV-BODY) ... END-EXEC END-IF
        // IF SQLCODE NOT = 0 EXEC SQL ROLLBACK END-EXEC PERFORM DB-DISCONNECT
        //     MOVE "notice_failed" TO WK-ERRMSG PERFORM ERR-500 END-IF
        try {
            if (dto.getWK_BODY() == null || dto.getWK_BODY().isBlank()) {
                dao.insert_01(dto);
            } else {
                dao.insert_02(dto);
            }
        } catch (Exception e) {
            try {
                PDBCONService.CONN().rollback();
            } catch (Exception ignore) {
            }
            PDBCONService.DB_DISCONNECT();
            throw CgiError.ERR_500("notice_failed");
        }

        // EXEC SQL COMMIT END-EXEC
        try {
            PDBCONService.CONN().commit();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }

        // MOVE 1 TO RESP-PTR MOVE SPACES TO RESP-BUF
        dto.setRESP_PTR(1);
        dto.setRESP_BUF(new StringBuilder());
        // MOVE HV-NID TO WK-NUM11 PERFORM FMT-NUM
        // STRING '{"ok":true,"noticeId":' FUNCTION TRIM(NUM-STR) '}' DELIMITED SIZE
        //        INTO RESP-BUF WITH POINTER RESP-PTR
        dto.getRESP_BUF().append("{\"ok\":true,\"noticeId\":");
        dto.getRESP_BUF().append(NumFmt.trim(dto.getHV_NID()));
        dto.getRESP_BUF().append('}');
        dto.setRESP_PTR(dto.getRESP_BUF().length() + 1);
        // SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN
        dto.setRESP_LEN(dto.getRESP_PTR() - 1);
    }
}
