package com.ksbank.minibank.strict.online.loan;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.db.Db;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.NumFmt;

/**
 * COBOL LOAN.cbl 1:1 포팅. GET=목록(DO-LIST), POST=신청(DO-APPLY).
 * ※ 원본처럼 최상위에서 kouza 파라미터의 "누락" 자체를 체크하지 않는다 — NUMVAL(빈 값이면 0)
 *   후 그대로 진행한다(HOLDINGS와 마찬가지로 COBOL 원본의 실제 동작).
 */
public class Loan {

    private static final String HV_ACT = "ACTIVE";
    private static final long LOAN_AVAIL = 3_000_000;
    private static final DateTimeFormatter DT14 = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");

    public String run(CgiRequest cgi) {
        Connection conn = null;
        try {
            long hvKouza = pic9(numval(cgi.param("kouza").value()), 7);

            conn = Db.connect();

            String out;
            if ("POST".equals(cgi.method())) {
                out = doApply(cgi, conn, hvKouza);
            } else {
                out = doList(conn, hvKouza);
            }
            return out;
        } finally {
            Db.disconnect(conn);
        }
    }

    private String doList(Connection conn, long hvKouza) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\"ok\":true,\"loans\":[");
        boolean firstRow = true;
        try (PreparedStatement ps = conn.prepareStatement("""
                SELECT loan_id, principal, balance, method, term_years
                  FROM loan_asis WHERE status = ? AND kouza_no = ? ORDER BY loan_id
                """)) {
            ps.setString(1, HV_ACT);
            ps.setLong(2, hvKouza);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    long cId = rs.getLong(1);
                    long cPrin = rs.getLong(2);
                    long cBal = rs.getLong(3);
                    String cMethod = rs.getString(4);
                    int cYears = rs.getInt(5);
                    if (firstRow) {
                        firstRow = false;
                    } else {
                        sb.append(',');
                    }
                    sb.append("{\"loanId\":").append(NumFmt.trim(cId))
                      .append(",\"principal\":").append(NumFmt.trim(cPrin))
                      .append(",\"balance\":").append(NumFmt.trim(cBal))
                      .append(",\"method\":\"").append(cMethod)
                      .append("\",\"years\":").append(NumFmt.trim(cYears))
                      .append('}');
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        sb.append("]}");
        return sb.toString();
    }

    private String doApply(CgiRequest cgi, Connection conn, long hvKouza) {
        long hvAmt = numval(cgi.param("amt").value());

        String rawMethod = cgi.param("method").value();
        String hvMethod = rawMethod.isEmpty() ? " " : rawMethod.substring(0, 1);
        if (!"A".equals(hvMethod) && !"B".equals(hvMethod) && !"C".equals(hvMethod)) {
            hvMethod = "A";
        }

        int hvYears = (int) pic9(numval(cgi.param("years").value()), 3);

        if (hvAmt <= 0) {
            throw CgiError.err400("invalid_amount");
        }

        long hvUsed;
        try (PreparedStatement ps = conn.prepareStatement("""
                SELECT COALESCE(SUM(balance),0) FROM loan_asis
                 WHERE status = ? AND kouza_no = ?
                """)) {
            ps.setString(1, HV_ACT);
            ps.setLong(2, hvKouza);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                hvUsed = rs.getLong(1);
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        if (hvUsed + hvAmt > LOAN_AVAIL) {
            throw CgiError.err409("loan_over_limit");
        }

        long hvCnt;
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

        long hvLoanId, hvTid;
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT nextval('seq_loan_asis'), nextval('seq_torihiki')")) {
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                hvLoanId = rs.getLong(1);
                hvTid = rs.getLong(2);
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        String hvDt = LocalDateTime.now().format(DT14);
        long hvBal = hvAmt;

        try (PreparedStatement ps = conn.prepareStatement("""
                INSERT INTO loan_asis
                  (loan_id, kouza_no, principal, balance, method,
                   term_years, rate, status)
                VALUES (?, ?, ?, ?, ?, ?, 2.5, ?)
                """)) {
            ps.setLong(1, hvLoanId);
            ps.setLong(2, hvKouza);
            ps.setLong(3, hvAmt);
            ps.setLong(4, hvBal);
            ps.setString(5, hvMethod);
            ps.setInt(6, hvYears);
            ps.setString(7, HV_ACT);
            ps.executeUpdate();
        } catch (SQLException e) {
            loanAbort(conn);
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
        hvZan += hvAmt;
        try (PreparedStatement ps = conn.prepareStatement(
                "UPDATE kouza SET zandaka = ? WHERE kouza_no = ?")) {
            ps.setLong(1, hvZan);
            ps.setLong(2, hvKouza);
            ps.executeUpdate();
        } catch (SQLException e) {
            loanAbort(conn);
        }

        try (PreparedStatement ps = conn.prepareStatement("""
                INSERT INTO torihiki
                  (torihiki_id, kouza_no, torihiki_dt, torihiki_kbn,
                   kingaku, aite_kouza, tesuryo, tekiyou)
                VALUES (?, ?, ?, '1', ?, NULL, NULL, NULL)
                """)) {
            ps.setLong(1, hvTid);
            ps.setLong(2, hvKouza);
            ps.setString(3, hvDt);
            ps.setLong(4, hvAmt);
            ps.executeUpdate();
        } catch (SQLException e) {
            loanAbort(conn);
        }

        try {
            conn.commit();
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }

        StringBuilder sb = new StringBuilder();
        sb.append("{\"ok\":true,\"loanId\":").append(NumFmt.trim(hvLoanId))
          .append(",\"kouza\":\"").append(zpad7(hvKouza))
          .append("\",\"amount\":").append(NumFmt.trim(hvAmt))
          .append('}');
        return sb.toString();
    }

    /** COBOL LOAN-ABORT(named) — ROLLBACK 후 CgiError. disconnect는 run()의 finally가 담당. */
    private static void loanAbort(Connection conn) {
        try {
            conn.rollback();
        } catch (SQLException ignore) {
            // best-effort, COBOL EXEC SQL ROLLBACK도 결과를 확인하지 않는다.
        }
        throw CgiError.err500("loan_failed");
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
