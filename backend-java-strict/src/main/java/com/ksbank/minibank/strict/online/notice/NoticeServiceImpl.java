package com.ksbank.minibank.strict.online.notice;

import java.sql.Connection;
import java.util.List;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.springframework.stereotype.Service;
import com.ksbank.minibank.strict.online.cgi.CgiParam;
import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.dao.NoticeDao;
import com.ksbank.minibank.strict.online.db.Db;
import com.ksbank.minibank.strict.online.dto.CNoticeDto;
import com.ksbank.minibank.strict.online.dto.NoticeDto;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.Cobol;
import com.ksbank.minibank.strict.online.util.NumFmt;
import com.ksbank.minibank.strict.online.util.Utf2Sjis;
import com.ksbank.minibank.strict.online.util.Utf2SjisException;

@Service
public class NoticeServiceImpl implements NoticeService {

    private final SqlSessionFactory sqlSessionFactory;

    public NoticeServiceImpl(SqlSessionFactory sqlSessionFactory) {
        this.sqlSessionFactory = sqlSessionFactory;
    }

    @Override
    public String MAIN(CgiRequest cgi) {
        NoticeDto dto = new NoticeDto();

        Connection conn = Db.DB_CONNECT();
        try (SqlSession session = sqlSessionFactory.openSession(conn)) {
            NoticeDao dao = session.getMapper(NoticeDao.class);
            if ("POST".equals(cgi.method())) {
                return DO_CREATE(cgi, conn, dao, dto);
            } else {
                return DO_LIST(dao, dto);
            }
        } finally {
            Db.DB_DISCONNECT(conn);
        }
    }

    private String DO_LIST(NoticeDao dao, NoticeDto dto) {
        StringBuilder RESP_BUF = new StringBuilder();
        RESP_BUF.append("{\"ok\":true,\"notices\":[");
        dto.setFIRST_ROW("Y");

        // KS_JAVA_START
        try {
            List<CNoticeDto> list = dao.select_01(dto);
            int SQLCODE = 0;
            int i = 0;
            while (SQLCODE == 0) {
                if (i < list.size()) {
                    dto.setCNoticeDto(list.get(i));
                    i++;
                    SQLCODE = 0;
                    EMIT_NOTICE(dto, RESP_BUF);
                } else {
                    SQLCODE = 100;
                }
            }
        } catch (Exception e) {
        }
        // KS_JAVA_END

        RESP_BUF.append("]}");
        return RESP_BUF.toString();
    }

    private void EMIT_NOTICE(NoticeDto dto, StringBuilder RESP_BUF) {
        if ("Y".equals(dto.getFIRST_ROW())) {
            dto.setFIRST_ROW("N");
        } else {
            RESP_BUF.append(',');
        }
        String C_DATE = dto.getCNoticeDto().getC_DATE();
        RESP_BUF.append("{\"date\":\"")
                .append(C_DATE, 0, 4).append('/')
                .append(C_DATE, 4, 6).append('/')
                .append(C_DATE, 6, 8)
                .append("\",\"tag\":\"").append(Cobol.TRIM(dto.getCNoticeDto().getC_TAG()))
                .append("\",\"title\":\"").append(Cobol.TRIM(dto.getCNoticeDto().getC_TITLE()))
                .append("\"}");
    }

    private String DO_CREATE(CgiRequest cgi, Connection conn, NoticeDao dao, NoticeDto dto) {
        dto.setWK_TITLE(cgi.param("title").value());
        if (dto.getWK_TITLE() == null || dto.getWK_TITLE().isBlank()) {
            throw CgiError.ERR_400("missing_title");
        }
        dto.setHV_TITLE(dto.getWK_TITLE());

        dto.setWK_BODY(cgi.param("body").value());
        dto.setHV_BODY(dto.getWK_BODY());

        CgiParam tagParam = cgi.param("tag");
        if (tagParam.found()) {
            dto.setWK_TAG(tagParam.value());
        } else {
            dto.setWK_TAG("新着");
        }
        dto.setHV_TAG(dto.getWK_TAG());

        dto.setWK_DATE(Cobol.CURRENT_DATE());
        dto.setHV_DATE(dto.getWK_DATE());

        try {
            dto.setHV_TITLE(Utf2Sjis.toDbCharset(dto.getHV_TITLE()));
        } catch (Utf2SjisException e) {
            throw CgiError.ERR_400("invalid_text_encoding");
        }
        try {
            dto.setHV_BODY(Utf2Sjis.toDbCharset(dto.getHV_BODY()));
        } catch (Utf2SjisException e) {
            throw CgiError.ERR_400("invalid_text_encoding");
        }
        try {
            dto.setHV_TAG(Utf2Sjis.toDbCharset(dto.getHV_TAG()));
        } catch (Utf2SjisException e) {
            throw CgiError.ERR_400("invalid_text_encoding");
        }

        // KS_JAVA_START
        try {
            long result = dao.select_02(dto);
            dto.setHV_NID(result);
        } catch (Exception e) {
        }
        // KS_JAVA_END

        // KS_JAVA_START
        try {
            if (dto.getWK_BODY() == null || dto.getWK_BODY().isBlank()) {
                dao.insert_01(dto);
            } else {
                dao.insert_02(dto);
            }
        } catch (Exception e) {
            try {
                conn.rollback();
            } catch (Exception ignore) {
            }
            throw CgiError.ERR_500("notice_failed");
        }
        // KS_JAVA_END

        try {
            conn.commit();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }

        StringBuilder RESP_BUF = new StringBuilder();
        RESP_BUF.append("{\"ok\":true,\"noticeId\":").append(NumFmt.trim(dto.getHV_NID())).append('}');
        return RESP_BUF.toString();
    }
}
