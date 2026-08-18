package com.ksbank.minibank.strict.online.holdings;

import java.sql.Connection;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.springframework.stereotype.Service;
import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.dao.HoldingsDao;
import com.ksbank.minibank.strict.online.db.Db;
import com.ksbank.minibank.strict.online.dto.HoldingsDto;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.Cobol;
import com.ksbank.minibank.strict.online.util.NumFmt;

/**
 * COBOL HOLDINGS.cbl 1:1 포팅.
 * ※ 원본 그대로 kouza 파라미터 "누락" 자체를 체크하지 않는다 — 바로 NUMVAL(빈 문자열이면 0)
 *   후 count 체크로 진행하며, 없으면 자연스럽게 404 kouza_not_found가 나온다.
 */
@Service
public class HoldingsServiceImpl implements HoldingsService {

    private final SqlSessionFactory sqlSessionFactory;

    public HoldingsServiceImpl(SqlSessionFactory sqlSessionFactory) {
        this.sqlSessionFactory = sqlSessionFactory;
    }

    @Override
    public String MAIN(CgiRequest cgi) {
        HoldingsDto dto = new HoldingsDto();
        dto.setHV_KOUZA(Cobol.truncate(Cobol.NUMVAL(cgi.param("kouza").value()), 7));

        Connection conn = Db.DB_CONNECT();
        try (SqlSession session = sqlSessionFactory.openSession(conn)) {
            HoldingsDao dao = session.getMapper(HoldingsDao.class);

            // KS_JAVA_START
            try {
                long result = dao.select_01(dto);
                dto.setHV_CNT(result);
            } catch (Exception e) {
            }
            // KS_JAVA_END

            if (dto.getHV_CNT() == 0) {
                throw CgiError.ERR_404("kouza_not_found");
            }

            // KS_JAVA_START
            try {
                HoldingsDto result = dao.select_02(dto);
                if (result != null) {
                    dto.setHV_KANJI(result.getHV_KANJI());
                    dto.setHV_SHU(result.getHV_SHU());
                    dto.setHV_ZAN(result.getHV_ZAN());
                    dto.setHV_JOU(result.getHV_JOU());
                    dto.setHV_TYPE(result.getHV_TYPE());
                    dto.setHV_BR(result.getHV_BR());
                    dto.setHV_PRIM(result.getHV_PRIM());
                    dto.setHV_BIRTH(result.getHV_BIRTH() == null ? "" : result.getHV_BIRTH());
                    dto.setHV_SEX(result.getHV_SEX() == null ? "" : result.getHV_SEX());
                    dto.setHV_ZIP(result.getHV_ZIP() == null ? "" : result.getHV_ZIP());
                    dto.setHV_ADDR(result.getHV_ADDR() == null ? "" : result.getHV_ADDR());
                    dto.setHV_PHONE(result.getHV_PHONE() == null ? "" : result.getHV_PHONE());
                    dto.setHV_EMAIL(result.getHV_EMAIL() == null ? "" : result.getHV_EMAIL());
                    dto.setHV_JOB(result.getHV_JOB() == null ? "" : result.getHV_JOB());
                }
            } catch (Exception e) {
            }
            // KS_JAVA_END
        } finally {
            Db.DB_DISCONNECT(conn);
        }

        return BUILD_JSON(dto);
    }

    private String BUILD_JSON(HoldingsDto dto) {
        StringBuilder RESP_BUF = new StringBuilder();
        String WK_KOUZA_Z = Cobol.pic9(dto.getHV_KOUZA(), 7);
        RESP_BUF.append("{\"ok\":true,\"holdings\":[{\"kouza\":\"").append(WK_KOUZA_Z)
                .append("\",\"branch\":\"").append(Cobol.TRIM(dto.getHV_BR()))
                .append("\",\"meigiKanji\":\"").append(Cobol.TRIM(dto.getHV_KANJI()))
                .append("\",\"shubetsu\":\"").append(Cobol.TRIM(dto.getHV_SHU()))
                .append("\",\"type\":\"").append(Cobol.TRIM(dto.getHV_TYPE()))
                .append("\",\"joutai\":\"").append(Cobol.TRIM(dto.getHV_JOU()))
                .append("\",\"isPrimary\":\"").append(Cobol.TRIM(dto.getHV_PRIM()))
                .append("\",\"zandaka\":").append(NumFmt.trim(dto.getHV_ZAN()))
                .append(",\"birth\":\"").append(Cobol.TRIM(dto.getHV_BIRTH()))
                .append("\",\"sex\":\"").append(Cobol.TRIM(dto.getHV_SEX()))
                .append("\",\"zip\":\"").append(Cobol.TRIM(dto.getHV_ZIP()))
                .append("\",\"addr\":\"").append(Cobol.TRIM(dto.getHV_ADDR()))
                .append("\",\"phone\":\"").append(Cobol.TRIM(dto.getHV_PHONE()))
                .append("\",\"email\":\"").append(Cobol.TRIM(dto.getHV_EMAIL()))
                .append("\",\"job\":\"").append(Cobol.TRIM(dto.getHV_JOB()))
                .append("\"}]}");
        return RESP_BUF.toString();
    }
}
