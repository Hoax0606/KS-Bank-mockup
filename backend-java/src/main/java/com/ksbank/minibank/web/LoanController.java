package com.ksbank.minibank.web;

import java.util.Map;
import com.ksbank.minibank.service.LoanService;
import com.ksbank.minibank.service.RepayService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** ローン: GET/POST /api/loan, 返済 POST /api/repay. */
@RestController
public class LoanController {

    private final LoanService loans;
    private final RepayService repay;

    public LoanController(LoanService loans, RepayService repay) {
        this.loans = loans;
        this.repay = repay;
    }

    @GetMapping(value = "/api/loan", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> list(@RequestParam(required = false) String kouza) {
        return loans.list(kouza);
    }

    @PostMapping(value = "/api/loan", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> apply(@RequestParam(required = false) String kouza,
                                     @RequestParam(required = false) String amt,
                                     @RequestParam(required = false) String method,
                                     @RequestParam(required = false) String years) {
        return loans.apply(kouza, amt, method, years);
    }

    @PostMapping(value = "/api/repay", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> repay(@RequestParam(required = false) String loanId,
                                     @RequestParam(required = false) String principal) {
        return repay.repay(loanId, principal);
    }
}
