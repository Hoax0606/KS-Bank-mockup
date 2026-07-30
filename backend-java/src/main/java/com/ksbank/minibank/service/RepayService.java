package com.ksbank.minibank.service;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;
import com.ksbank.minibank.config.GlobalExceptionHandler.BusinessException;
import com.ksbank.minibank.domain.BalanceRow;
import com.ksbank.minibank.domain.LoanForRepay;
import com.ksbank.minibank.repository.AccountRepository;
import com.ksbank.minibank.repository.LoanRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** ローン返済. COBOL REPAY.cbl 대체. 이자=round(잔액·이율/100/12), 수수료 550, 원자적. */
@Service
public class RepayService {

    private static final String ACTIVE = "ACTIVE";
    private static final String CLOSED = "CLOSED";
    private static final long FEE = 550;

    private final AccountRepository accounts;
    private final LoanRepository loans;

    public RepayService(AccountRepository accounts, LoanRepository loans) {
        this.accounts = accounts;
        this.loans = loans;
    }

    @Transactional
    public Map<String, Object> repay(String loanIdStr, String principalStr) {
        long loanId = parseLong(loanIdStr);
        long prin = parseAmount(principalStr);

        LoanForRepay lf = loans.findForRepay(loanId, ACTIVE)
            .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "loan_not_found"));
        long bal = lf.balance();
        double rate = lf.rate();   // 예: 2.5 (%)
        if (prin > bal) throw new BusinessException(HttpStatus.CONFLICT, "over_balance");

        long interest = Math.round(bal * rate / 100.0 / 12.0);
        long total = prin + interest + FEE;

        int kz = lf.kouzaNo();
        BalanceRow acc = accounts.findBalance(kz).orElseThrow(
            () -> new BusinessException(HttpStatus.INTERNAL_SERVER_ERROR, "repay_failed"));
        long zan = acc.zandaka();
        if (zan < total) throw new BusinessException(HttpStatus.CONFLICT, "insufficient_funds");

        long newBal = bal - prin;
        boolean closed = newBal <= 0;

        accounts.updateBalance(kz, zan - total);
        if (closed) {
            loans.close(loanId, 0, CLOSED, LocalDate.now());
        } else {
            loans.updateBalance(loanId, newBal);
        }
        loans.insertRepay(loans.nextRepayId(), loanId, prin, interest, FEE, total);

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("ok", true);
        res.put("loanId", loanId);
        res.put("principal", prin);
        res.put("interest", interest);
        res.put("fee", FEE);
        res.put("total", total);
        res.put("loanBalance", newBal);
        res.put("closed", closed);
        return res;
    }

    private static long parseLong(String s) {
        try { return Long.parseLong(s == null ? "" : s.replaceAll("[^0-9]", "")); }
        catch (NumberFormatException e) { throw new BusinessException(HttpStatus.BAD_REQUEST, "invalid_loan"); }
    }
    private static long parseAmount(String s) {
        long a;
        try { a = Long.parseLong(s == null ? "" : s.replaceAll("[^0-9]", "")); }
        catch (NumberFormatException e) { throw new BusinessException(HttpStatus.BAD_REQUEST, "invalid_amount"); }
        if (a <= 0) throw new BusinessException(HttpStatus.BAD_REQUEST, "invalid_amount");
        return a;
    }
}
