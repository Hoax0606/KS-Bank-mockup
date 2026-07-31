package com.ksbank.minibank.repository;

import java.time.LocalDate;
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
    public List<LoanRow> findActive(int kouzaNo, String activeStatus) {
        return jdbc.query("""
            SELECT loan_id, principal, balance, method, term_years
              FROM loan_asis WHERE status = ? AND kouza_no = ? ORDER BY loan_id""",
            ps -> { ps.setString(1, activeStatus); ps.setInt(2, kouzaNo); },
            (rs, i) -> new LoanRow(rs.getLong(1), rs.getLong(2), rs.getLong(3),
                                   rs.getString(4), rs.getInt(5)));
    }

    /** 유효 대출 잔액들. 여신한도 계산용(합산은 서비스에서). */
    public List<Long> activeBalances(int kouzaNo, String activeStatus) {
        return jdbc.query("SELECT balance FROM loan_asis WHERE status = ? AND kouza_no = ?",
            ps -> { ps.setString(1, activeStatus); ps.setInt(2, kouzaNo); },
            (rs, i) -> rs.getLong(1));
    }

    public void insertLoan(long id, int kouzaNo, long principal, long balance,
                           String method, int termYears, double rate, String status) {
        jdbc.update("""
            INSERT INTO loan_asis (loan_id, kouza_no, principal, balance, method,
                                   term_years, rate, status)
            VALUES (?,?,?,?,?,?,?,?)""", ps -> {
            ps.setLong(1, id); ps.setInt(2, kouzaNo); ps.setLong(3, principal);
            ps.setLong(4, balance); ps.setString(5, method); ps.setInt(6, termYears);
            ps.setDouble(7, rate); ps.setString(8, status);
        });
    }

    /** 返済용: ACTIVE 대출의 잔액/이율/계좌. 없으면 empty. */
    public Optional<LoanForRepay> findForRepay(long loanId, String activeStatus) {
        return jdbc.query("""
            SELECT balance, rate, kouza_no FROM loan_asis
             WHERE loan_id = ? AND status = ?""",
            ps -> { ps.setLong(1, loanId); ps.setString(2, activeStatus); },
            rs -> rs.next()
                ? Optional.of(new LoanForRepay(rs.getLong(1), rs.getDouble(2), rs.getInt(3)))
                : Optional.empty());
    }

    public void updateBalance(long loanId, long newBalance) {
        jdbc.update("UPDATE loan_asis SET balance = ? WHERE loan_id = ?",
            ps -> { ps.setLong(1, newBalance); ps.setLong(2, loanId); });
    }

    public void close(long loanId, long zeroBalance, String closedStatus, LocalDate closedDate) {
        jdbc.update("""
            UPDATE loan_asis SET balance = ?, status = ?, closed_date = ?
             WHERE loan_id = ?""", ps -> {
            ps.setLong(1, zeroBalance); ps.setString(2, closedStatus);
            ps.setObject(3, closedDate); ps.setLong(4, loanId);
        });
    }

    public void insertRepay(long repayId, long loanId, long principal,
                            long interest, long fee, long total) {
        jdbc.update("""
            INSERT INTO loan_repay_asis (repay_id, loan_id, principal, interest, fee, total)
            VALUES (?,?,?,?,?,?)""", ps -> {
            ps.setLong(1, repayId); ps.setLong(2, loanId); ps.setLong(3, principal);
            ps.setLong(4, interest); ps.setLong(5, fee); ps.setLong(6, total);
        });
    }
}
