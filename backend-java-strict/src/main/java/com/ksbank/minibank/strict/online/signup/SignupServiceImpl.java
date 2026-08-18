package com.ksbank.minibank.strict.online.signup;

import java.sql.Connection;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.springframework.stereotype.Service;
import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.dao.SignupDao;
import com.ksbank.minibank.strict.online.db.Db;
import com.ksbank.minibank.strict.online.dto.SignupDto;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.Cobol;
import com.ksbank.minibank.strict.online.util.Utf2Sjis;
import com.ksbank.minibank.strict.online.util.Utf2SjisException;

@Service
public class SignupServiceImpl implements SignupService {

    private final SqlSessionFactory sqlSessionFactory;

    public SignupServiceImpl(SqlSessionFactory sqlSessionFactory) {
        this.sqlSessionFactory = sqlSessionFactory;
    }

    @Override
    public String MAIN(CgiRequest cgi) {
        SignupDto dto = new SignupDto();
        dto.setHV_KANJI(cgi.param("kanji").value());
        dto.setHV_KANA(cgi.param("kana").value());
        dto.setHV_BR(Cobol.picX(cgi.param("branch").value(), 3));
        dto.setHV_TYPE(cgi.param("type").value());
        dto.setHV_PW(cgi.param("pw").value());

        if (dto.getHV_KANJI() == null || dto.getHV_KANJI().isBlank()
                || dto.getHV_PW() == null || dto.getHV_PW().isBlank()) {
            throw CgiError.ERR_400("missing_required");
        }

        try {
            dto.setHV_KANJI(Utf2Sjis.toDbCharset(dto.getHV_KANJI()));
        } catch (Utf2SjisException e) {
            throw CgiError.ERR_400("invalid_text_encoding");
        }
        try {
            dto.setHV_KANA(Utf2Sjis.toDbCharset(dto.getHV_KANA()));
        } catch (Utf2SjisException e) {
            throw CgiError.ERR_400("invalid_text_encoding");
        }

        dto.setHV_SHU(dto.getHV_TYPE() != null && dto.getHV_TYPE().startsWith("当座") ? "2" : "1");
        dto.setHV_KAI(Cobol.CURRENT_DATE());

        Connection conn = Db.DB_CONNECT();
        try (SqlSession session = sqlSessionFactory.openSession(conn)) {
            SignupDao dao = session.getMapper(SignupDao.class);

            // KS_JAVA_START
            try {
                long result = dao.select_01(dto);
                dto.setHV_NEWNO(result);
            } catch (Exception e) {
            }
            // KS_JAVA_END

            // KS_JAVA_START
            try {
                int result = dao.insert_01(dto);
                if (result != 1) {
                    try {
                        conn.rollback();
                    } catch (Exception ignore) {
                    }
                    throw CgiError.ERR_500("signup_failed");
                }
            } catch (CgiError e) {
                throw e;
            } catch (Exception e) {
                try {
                    conn.rollback();
                } catch (Exception ignore) {
                }
                throw CgiError.ERR_500("signup_failed");
            }
            // KS_JAVA_END

            // KS_JAVA_START
            try {
                int result = dao.insert_02(dto);
                if (result != 1) {
                    try {
                        conn.rollback();
                    } catch (Exception ignore) {
                    }
                    throw CgiError.ERR_500("signup_failed");
                }
            } catch (CgiError e) {
                throw e;
            } catch (Exception e) {
                try {
                    conn.rollback();
                } catch (Exception ignore) {
                }
                throw CgiError.ERR_500("signup_failed");
            }
            // KS_JAVA_END

            try {
                conn.commit();
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        } finally {
            Db.DB_DISCONNECT(conn);
        }

        return BUILD_JSON(dto);
    }

    private String BUILD_JSON(SignupDto dto) {
        StringBuilder RESP_BUF = new StringBuilder();
        String WK_KOUZA_Z = Cobol.pic9(dto.getHV_NEWNO(), 7);
        RESP_BUF.append("{\"ok\":true,\"kouza\":\"").append(WK_KOUZA_Z)
                .append("\",\"branch\":\"").append(Cobol.TRIM(dto.getHV_BR()))
                .append("\",\"type\":\"").append(Cobol.TRIM(dto.getHV_TYPE()))
                .append("\",\"shubetsu\":\"").append(Cobol.TRIM(dto.getHV_SHU()))
                .append("\"}");
        return RESP_BUF.toString();
    }
}
