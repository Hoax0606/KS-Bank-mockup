package com.ksbank.minibank.strict.online.login;

import java.sql.Connection;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.springframework.stereotype.Service;
import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.dao.LoginDao;
import com.ksbank.minibank.strict.online.db.Db;
import com.ksbank.minibank.strict.online.dto.LoginDto;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.Cobol;
import com.ksbank.minibank.strict.online.util.NumFmt;

@Service
public class LoginServiceImpl implements LoginService {

    private final SqlSessionFactory sqlSessionFactory;

    public LoginServiceImpl(SqlSessionFactory sqlSessionFactory) {
        this.sqlSessionFactory = sqlSessionFactory;
    }

    @Override
    public String MAIN(CgiRequest cgi) {
        LoginDto dto = new LoginDto();
        dto.setHV_BR(Cobol.picX(cgi.param("branch").value(), 3));
        dto.setHV_KOUZA(Cobol.truncate(Cobol.NUMVAL(cgi.param("acct").value()), 7));
        dto.setHV_PW(cgi.param("pw").value());

        if (dto.getHV_PW() == null || dto.getHV_PW().isBlank()) {
            throw CgiError.ERR_409("invalid_login");
        }

        Connection conn = Db.DB_CONNECT();
        try (SqlSession session = sqlSessionFactory.openSession(conn)) {
            LoginDao dao = session.getMapper(LoginDao.class);

            // KS_JAVA_START
            try {
                long result = dao.select_01(dto);
                dto.setHV_CNT(result);
            } catch (Exception e) {
            }
            // KS_JAVA_END

            if (dto.getHV_CNT() == 0) {
                throw CgiError.ERR_409("invalid_login");
            }

            // KS_JAVA_START
            try {
                LoginDto result = dao.select_02(dto);

                if (result != null) {
                    dto.setHV_KANJI(result.getHV_KANJI());
                    dto.setHV_SHU(result.getHV_SHU());
                    dto.setHV_ZAN(result.getHV_ZAN());
                    dto.setHV_JOU(result.getHV_JOU());
                    dto.setHV_TYPE(result.getHV_TYPE());
                }
            } catch (Exception e) {
            }
            // KS_JAVA_END
        } finally {
            Db.DB_DISCONNECT(conn);
        }

        return BUILD_JSON(dto);
    }

    private String BUILD_JSON(LoginDto dto) {
        StringBuilder RESP_BUF = new StringBuilder();
        String WK_KOUZA_Z = Cobol.pic9(dto.getHV_KOUZA(), 7);
        RESP_BUF.append("{\"ok\":true,\"kouza\":\"").append(WK_KOUZA_Z)
                .append("\",\"branch\":\"").append(Cobol.TRIM(dto.getHV_BR()))
                .append("\",\"meigiKanji\":\"").append(Cobol.TRIM(dto.getHV_KANJI()))
                .append("\",\"shubetsu\":\"").append(Cobol.TRIM(dto.getHV_SHU()))
                .append("\",\"type\":\"").append(Cobol.TRIM(dto.getHV_TYPE()))
                .append("\",\"joutai\":\"").append(Cobol.TRIM(dto.getHV_JOU()))
                .append("\",\"zandaka\":");
        RESP_BUF.append(NumFmt.trim(dto.getHV_ZAN())).append("}");
        return RESP_BUF.toString();
    }
}
