package com.ksbank.minibank.strict.online.login;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.db.Db;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.NumFmt;

/**
 * COBOL LOGIN.cbl 1:1 포팅.
 * POST branch(店番3桁)/acct(口座番号7桁)/pw -> KOUZA_EXT 로 인증 후 KOUZA+KOUZA_EXT 상세 조회.
 * ※ 두 번째 SELECT(상세)는 COBOL 원본처럼 SQLCODE 체크를 하지 않는다.
 */
public class Login {

    public String run(CgiRequest cgi) {
        Connection conn = null;
        try {
            String hvBr = left(cgi.param("branch").value(), 3);
            long hvKouza = pic9(numval(cgi.param("acct").value()), 7);
            String hvPw = cgi.param("pw").value();
            if (isSpaces(hvPw)) {
                throw CgiError.err409("invalid_login");
            }

            conn = Db.connect();

            long hvCnt;
            try (PreparedStatement ps = conn.prepareStatement("""
                    SELECT COUNT(*)
                      FROM kouza_ext
                     WHERE branch_code = ?
                       AND kouza_no    = ?
                       AND password    = ?
                    """)) {
                ps.setString(1, hvBr.trim());
                ps.setLong(2, hvKouza);
                ps.setString(3, hvPw.trim());
                try (ResultSet rs = ps.executeQuery()) {
                    rs.next();
                    hvCnt = rs.getLong(1);
                }
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }
            if (hvCnt == 0) {
                throw CgiError.err409("invalid_login");
            }

            String hvKanji = null, hvShu = null, hvJou = null, hvType = null;
            long hvZan = 0;
            try (PreparedStatement ps = conn.prepareStatement("""
                    SELECT k.meigi_kanji, k.shubetsu,
                           k.zandaka, k.joutai, x.acct_type
                      FROM kouza k, kouza_ext x
                     WHERE x.kouza_no = k.kouza_no
                       AND k.kouza_no = ?
                    """)) {
                ps.setLong(1, hvKouza);
                try (ResultSet rs = ps.executeQuery()) {
                    // COBOL은 이 SELECT의 SQLCODE를 확인하지 않는다 — 그대로 재현.
                    if (rs.next()) {
                        hvKanji = rs.getString(1);
                        hvShu = rs.getString(2);
                        hvZan = rs.getLong(3);
                        hvJou = rs.getString(4);
                        hvType = rs.getString(5);
                    }
                }
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }

            return buildJson(hvKouza, hvBr, hvKanji, hvShu, hvType, hvJou, hvZan);
        } finally {
            Db.disconnect(conn);
        }
    }

    private static String buildJson(long hvKouza, String hvBr, String hvKanji,
                                     String hvShu, String hvType, String hvJou, long hvZan) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\"ok\":true,\"kouza\":\"").append(zpad7(hvKouza))
          .append("\",\"branch\":\"").append(trim(hvBr))
          .append("\",\"meigiKanji\":\"").append(trim(hvKanji))
          .append("\",\"shubetsu\":\"").append(trim(hvShu))
          .append("\",\"type\":\"").append(trim(hvType))
          .append("\",\"joutai\":\"").append(trim(hvJou))
          .append("\",\"zandaka\":").append(NumFmt.trim(hvZan))
          .append("}");
        return sb.toString();
    }

    // -- COBOL FUNCTION NUMVAL / PIC 9(n) MOVE 대응 헬퍼 (각 프로그램 개별 보유) --
    static long numval(String s) {
        if (s == null) return 0;
        s = s.trim();
        if (s.isEmpty()) return 0;
        try {
            return (long) Double.parseDouble(s);
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    /** MOVE <numeric> TO PIC 9(n) — 부호 무시, 하위 n자리만 남김(상위 자리 절단). */
    static long pic9(long v, int digits) {
        long av = Math.abs(v);
        long mod = (long) Math.pow(10, digits);
        return av % mod;
    }

    /** PIC 9(n) 값을 선행 0 포함 n자리 문자열로(표시 편집, WK-KOUZA-Z 대응). */
    static String zpad7(long v) {
        return String.format("%07d", v);
    }

    /** MOVE CP-VALUE(1:n) — 앞에서 n글자, 모자라면 공백으로 채움. */
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
