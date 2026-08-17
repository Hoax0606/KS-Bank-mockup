package com.ksbank.minibank.strict.online.zandaka;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import com.ksbank.minibank.strict.online.cgi.CgiParam;
import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.db.Db;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.NumFmt;

/**
 * COBOL ZANDAKA.cbl 1:1 포팅.
 * kouza 필수(400 missing_kouza) + KOUZA 테이블만 조회하는 독립 SELECT(HOLDINGS와 공유하지 않음).
 */
public class Zandaka {

    public String run(CgiRequest cgi) {
        Connection conn = null;
        try {
            CgiParam kouzaParam = cgi.param("kouza");
            if (!kouzaParam.found()) {
                throw CgiError.err400("missing_kouza");
            }
            long hvKouza = pic9(numval(kouzaParam.value()), 7);

            conn = Db.connect();

            boolean wkFound = false;
            String hvKanji = null, hvKana = null, hvShu = null, hvJou = null;
            long hvZan = 0;
            try (PreparedStatement ps = conn.prepareStatement("""
                    SELECT meigi_kanji, meigi_kana, shubetsu,
                           zandaka, joutai
                      FROM kouza
                     WHERE kouza_no = ?
                    """)) {
                ps.setLong(1, hvKouza);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        hvKanji = rs.getString(1);
                        hvKana = rs.getString(2);
                        hvShu = rs.getString(3);
                        hvZan = rs.getLong(4);
                        hvJou = rs.getString(5);
                        wkFound = true;
                    }
                }
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }

            if (!wkFound) {
                throw CgiError.err404("kouza_not_found");
            }

            return buildJson(hvKouza, hvKanji, hvKana, hvShu, hvZan, hvJou);
        } finally {
            Db.disconnect(conn);
        }
    }

    private static String buildJson(long hvKouza, String hvKanji, String hvKana,
                                     String hvShu, long hvZan, String hvJou) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\"ok\":true,\"kouza\":\"").append(zpad7(hvKouza))
          .append("\",\"meigiKanji\":\"").append(trim(hvKanji))
          .append("\",\"meigiKana\":\"").append(trim(hvKana))
          .append("\",\"shubetsu\":\"").append(trim(hvShu))
          .append("\",\"zandaka\":").append(NumFmt.trim(hvZan))
          .append(",\"joutai\":\"").append(trim(hvJou))
          .append("\"}");
        return sb.toString();
    }

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

    static long pic9(long v, int digits) {
        long av = Math.abs(v);
        long mod = (long) Math.pow(10, digits);
        return av % mod;
    }

    static String zpad7(long v) {
        return String.format("%07d", v);
    }

    static String trim(String s) {
        return s == null ? "" : s.trim();
    }
}
