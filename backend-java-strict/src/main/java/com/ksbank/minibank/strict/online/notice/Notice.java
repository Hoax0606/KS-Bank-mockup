package com.ksbank.minibank.strict.online.notice;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import com.ksbank.minibank.strict.online.cgi.CgiParam;
import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.db.Db;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.NumFmt;
import com.ksbank.minibank.strict.online.util.Utf2Sjis;

/**
 * COBOL NOTICE.cbl 1:1 포팅. GET=목록(DO-LIST), POST=등록(DO-CREATE).
 * COBOL이 한 프로그램 안에서 IF CGI-METHOD="POST" 로 분기하는 모양을 그대로 유지.
 */
public class Notice {

    private static final DateTimeFormatter YMD = DateTimeFormatter.ofPattern("yyyyMMdd");
    private static final String HV_ACT = "Y";

    public String run(CgiRequest cgi) {
        Connection conn = null;
        try {
            conn = Db.connect();
            String out;
            if ("POST".equals(cgi.method())) {
                out = doCreate(cgi, conn);
            } else {
                out = doList(conn);
            }
            return out;
        } finally {
            Db.disconnect(conn);
        }
    }

    private String doList(Connection conn) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\"ok\":true,\"notices\":[");
        boolean firstRow = true;
        try (PreparedStatement ps = conn.prepareStatement("""
                SELECT notice_date, tag, title
                  FROM notice_asis WHERE is_active = ?
                 ORDER BY notice_date DESC, notice_id DESC
                """)) {
            ps.setString(1, HV_ACT);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    String cDate = rs.getString(1);
                    String cTag = rs.getString(2);
                    String cTitle = rs.getString(3);
                    if (firstRow) {
                        firstRow = false;
                    } else {
                        sb.append(',');
                    }
                    sb.append("{\"date\":\"")
                      .append(cDate.substring(0, 4)).append('/')
                      .append(cDate.substring(4, 6)).append('/')
                      .append(cDate.substring(6, 8))
                      .append("\",\"tag\":\"").append(trim(cTag))
                      .append("\",\"title\":\"").append(trim(cTitle))
                      .append("\"}");
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        sb.append("]}");
        return sb.toString();
    }

    private String doCreate(CgiRequest cgi, Connection conn) {
        String wkTitle = cgi.param("title").value();
        if (isSpaces(wkTitle)) {
            throw CgiError.err400("missing_title");
        }
        String hvTitle = wkTitle;

        String wkBody = cgi.param("body").value();
        String hvBody = wkBody;

        CgiParam tagParam = cgi.param("tag");
        String wkTag = tagParam.found() ? tagParam.value() : "新着";
        String hvTag = wkTag;

        String hvDate = LocalDate.now().format(YMD);

        // UTF-8(브라우저 송신/기본값 리터럴 공통) -> Shift-JIS(DB 저장) 변환 지점(이 모듈은 no-op).
        hvTitle = Utf2Sjis.toDbCharset(hvTitle);
        hvBody = Utf2Sjis.toDbCharset(hvBody);
        hvTag = Utf2Sjis.toDbCharset(hvTag);

        long hvNid;
        try (PreparedStatement ps = conn.prepareStatement("SELECT nextval('seq_notice_asis')");
             ResultSet rs = ps.executeQuery()) {
            rs.next();
            hvNid = rs.getLong(1);
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }

        try (PreparedStatement ps = conn.prepareStatement("""
                INSERT INTO notice_asis
                  (notice_id, notice_date, tag, title, body, is_active)
                VALUES (?, ?, ?, ?, ?, ?)
                """)) {
            ps.setLong(1, hvNid);
            ps.setString(2, hvDate);
            ps.setString(3, hvTag.trim());
            ps.setString(4, hvTitle.trim());
            if (isSpaces(wkBody)) {
                ps.setNull(5, Types.VARCHAR);
            } else {
                ps.setString(5, hvBody.trim());
            }
            ps.setString(6, HV_ACT);
            ps.executeUpdate();
        } catch (SQLException e) {
            try {
                conn.rollback();
            } catch (SQLException ignore) {
                // best-effort, COBOL EXEC SQL ROLLBACK도 결과를 확인하지 않는다.
            }
            throw CgiError.err500("notice_failed");
        }

        try {
            conn.commit();
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }

        StringBuilder sb = new StringBuilder();
        sb.append("{\"ok\":true,\"noticeId\":").append(NumFmt.trim(hvNid)).append('}');
        return sb.toString();
    }

    static boolean isSpaces(String s) {
        return s == null || s.isBlank();
    }

    static String trim(String s) {
        return s == null ? "" : s.trim();
    }
}
