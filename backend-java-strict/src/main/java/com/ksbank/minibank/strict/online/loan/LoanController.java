package com.ksbank.minibank.strict.online.loan;

import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.cgi.CgiResp;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

/**
 * 얇은 어댑터. GET/POST 모두 /api/loan 하나로 매핑하고, COBOL이 한 프로그램 안에서
 * IF CGI-METHOD="POST" 로 분기하듯 {@link LoanServiceImpl#MAIN} 내부에서 분기한다.
 */
@RestController
public class LoanController {

    private final LoanService loanService;

    public LoanController(LoanService loanService) {
        this.loanService = loanService;
    }

    @RequestMapping(value = "/api/loan", method = {RequestMethod.GET, RequestMethod.POST},
                     produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<String> loan(HttpServletRequest req) {
        return CgiResp.ok(loanService.MAIN(new CgiRequest(req)));
    }
}
