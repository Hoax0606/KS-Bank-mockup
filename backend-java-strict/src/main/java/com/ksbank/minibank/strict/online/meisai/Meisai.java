package com.ksbank.minibank.strict.online.meisai;

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
 * COBOL MEISAI.cbl 1:1 포팅.
 * 전체 명세를 시간 오름차순으로 OCCURS 1000 고정배열({@link RowsTable})에 적재하며
 * CALC-DELTA(이 프로그램 전용 독립 사본, batch 쪽과 공유하지 않음)로 부호합계를 누적 ->
 * 期首残高 = 현재잔액 - 합계 -> 오름차순 재통과로 afterBal 확정 -> 내림차순 + 필터로 출력.
 */
public class Meisai {

    public String run(CgiRequest cgi) {
        Connection conn = null;
        try {
            CgiParam kouzaParam = cgi.param("kouza");
            if (!kouzaParam.found()) {
                throw CgiError.err400("missing_kouza");
            }
            long hvKouza = pic9(numval(kouzaParam.value()), 7);

            Filters f = readFilters(cgi);

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

            long hvZan;
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT zandaka FROM kouza WHERE kouza_no = ?")) {
                ps.setLong(1, hvKouza);
                try (ResultSet rs = ps.executeQuery()) {
                    rs.next();
                    hvZan = rs.getLong(1);
                }
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }

            RowsTable rows = new RowsTable();
            long wkSum = 0;
            try (PreparedStatement ps = conn.prepareStatement("""
                    SELECT torihiki_dt, torihiki_kbn, kingaku,
                           COALESCE(tesuryo,0), tekiyou, COALESCE(aite_kouza,0)
                      FROM torihiki
                     WHERE kouza_no = ?
                     ORDER BY torihiki_dt ASC, torihiki_id ASC
                    """)) {
                ps.setLong(1, hvKouza);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rows.size() < RowsTable.MAX && rs.next()) {
                        String dt = rs.getString(1);
                        String kbn = rs.getString(2);
                        long kin = rs.getLong(3);
                        long tes = rs.getLong(4);
                        String tek = rs.getString(5);
                        long aite = rs.getLong(6);
                        rows.add(dt, kbn, kin, tes, tek, aite);
                        wkSum += calcDelta(kbn, kin, tes);
                    }
                }
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }

            int n = rows.size();
            long wkOpening = hvZan - wkSum;
            long wkRun = wkOpening;
            for (int i = 0; i < n; i++) {
                wkRun += calcDelta(rows.kbn(i), rows.kin(i), rows.tes(i));
                rows.setAfter(i, wkRun);
            }

            return buildJson(hvKouza, rows, n, f);
        } finally {
            Db.disconnect(conn);
        }
    }

    /** COBOL CALC-DELTA — 이 프로그램만의 독립 사본(배치 쪽과 공유하지 않음). */
    private static long calcDelta(String hvKbn, long hvKin, long hvTes) {
        if ("1".equals(hvKbn)) return hvKin;
        if ("2".equals(hvKbn)) return -hvKin;
        if ("3".equals(hvKbn)) return -(hvKin + hvTes);
        return 0;
    }

    private record Filters(String kbn, String from, String to) {
    }

    private static Filters readFilters(CgiRequest cgi) {
        String filtKbn = "A";
        CgiParam kbnParam = cgi.param("kbn");
        if (kbnParam.found() && !kbnParam.value().isEmpty() && kbnParam.value().charAt(0) != ' ') {
            String v = kbnParam.value();
            if (v.length() >= 3 && v.substring(0, 3).equals("all")) {
                filtKbn = "A";
            } else {
                filtKbn = v.substring(0, 1);
            }
        }
        String from = "        ";
        CgiParam fromParam = cgi.param("from");
        if (fromParam.found()) {
            from = normDate8(fromParam.value());
        }
        String to = "        ";
        CgiParam toParam = cgi.param("to");
        if (toParam.found()) {
            to = normDate8(toParam.value());
        }
        return new Filters(filtKbn, from, to);
    }

    /** COBOL NORM-FROM/NORM-TO: '-'/'/' -> ' ' 치환 -> TRIM -> PIC X(8) 이동(절단/공백채움). */
    private static String normDate8(String raw) {
        String tmp = raw == null ? "" : raw;
        if (tmp.length() > 16) tmp = tmp.substring(0, 16);
        tmp = tmp.replace('-', ' ').replace('/', ' ');
        String trimmed = tmp.trim();
        if (trimmed.length() >= 8) return trimmed.substring(0, 8);
        StringBuilder sb = new StringBuilder(trimmed);
        while (sb.length() < 8) sb.append(' ');
        return sb.toString();
    }

    private static String buildJson(long hvKouza, RowsTable rows, int n, Filters f) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\"ok\":true,\"kouza\":\"").append(zpad7(hvKouza)).append("\",\"rows\":[");
        boolean firstRow = true;
        boolean fromBlank = f.from().isBlank();
        boolean toBlank = f.to().isBlank();
        for (int i = n - 1; i >= 0; i--) {
            String kbn = rows.kbn(i);
            if (!("A".equals(f.kbn()) || f.kbn().equals(kbn))) continue;
            String dt14 = rows.dt(i);
            String dt8 = dt14.length() >= 8 ? dt14.substring(0, 8) : dt14;
            if (!fromBlank && dt8.compareTo(f.from()) < 0) continue;
            if (!toBlank && dt8.compareTo(f.to()) > 0) continue;

            if (firstRow) {
                firstRow = false;
            } else {
                sb.append(',');
            }
            sb.append("{\"date\":\"")
              .append(dt8, 0, 4).append('-').append(dt8, 4, 6).append('-').append(dt8, 6, 8)
              .append("\",\"kbn\":\"").append(kbn)
              .append("\",\"kingaku\":").append(NumFmt.trim(rows.kin(i)))
              .append(",\"afterBal\":").append(NumFmt.trim(rows.after(i)))
              .append(",\"aite\":").append(NumFmt.trim(rows.aite(i)))
              .append(",\"memo\":\"");
            String tek = rows.tek(i);
            if (tek != null && !tek.isBlank()) {
                sb.append(tek.trim());
            }
            sb.append("\"}");
        }
        sb.append("]}");
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
}
