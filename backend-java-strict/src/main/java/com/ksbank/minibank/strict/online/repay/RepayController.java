package com.ksbank.minibank.strict.online.repay;

import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

/** 얇은 어댑터. 실제 로직은 {@link Repay}(COBOL REPAY.cbl 1:1 포팅)에 위임. */
@RestController
public class RepayController {

    @PostMapping(value = "/api/repay", produces = MediaType.APPLICATION_JSON_VALUE)
    public String repay(HttpServletRequest req) {
        return new Repay().run(new CgiRequest(req));
    }
}
