package com.ksbank.minibank.service;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.Map;
import com.ksbank.minibank.codec.Enc;
import com.ksbank.minibank.codec.JefCodec;
import com.ksbank.minibank.codec.PackedDecimalCodec;
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

    private static final byte[] ACTIVE = JefCodec.encode("ACTIVE");
    private static final byte[] CLOSED = JefCodec.encode("CLOSED");
    private static final long FEE = 550;
    private static final DateTimeFormatter YMD = DateTimeFormatter.ofPattern("yyyyMMdd");

    private final AccountRepository accounts;
    private final LoanRepository loans;

    public RepayService(AccountRepository accounts, LoanRepository loans) {
        this.accounts = accounts;
        this.loans = loans;
    }

    @Transactional
    public Map<String, Object> repay(String loanIdStr, String principalStr) {
        long loanId = parseLong(loanIdStr);
        byte[] lid = Enc.key(loanId, 12);
        long prin = parseAmount(principalStr);

        LoanForRepay lf = loans.findForRepay(lid, ACTIVE)
            .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "loan_not_found"));
        long bal = lf.balance() == null ? 0 : PackedDecimalCodec.decode(lf.balance());
        double rate = (lf.rate() == null ? 0 : PackedDecimalCodec.decode(lf.rate())) / 1000.0;
        if (prin > bal) throw new BusinessException(HttpStatus.CONFLICT, "over_balance");

        long interest = Math.round(bal * rate / 100.0 / 12.0);
        long total = prin + interest + FEE;

        byte[] kz = lf.kouzaNo();
        BalanceRow acc = accounts.findBalance(kz).orElseThrow(
            () -> new BusinessException(HttpStatus.INTERNAL_SERVER_ERROR, "repay_failed"));
        long zan = acc.zandaka() == null ? 0 : PackedDecimalCodec.decode(acc.zandaka());
        if (zan < total) throw new BusinessException(HttpStatus.CONFLICT, "insufficient_funds");

        long newBal = bal - prin;
        boolean closed = newBal <= 0;

        accounts.updateBalance(kz, Enc.amount(zan - total));
        if (closed) {
            loans.close(lid, Enc.amount(0), CLOSED, Enc.key(LocalDate.now().format(YMD)));
        } else {
            loans.updateBalance(lid, Enc.amount(newBal));
        }
        loans.insertRepay(Enc.key(loans.nextRepayId(), 15), lid,
            Enc.amount(prin), Enc.amount(interest), Enc.amount(FEE), Enc.amount(total));

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
