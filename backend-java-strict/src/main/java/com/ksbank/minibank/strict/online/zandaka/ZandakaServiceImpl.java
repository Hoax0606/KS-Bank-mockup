package com.ksbank.minibank.strict.online.zandaka;

import java.sql.Connection;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.springframework.stereotype.Service;
import com.ksbank.minibank.strict.online.cgi.CgiParam;
import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.dao.ZandakaDao;
import com.ksbank.minibank.strict.online.db.Db;
import com.ksbank.minibank.strict.online.dto.ZandakaDto;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.Cobol;
import com.ksbank.minibank.strict.online.util.NumFmt;

@Service
public class ZandakaServiceImpl implements ZandakaService {

    private final SqlSessionFactory sqlSessionFactory;

    public ZandakaServiceImpl(SqlSessionFactory sqlSessionFactory) {
        this.sqlSessionFactory = sqlSessionFactory;
    }

    @Override
    public String MAIN(CgiRequest cgi) {
        ZandakaDto dto = new ZandakaDto();
        CgiParam kouzaParam = cgi.param("kouza");
        if (!kouzaParam.found()) {
            throw CgiError.ERR_400("missing_kouza");
        }
        dto.setHV_KOUZA(Cobol.truncate(Cobol.NUMVAL(kouzaParam.value()), 7));

        boolean wkFound = false;

        Connection conn = Db.DB_CONNECT();
        try (SqlSession session = sqlSessionFactory.openSession(conn)) {
            ZandakaDao dao = session.getMapper(ZandakaDao.class);

            // KS_JAVA_START
            try {
                ZandakaDto result = dao.select_01(dto);
                if (result != null) {
                    dto.setHV_KANJI(result.getHV_KANJI());
                    dto.setHV_KANA(result.getHV_KANA());
                    dto.setHV_SHU(result.getHV_SHU());
                    dto.setHV_ZAN(result.getHV_ZAN());
                    dto.setHV_JOU(result.getHV_JOU());
                }
            } catch (Exception e) {
            }
            // KS_JAVA_END
            wkFound = dto.getHV_KANJI() != null;
        } finally {
            Db.DB_DISCONNECT(conn);
        }

        if (!wkFound) {
            throw CgiError.ERR_404("kouza_not_found");
        }

        return BUILD_JSON(dto);
    }

    private String BUILD_JSON(ZandakaDto dto) {
        StringBuilder RESP_BUF = new StringBuilder();
        String WK_KOUZA_Z = Cobol.pic9(dto.getHV_KOUZA(), 7);
        RESP_BUF.append("{\"ok\":true,\"kouza\":\"").append(WK_KOUZA_Z)
                .append("\",\"meigiKanji\":\"").append(Cobol.TRIM(dto.getHV_KANJI()))
                .append("\",\"meigiKana\":\"").append(Cobol.TRIM(dto.getHV_KANA()))
                .append("\",\"shubetsu\":\"").append(Cobol.TRIM(dto.getHV_SHU()))
                .append("\",\"zandaka\":").append(NumFmt.trim(dto.getHV_ZAN()))
                .append(",\"joutai\":\"").append(Cobol.TRIM(dto.getHV_JOU()))
                .append("\"}");
        return RESP_BUF.toString();
    }
}
