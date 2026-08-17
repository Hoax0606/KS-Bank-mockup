package com.ksbank.minibank.strict.online.repay;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.db.Db;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.NumFmt;

/**
 * COBOL REPAY.cbl 1:1 포팅.
 * 경과이자 = FUNCTION INTEGER(잔액*이율/100/12 + 0.5) (floor 방식, Math.round 아님).
 * 중도수수료 550 고정, 원자적(계좌차감+대출갱신+INSERT), 실패 시 named {@link #rpAbort}.
 */
public class Repay {

    private static final String HV_ACT = "ACTIVE";
    private static final String HV_CLST = "CLOSED";
    private static final long HV_FEE = 550;

    public String run(CgiRequest cgi) {
        Connection conn = null;
        try {
            long hvLoanId = pic9(numval(cgi.param("loanId").value()), 12);
            long hvPrin = numval(cgi.param("principal").value());
            if (hvPrin <= 0) {
                throw CgiError.err400("invalid_amount");
            }

            conn = Db.connect();

            long hvCnt;
            try (PreparedStatement ps = conn.prepareStatement("""
                    SELECT COUNT(*) FROM loan_asis
                     WHERE loan_id = ? AND status = ?
                    """)) {
                ps.setLong(1, hvLoanId);
                ps.setString(2, HV_ACT);
                try (ResultSet rs = ps.executeQuery()) {
                    rs.next();
                    hvCnt = rs.getLong(1);
                }
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }
            if (hvCnt == 0) {
                throw CgiError.err404("loan_not_found");
            }

            long hvBal;
            double hvRate;
            long hvKouza;
            try (PreparedStatement ps = conn.prepareStatement("""
                    SELECT balance, rate, kouza_no
                      FROM loan_asis WHERE loan_id = ?
                    """)) {
                ps.setLong(1, hvLoanId);
                try (ResultSet rs = ps.executeQuery()) {
                    rs.next();
                    hvBal = rs.getLong(1);
                    hvRate = rs.getDouble(2);
                    hvKouza = rs.getLong(3);
                }
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }
            if (hvPrin > hvBal) {
                throw CgiError.err409("over_balance");
            }

            long hvInt = (long) Math.floor(hvBal * hvRate / 100.0 / 12.0 + 0.5);
            long hvTotal = hvPrin + hvInt + HV_FEE;

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
            if (hvZan < hvTotal) {
                throw CgiError.err409("insufficient_funds");
            }

            long hvNewBal = hvBal - hvPrin;
            boolean wkClosed = hvNewBal <= 0;

            // ===== 트랜잭션 시작 =====
            hvZan -= hvTotal;
            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE kouza SET zandaka = ? WHERE kouza_no = ?")) {
                ps.setLong(1, hvZan);
                ps.setLong(2, hvKouza);
                ps.executeUpdate();
            } catch (SQLException e) {
                rpAbort(conn);
            }

            if (wkClosed) {
                try (PreparedStatement ps = conn.prepareStatement("""
                        UPDATE loan_asis
                           SET balance = 0, status = ?, closed_date = ?
                         WHERE loan_id = ?
                        """)) {
                    ps.setString(1, HV_CLST);
                    ps.setObject(2, LocalDate.now());
                    ps.setLong(3, hvLoanId);
                    ps.executeUpdate();
                } catch (SQLException e) {
                    rpAbort(conn);
                }
            } else {
                try (PreparedStatement ps = conn.prepareStatement(
                        "UPDATE loan_asis SET balance = ? WHERE loan_id = ?")) {
                    ps.setLong(1, hvNewBal);
                    ps.setLong(2, hvLoanId);
                    ps.executeUpdate();
                } catch (SQLException e) {
                    rpAbort(conn);
                }
            }

            long hvRepId;
            try (PreparedStatement ps = conn.prepareStatement("SELECT nextval('seq_repay_asis')");
                 ResultSet rs = ps.executeQuery()) {
                rs.next();
                hvRepId = rs.getLong(1);
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }

            try (PreparedStatement ps = conn.prepareStatement("""
                    INSERT INTO loan_repay_asis
                      (repay_id, loan_id, principal, interest, fee, total)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """)) {
                ps.setLong(1, hvRepId);
                ps.setLong(2, hvLoanId);
                ps.setLong(3, hvPrin);
                ps.setLong(4, hvInt);
                ps.setLong(5, HV_FEE);
                ps.setLong(6, hvTotal);
                ps.executeUpdate();
            } catch (SQLException e) {
                rpAbort(conn);
            }

            try {
                conn.commit();
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }

            return buildJson(hvLoanId, hvPrin, hvInt, hvTotal, hvNewBal, wkClosed);
        } finally {
            Db.disconnect(conn);
        }
    }

    /** COBOL RP-ABORT(named) — ROLLBACK 후 CgiError. disconnect는 run()의 finally가 담당. */
    private static void rpAbort(Connection conn) {
        try {
            conn.rollback();
        } catch (SQLException ignore) {
            // best-effort, COBOL EXEC SQL ROLLBACK도 결과를 확인하지 않는다.
        }
        throw CgiError.err500("repay_failed");
    }

    private static String buildJson(long hvLoanId, long hvPrin, long hvInt, long hvTotal,
                                     long hvNewBal, boolean wkClosed) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\"ok\":true,\"loanId\":").append(NumFmt.trim(hvLoanId))
          .append(",\"principal\":").append(NumFmt.trim(hvPrin))
          .append(",\"interest\":").append(NumFmt.trim(hvInt))
          .append(",\"fee\":550,\"total\":").append(NumFmt.trim(hvTotal))
          .append(",\"loanBalance\":").append(NumFmt.trim(hvNewBal))
          .append(",\"closed\":").append(wkClosed ? "true" : "false")
          .append('}');
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
}
