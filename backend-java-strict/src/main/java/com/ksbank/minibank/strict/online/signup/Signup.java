package com.ksbank.minibank.strict.online.signup;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.db.Db;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.Utf2Sjis;

/**
 * COBOL SIGNUP.cbl 1:1 포팅.
 * ※ 원본이 롤백 블록을 헬퍼 없이 두 번(KOUZA INSERT 실패 / KOUZA_EXT INSERT 실패) 그대로
 *   인라인 중복해 두었으므로, 이 포팅도 signupAbort() 같은 공통 메서드를 만들지 않고
 *   두 곳에 동일한 코드를 그대로 반복한다.
 */
public class Signup {

    private static final DateTimeFormatter YMD = DateTimeFormatter.ofPattern("yyyyMMdd");

    public String run(CgiRequest cgi) {
        Connection conn = null;
        try {
            String hvKanji = cgi.param("kanji").value();
            String hvKana = cgi.param("kana").value();
            String hvBr = left(cgi.param("branch").value(), 3);
            String hvType = cgi.param("type").value();
            String hvPw = cgi.param("pw").value();

            if (isSpaces(hvKanji) || isSpaces(hvPw)) {
                throw CgiError.err400("missing_required");
            }

            // UTF-8(브라우저 송신) -> Shift-JIS(DB 저장) 변환 지점(이 모듈은 PostgreSQL/UTF-8이라 no-op).
            hvKanji = Utf2Sjis.toDbCharset(hvKanji);
            hvKana = Utf2Sjis.toDbCharset(hvKana);

            String hvShu = hvType.startsWith("当座") ? "2" : "1";
            String hvKai = LocalDate.now().format(YMD);

            conn = Db.connect();

            long hvNewNo;
            try (PreparedStatement ps = conn.prepareStatement("SELECT nextval('seq_kouza_dyn')");
                 ResultSet rs = ps.executeQuery()) {
                rs.next();
                hvNewNo = rs.getLong(1);
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }

            try (PreparedStatement ps = conn.prepareStatement("""
                    INSERT INTO kouza
                      (kouza_no, meigi_kanji, meigi_kana, shubetsu,
                       zandaka, kaisetsu_bi, joutai)
                    VALUES (?, ?, ?, ?, 0, ?, '0')
                    """)) {
                ps.setLong(1, hvNewNo);
                ps.setString(2, hvKanji.trim());
                ps.setString(3, hvKana.trim());
                ps.setString(4, hvShu);
                ps.setString(5, hvKai);
                ps.executeUpdate();
            } catch (SQLException e) {
                try {
                    conn.rollback();
                } catch (SQLException ignore) {
                    // best-effort, COBOL EXEC SQL ROLLBACK도 결과를 확인하지 않는다.
                }
                throw CgiError.err500("signup_failed");
            }

            try (PreparedStatement ps = conn.prepareStatement("""
                    INSERT INTO kouza_ext
                      (kouza_no, branch_code, acct_type,
                       password, is_primary)
                    VALUES (?, ?, ?, ?, 'N')
                    """)) {
                ps.setLong(1, hvNewNo);
                ps.setString(2, hvBr.trim());
                ps.setString(3, hvType.trim());
                ps.setString(4, hvPw.trim());
                ps.executeUpdate();
            } catch (SQLException e) {
                try {
                    conn.rollback();
                } catch (SQLException ignore) {
                    // best-effort, COBOL EXEC SQL ROLLBACK도 결과를 확인하지 않는다.
                }
                throw CgiError.err500("signup_failed");
            }

            try {
                conn.commit();
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }

            return buildJson(hvNewNo, hvBr, hvType, hvShu);
        } finally {
            Db.disconnect(conn);
        }
    }

    private static String buildJson(long hvNewNo, String hvBr, String hvType, String hvShu) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\"ok\":true,\"kouza\":\"").append(zpad7(hvNewNo))
          .append("\",\"branch\":\"").append(trim(hvBr))
          .append("\",\"type\":\"").append(trim(hvType))
          .append("\",\"shubetsu\":\"").append(trim(hvShu))
          .append("\"}");
        return sb.toString();
    }

    static String zpad7(long v) {
        return String.format("%07d", v);
    }

    static String left(String s, int n) {
        String v = s == null ? "" : s;
        if (v.length() >= n) return v.substring(0, n);
        StringBuilder sb = new StringBuilder(v);
        while (sb.length() < n) sb.append(' ');
        return sb.toString();
    }

    static boolean isSpaces(String s) {
        return s == null || s.isBlank();
    }

    static String trim(String s) {
        return s == null ? "" : s.trim();
    }
}
