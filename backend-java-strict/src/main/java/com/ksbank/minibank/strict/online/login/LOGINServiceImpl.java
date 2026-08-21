package com.ksbank.minibank.strict.online.login;

import org.apache.ibatis.session.SqlSessionFactory;
import org.springframework.stereotype.Service;

import com.ksbank.minibank.strict.online.cgi.CGINITService;
import com.ksbank.minibank.strict.online.cgi.CGIPARMService;
import com.ksbank.minibank.strict.online.cgi.CGIRESPService;
import com.ksbank.minibank.strict.online.cgi.WCGIDto;
import com.ksbank.minibank.strict.online.dao.LOGINDao;
import com.ksbank.minibank.strict.online.db.PDBCONService;
import com.ksbank.minibank.strict.online.dto.LOGINDto;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.Cobol;
import com.ksbank.minibank.strict.online.util.NumFmt;

@Service
public class LOGINServiceImpl implements LOGINService {

    private final SqlSessionFactory sqlSessionFactory;

    public LOGINServiceImpl(SqlSessionFactory sqlSessionFactory) {
        this.sqlSessionFactory = sqlSessionFactory;
    }

    public void MAIN(LOGINDto dto) {
        CGINITService CGINITService = new CGINITService();
        WCGIDto.setCP_NAME("branch");
    
        CGIPARMService cGIPARAMService = new CGIPARMService();
        dto.setHV_BR(WCGIDto.getCP_VALUE().substring(0,3));
        WCGIDto.setCP_NAME("acct");

        CGIPARMService cGIPARMService2 = new CGIPARMService();
        dto.setHV_KOUZA(Cobol.NUMVAL(WCGIDto.getCP_VALUE()));
        WCGIDto.setCP_NAME("pw");

        CGIPARMService cGIPARMService3 = new CGIPARMService();
        dto.setHV_PW(WCGIDto.getCP_VALUE());

        if (dto.getHV_PW() == null || dto.getHV_PW().isBlank()) {
            throw CgiError.ERR_409("invalid_login");
        }
        PDBCONService.DB_CONNECT();

        long cnt = sqlSessionFactory.openSession(PDBCONService.CONN())
        .getMapper(LOGINDao.class).select_01(dto);
        dto.setHV_CNT(cnt);

        // IF HV-CNT = 0
        //     PERFORM DB-DISCONNECT
        //     MOVE "invalid_login" TO WK-ERRMSG PERFORM ERR-409
        // END-IF
        if (dto.getHV_CNT() == 0) {
            PDBCONService.DB_DISCONNECT();
            throw CgiError.ERR_409("invalid_login");
        }

        // EXEC SQL SELECT K.MEIGI_KANJI, K.SHUBETSU, K.ZANDAKA, K.JOUTAI, X.ACCT_TYPE
        //     INTO :HV-KANJI, :HV-SHU, :HV-ZAN, :HV-JOU, :HV-TYPE
        //     FROM KOUZA K, KOUZA_EXT X WHERE ... END-EXEC
        LOGINDto row = sqlSessionFactory.openSession(PDBCONService.CONN())
            .getMapper(LOGINDao.class).select_02(dto);
        dto.setHV_KANJI(row.getHV_KANJI());
        dto.setHV_SHU(row.getHV_SHU());
        dto.setHV_ZAN(row.getHV_ZAN());
        dto.setHV_JOU(row.getHV_JOU());
        dto.setHV_TYPE(row.getHV_TYPE());

        // PERFORM DB-DISCONNECT
        PDBCONService.DB_DISCONNECT();
        // PERFORM BUILD-JSON
        BUILD_JSON(dto);
        // CALL "CGIRESP" USING RESP
        CGIRESPService cGIRESPService = new CGIRESPService(dto.getRESP_BUF().toString());
        // STOP RUN
        return;
    }

    // BUILD-JSON.
    private void BUILD_JSON(LOGINDto dto) {
        // MOVE 1 TO RESP-PTR
        dto.setRESP_PTR(1);
        // MOVE SPACES TO RESP-BUF
        dto.setRESP_BUF(new StringBuilder());
        // MOVE HV-KOUZA TO WK-KOUZA-Z
        dto.setWK_KOUZA_Z(String.format("%07d", dto.getHV_KOUZA()));
        // STRING '{"ok":true,"kouza":"' WK-KOUZA-Z '","branch":"' FUNCTION TRIM(HV-BR)
        //        '","meigiKanji":"' FUNCTION TRIM(HV-KANJI) '","shubetsu":"' HV-SHU
        //        '","type":"' FUNCTION TRIM(HV-TYPE) '","joutai":"' HV-JOU '","zandaka":'
        //        DELIMITED SIZE INTO RESP-BUF WITH POINTER RESP-PTR
        dto.getRESP_BUF().append("{\"ok\":true,\"kouza\":\"");
        dto.getRESP_BUF().append(dto.getWK_KOUZA_Z());
        dto.getRESP_BUF().append("\",\"branch\":\"");
        dto.getRESP_BUF().append(Cobol.TRIM(dto.getHV_BR()));
        dto.getRESP_BUF().append("\",\"meigiKanji\":\"");
        dto.getRESP_BUF().append(Cobol.TRIM(dto.getHV_KANJI()));
        dto.getRESP_BUF().append("\",\"shubetsu\":\"");
        dto.getRESP_BUF().append(dto.getHV_SHU());
        dto.getRESP_BUF().append("\",\"type\":\"");
        dto.getRESP_BUF().append(Cobol.TRIM(dto.getHV_TYPE()));
        dto.getRESP_BUF().append("\",\"joutai\":\"");
        dto.getRESP_BUF().append(dto.getHV_JOU());
        dto.getRESP_BUF().append("\",\"zandaka\":");
        dto.setRESP_PTR(dto.getRESP_BUF().length() + 1);
        // MOVE HV-ZAN TO WK-NUM11
        // PERFORM FMT-NUM
        // STRING FUNCTION TRIM(NUM-STR) '}' DELIMITED SIZE INTO RESP-BUF WITH POINTER RESP-PTR
        dto.getRESP_BUF().append(NumFmt.trim(dto.getHV_ZAN()));
        dto.getRESP_BUF().append('}');
        dto.setRESP_PTR(dto.getRESP_BUF().length() + 1);
        // SUBTRACT 1 FROM RESP-PTR GIVING RESP-LEN
        dto.setRESP_LEN(dto.getRESP_PTR() - 1);
    }
}
