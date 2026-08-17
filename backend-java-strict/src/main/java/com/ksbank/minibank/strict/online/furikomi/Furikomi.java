package com.ksbank.minibank.strict.online.furikomi;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import com.ksbank.minibank.strict.online.cgi.CgiParam;
import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.db.Db;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.NumFmt;

/**
 * COBOL FURIKOMI.cbl 1:1 포팅. ★원자적★
 * 출금측 -(금액+수수료110) + (수취계좌 자행 존재 시) 입금측 +금액을 한 트랜잭션으로 처리.
 * 실패 시 named 메서드 {@link #txnAbort}로 여러 지점에서 재사용(ROLLBACK 후 CgiError).
 */
public class Furikomi {

    private static final DateTimeFormatter DT14 = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");

    public String run(CgiRequest cgi) {
        Connection conn = null;
        try {
            CgiParam kouzaParam = cgi.param("kouza");
            if (!kouzaParam.found()) {
                throw CgiError.err400("missing_kouza");
            }
            long hvKouza = pic9(numval(kouzaParam.value()), 7);

            CgiParam aiteParam = cgi.param("aite");
            if (!aiteParam.found()) {
                throw CgiError.err400("missing_aite");
            }
            long hvAite = pic9(numval(aiteParam.value()), 7);

            long hvAmt = numval(cgi.param("kingaku").value());
            if (hvAmt <= 0) {
                throw CgiError.err400("invalid_amount");
            }
            long hvFee = 110;
            long hvTotal = hvAmt + hvFee;

            conn = Db.connect();

            boolean wkFound = false;
            long hvZan = 0;
            String hvJou = null;
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT zandaka, joutai FROM kouza WHERE kouza_no = ?")) {
                ps.setLong(1, hvKouza);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        hvZan = rs.getLong(1);
                        hvJou = rs.getString(2);
                        wkFound = true;
                    }
                }
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }
            if (!wkFound) {
                throw CgiError.err404("kouza_not_found");
            }
            if ("9".equals(hvJou)) {
                throw CgiError.err409("account_frozen");
            }
            if (hvZan < hvTotal) {
                throw CgiError.err409("insufficient_funds");
            }

            int wkAiteCnt;
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT COUNT(*) FROM kouza WHERE kouza_no = ?")) {
                ps.setLong(1, hvAite);
                try (ResultSet rs = ps.executeQuery()) {
                    rs.next();
                    wkAiteCnt = (int) rs.getLong(1);
                }
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }

            long hvTid, hvRseq;
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT nextval('seq_torihiki'), nextval('seq_receipt_asis')")) {
                try (ResultSet rs = ps.executeQuery()) {
                    rs.next();
                    hvTid = rs.getLong(1);
                    hvRseq = rs.getLong(2);
                }
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }

            String hvDt = LocalDateTime.now().format(DT14);

            // ===== 원자적 트랜잭션 시작 =====
            hvZan -= hvTotal;
            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE kouza SET zandaka = ? WHERE kouza_no = ?")) {
                ps.setLong(1, hvZan);
                ps.setLong(2, hvKouza);
                ps.executeUpdate();
            } catch (SQLException e) {
                txnAbort(conn);
            }
            try (PreparedStatement ps = conn.prepareStatement("""
                    INSERT INTO torihiki
                      (torihiki_id, kouza_no, torihiki_dt, torihiki_kbn,
                       kingaku, aite_kouza, tesuryo, tekiyou)
                    VALUES (?, ?, ?, '3', ?, ?, ?, NULL)
                    """)) {
                ps.setLong(1, hvTid);
                ps.setLong(2, hvKouza);
                ps.setString(3, hvDt);
                ps.setLong(4, hvAmt);
                ps.setLong(5, hvAite);
                ps.setLong(6, hvFee);
                ps.executeUpdate();
            } catch (SQLException e) {
                txnAbort(conn);
            }
            if (wkAiteCnt > 0) {
                long hvAzan;
                try (PreparedStatement ps = conn.prepareStatement(
                        "SELECT zandaka FROM kouza WHERE kouza_no = ?")) {
                    ps.setLong(1, hvAite);
                    try (ResultSet rs = ps.executeQuery()) {
                        rs.next();
                        hvAzan = rs.getLong(1);
                    }
                } catch (SQLException e) {
                    throw new RuntimeException(e);
                }
                hvAzan += hvAmt;
                try (PreparedStatement ps = conn.prepareStatement(
                        "UPDATE kouza SET zandaka = ? WHERE kouza_no = ?")) {
                    ps.setLong(1, hvAzan);
                    ps.setLong(2, hvAite);
                    ps.executeUpdate();
                } catch (SQLException e) {
                    txnAbort(conn);
                }
                long hvTid2;
                try (PreparedStatement ps = conn.prepareStatement("SELECT nextval('seq_torihiki')")) {
                    try (ResultSet rs = ps.executeQuery()) {
                        rs.next();
                        hvTid2 = rs.getLong(1);
                    }
                } catch (SQLException e) {
                    throw new RuntimeException(e);
                }
                try (PreparedStatement ps = conn.prepareStatement("""
                        INSERT INTO torihiki
                          (torihiki_id, kouza_no, torihiki_dt, torihiki_kbn,
                           kingaku, aite_kouza, tesuryo, tekiyou)
                        VALUES (?, ?, ?, '1', ?, NULL, NULL, NULL)
                        """)) {
                    ps.setLong(1, hvTid2);
                    ps.setLong(2, hvAite);
                    ps.setString(3, hvDt);
                    ps.setLong(4, hvAmt);
                    ps.executeUpdate();
                } catch (SQLException e) {
                    txnAbort(conn);
                }
            }
            try {
                conn.commit();
            } catch (SQLException e) {
                throw new RuntimeException(e);
            }
            // ===== 원자적 트랜잭션 종료 =====
            // HV-ZAN 은 이미 이체 후 잔액(위에서 차감 완료)

            String receipt = makeReceipt(hvDt, hvRseq);
            return buildJson(hvKouza, hvAite, receipt, hvDt, hvZan);
        } finally {
            Db.disconnect(conn);
        }
    }

    /** COBOL TXN-ABORT(named, 여러 지점에서 재사용) — ROLLBACK 후 CgiError. disconnect는 run()의 finally가 담당. */
    private static void txnAbort(Connection conn) {
        try {
            conn.rollback();
        } catch (SQLException ignore) {
            // best-effort, COBOL EXEC SQL ROLLBACK도 결과를 확인하지 않는다.
        }
        throw CgiError.err500("transfer_failed");
    }

    private static String makeReceipt(String hvDt, long hvRseq) {
        long mod = hvRseq % 10000;
        return "WEB" + hvDt.substring(0, 8) + "-" + String.format("%04d", mod);
    }

    private static String buildJson(long hvKouza, long hvAite, String receipt, String hvDt, long hvZan) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\"ok\":true,\"kouza\":\"").append(zpad7(hvKouza))
          .append("\",\"aite\":\"").append(zpad7(hvAite))
          .append("\",\"receipt\":\"").append(receipt)
          .append("\",\"dt\":\"").append(hvDt)
          .append("\",\"fee\":110,\"afterBal\":").append(NumFmt.trim(hvZan))
          .append("}");
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
