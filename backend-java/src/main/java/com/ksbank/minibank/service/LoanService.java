package com.ksbank.minibank.service;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import com.ksbank.minibank.config.GlobalExceptionHandler.BusinessException;
import com.ksbank.minibank.domain.BalanceRow;
import com.ksbank.minibank.domain.LoanRow;
import com.ksbank.minibank.repository.AccountRepository;
import com.ksbank.minibank.repository.LoanRepository;
import com.ksbank.minibank.repository.TransactionRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** ローン 조회/실행. COBOL LOAN.cbl 대체(여신한도 300만, 실행=대출+입금+거래 원자적). */
@Service
public class LoanService {

    private static final String ACTIVE = "ACTIVE";
    private static final long LIMIT = 3_000_000;
    private static final double RATE = 2.5;
    private static final DateTimeFormatter DT = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");

    private final AccountRepository accounts;
    private final LoanRepository loans;
    private final TransactionRepository txns;

    public LoanService(AccountRepository accounts, LoanRepository loans, TransactionRepository txns) {
        this.accounts = accounts;
        this.loans = loans;
        this.txns = txns;
    }

    /** GET /api/loan?kouza= */
    public Map<String, Object> list(String kouza) {
        int kz = Integer.parseInt(digits7(kouza));
        List<Map<String, Object>> out = new ArrayList<>();
        for (LoanRow r : loans.findActive(kz, ACTIVE)) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("loanId", r.loanId());
            m.put("principal", r.principal());
            m.put("balance", r.balance());
            m.put("method", r.method());
            m.put("years", r.termYears());
            out.add(m);
        }
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("ok", true);
        res.put("loans", out);
        return res;
    }

    /** POST /api/loan */
    @Transactional
    public Map<String, Object> apply(String kouza, String amtStr, String method, String yearsStr) {
        String kzs = digits7(kouza);
        int kz = Integer.parseInt(kzs);
        long amt = parseAmount(amtStr);
        String m = (method != null && method.matches("^[ABC].*")) ? method.substring(0, 1) : "A";
        int years = (int) parseLongOr(yearsStr, 0);

        long used = 0;
        for (long b : loans.activeBalances(kz, ACTIVE)) used += b;
        if (used + amt > LIMIT) throw new BusinessException(HttpStatus.CONFLICT, "loan_over_limit");
        if (!accounts.exists(kz)) throw new BusinessException(HttpStatus.NOT_FOUND, "kouza_not_found");

        long loanId = loans.nextLoanId();
        long tid = txns.nextTorihikiId();
        String dt = LocalDateTime.now().format(DT);

        loans.insertLoan(loanId, kz, amt, amt, m, years, RATE, ACTIVE);

        BalanceRow acc = accounts.findBalance(kz).orElseThrow(
            () -> new BusinessException(HttpStatus.INTERNAL_SERVER_ERROR, "loan_failed"));
        long bal = acc.zandaka();
        accounts.updateBalance(kz, bal + amt);
        txns.insert(tid, kz, dt, "1", amt, null, null);

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("ok", true);
        res.put("loanId", loanId);
        res.put("kouza", kzs);
        res.put("amount", amt);
        return res;
    }

    private static String digits7(String s) {
        String d = s == null ? "" : s.replaceAll("[^0-9]", "");
        if (d.isEmpty()) throw new BusinessException(HttpStatus.BAD_REQUEST, "missing_kouza");
        return d.length() >= 7 ? d.substring(d.length() - 7) : "0".repeat(7 - d.length()) + d;
    }
    private static long parseAmount(String s) {
        long a;
        try { a = Long.parseLong(s == null ? "" : s.replaceAll("[^0-9]", "")); }
        catch (NumberFormatException e) { throw new BusinessException(HttpStatus.BAD_REQUEST, "invalid_amount"); }
        if (a <= 0) throw new BusinessException(HttpStatus.BAD_REQUEST, "invalid_amount");
        return a;
    }
    private static long parseLongOr(String s, long def) {
        try { return Long.parseLong(s == null ? "" : s.replaceAll("[^0-9]", "")); }
        catch (NumberFormatException e) { return def; }
    }
}
