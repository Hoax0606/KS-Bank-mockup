package com.ksbank.minibank.repository;

import java.util.List;
import java.util.Optional;
import com.ksbank.minibank.domain.LoanForRepay;
import com.ksbank.minibank.domain.LoanRow;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** LOAN_ASIS / LOAN_REPAY_ASIS 접근. COBOL LOAN.cbl / REPAY.cbl 의 EXEC SQL 대체. */
@Repository
public class LoanRepository {

    private final JdbcTemplate jdbc;

    public LoanRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public long nextLoanId() {
        Long v = jdbc.queryForObject("SELECT nextval('seq_loan_asis')", Long.class);
        return v == null ? 0 : v;
    }
    public long nextRepayId() {
        Long v = jdbc.queryForObject("SELECT nextval('seq_repay_asis')", Long.class);
        return v == null ? 0 : v;
    }

    /** 유효(ACTIVE) 대출 목록. */
    public List<LoanRow> findActive(byte[] kouzaNo, byte[] activeStatus) {
        return jdbc.query("""
            SELECT loan_id, principal, balance, method, term_years
              FROM loan_asis WHERE status = ? AND kouza_no = ? ORDER BY loan_id""",
            ps -> { ps.setBytes(1, activeStatus); ps.setBytes(2, kouzaNo); },
            (rs, i) -> new LoanRow(rs.getBytes(1), rs.getBytes(2), rs.getBytes(3),
                                   rs.getBytes(4), rs.getBytes(5)));
    }

    /** 유효 대출 잔액들(RAW). 여신한도 계산용(합산은 서비스에서 복호). */
    public List<byte[]> activeBalances(byte[] kouzaNo, byte[] activeStatus) {
        return jdbc.query("SELECT balance FROM loan_asis WHERE status = ? AND kouza_no = ?",
            ps -> { ps.setBytes(1, activeStatus); ps.setBytes(2, kouzaNo); },
            (rs, i) -> rs.getBytes(1));
    }

    public void insertLoan(byte[] id, byte[] kouzaNo, byte[] principal, byte[] balance,
                           byte[] method, byte[] termYears, byte[] rate, byte[] status) {
        jdbc.update("""
            INSERT INTO loan_asis (loan_id, kouza_no, principal, balance, method,
                                   term_years, rate, status)
            VALUES (?,?,?,?,?,?,?,?)""", ps -> {
            ps.setBytes(1, id); ps.setBytes(2, kouzaNo); ps.setBytes(3, principal);
            ps.setBytes(4, balance); ps.setBytes(5, method); ps.setBytes(6, termYears);
            ps.setBytes(7, rate); ps.setBytes(8, status);
        });
    }

    /** 返済용: ACTIVE 대출의 잔액/이율/계좌. 없으면 empty. */
    public Optional<LoanForRepay> findForRepay(byte[] loanId, byte[] activeStatus) {
        return jdbc.query("""
            SELECT balance, rate, kouza_no FROM loan_asis
             WHERE loan_id = ? AND status = ?""",
            ps -> { ps.setBytes(1, loanId); ps.setBytes(2, activeStatus); },
            rs -> rs.next()
                ? Optional.of(new LoanForRepay(rs.getBytes(1), rs.getBytes(2), rs.getBytes(3)))
                : Optional.empty());
    }

    public void updateBalance(byte[] loanId, byte[] newBalance) {
        jdbc.update("UPDATE loan_asis SET balance = ? WHERE loan_id = ?",
            ps -> { ps.setBytes(1, newBalance); ps.setBytes(2, loanId); });
    }

    public void close(byte[] loanId, byte[] zeroBalance, byte[] closedStatus, byte[] closedDate) {
        jdbc.update("""
            UPDATE loan_asis SET balance = ?, status = ?, closed_date = ?
             WHERE loan_id = ?""", ps -> {
            ps.setBytes(1, zeroBalance); ps.setBytes(2, closedStatus);
            ps.setBytes(3, closedDate); ps.setBytes(4, loanId);
        });
    }

    public void insertRepay(byte[] repayId, byte[] loanId, byte[] principal,
                            byte[] interest, byte[] fee, byte[] total) {
        jdbc.update("""
            INSERT INTO loan_repay_asis (repay_id, loan_id, principal, interest, fee, total)
            VALUES (?,?,?,?,?,?)""", ps -> {
            ps.setBytes(1, repayId); ps.setBytes(2, loanId); ps.setBytes(3, principal);
            ps.setBytes(4, interest); ps.setBytes(5, fee); ps.setBytes(6, total);
        });
    }
}
