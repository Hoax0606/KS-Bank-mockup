package com.ksbank.minibank.strict.online.holdings;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.db.Db;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.NumFmt;

/**
 * COBOL HOLDINGS.cbl 1:1 포팅.
 * ※ 원본 그대로 kouza 파라미터 "누락" 자체를 체크하지 않는다 — 바로 NUMVAL(빈 문자열이면 0)
 *   후 count 체크로 진행하며, 없으면 자연스럽게 404 kouza_not_found가 나온다.
 *   (backend-java의 holdings 는 missing_kouza 400을 별도로 던지므로 여기만 의도적으로 다르다.)
 */
public class Holdings {

    public String run(CgiRequest cgi) {
        Connection conn = null;
        try {
            long hvKouza = pic9(numval(cgi.param("kouza").value()), 7);

            conn = Db.connect();

            long hvCnt = 0;
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT COUNT(*) FROM kouza WHERE kouza_no = ?")) {
                ps.setLong(1, hvKouza);
                try (ResultSet rs = ps.executeQuery()) {
                    rs.next();
                    hvCnt = rs.getLong(1);
                }
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }

            if (hvCnt == 0) {
                throw CgiError.err404("kouza_not_found");
            }

            String hvKanji = null, hvShu = null, hvType = null, hvJou = null,
                   hvBr = null, hvPrim = null;
            long hvZan = 0;
            String hvBirth = "", hvSex = "", hvZip = "", hvAddr = "",
                   hvPhone = "", hvEmail = "", hvJob = "";

            try (PreparedStatement ps = conn.prepareStatement("""
                    SELECT k.meigi_kanji, k.shubetsu,
                           k.zandaka, k.joutai,
                           x.acct_type, x.branch_code, x.is_primary,
                           x.birth, x.sex, x.zip, x.addr,
                           x.phone, x.email, x.job
                      FROM kouza k, kouza_ext x
                     WHERE x.kouza_no = k.kouza_no
                       AND k.kouza_no = ?
                    """)) {
                ps.setLong(1, hvKouza);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        hvKanji = rs.getString(1);
                        hvShu = rs.getString(2);
                        hvZan = rs.getLong(3);
                        hvJou = rs.getString(4);
                        hvType = rs.getString(5);
                        hvBr = rs.getString(6);
                        hvPrim = rs.getString(7);
                        // 신규 계좌는 KOUZA_EXT 프로필 열이 NULL — COBOL IND-* < 0 체크 대응.
                        String v;
                        v = rs.getString(8); hvBirth = rs.wasNull() ? "" : v;
                        v = rs.getString(9); hvSex = rs.wasNull() ? "" : v;
                        v = rs.getString(10); hvZip = rs.wasNull() ? "" : v;
                        v = rs.getString(11); hvAddr = rs.wasNull() ? "" : v;
                        v = rs.getString(12); hvPhone = rs.wasNull() ? "" : v;
                        v = rs.getString(13); hvEmail = rs.wasNull() ? "" : v;
                        v = rs.getString(14); hvJob = rs.wasNull() ? "" : v;
                    }
                }
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }

            return buildJson(hvKouza, hvBr, hvKanji, hvShu, hvType, hvJou, hvPrim, hvZan,
                hvBirth, hvSex, hvZip, hvAddr, hvPhone, hvEmail, hvJob);
        } finally {
            Db.disconnect(conn);
        }
    }

    private static String buildJson(long hvKouza, String hvBr, String hvKanji, String hvShu,
                                     String hvType, String hvJou, String hvPrim, long hvZan,
                                     String hvBirth, String hvSex, String hvZip, String hvAddr,
                                     String hvPhone, String hvEmail, String hvJob) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\"ok\":true,\"holdings\":[{\"kouza\":\"").append(zpad7(hvKouza))
          .append("\",\"branch\":\"").append(trim(hvBr))
          .append("\",\"meigiKanji\":\"").append(trim(hvKanji))
          .append("\",\"shubetsu\":\"").append(trim(hvShu))
          .append("\",\"type\":\"").append(trim(hvType))
          .append("\",\"joutai\":\"").append(trim(hvJou))
          .append("\",\"isPrimary\":\"").append(trim(hvPrim))
          .append("\",\"zandaka\":").append(NumFmt.trim(hvZan))
          .append(",\"birth\":\"").append(trim(hvBirth))
          .append("\",\"sex\":\"").append(trim(hvSex))
          .append("\",\"zip\":\"").append(trim(hvZip))
          .append("\",\"addr\":\"").append(trim(hvAddr))
          .append("\",\"phone\":\"").append(trim(hvPhone))
          .append("\",\"email\":\"").append(trim(hvEmail))
          .append("\",\"job\":\"").append(trim(hvJob))
          .append("\"}]}");
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
