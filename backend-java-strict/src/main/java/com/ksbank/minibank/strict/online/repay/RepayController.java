package com.ksbank.minibank.strict.online.repay;

import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.cgi.CgiResp;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

/** 얇은 어댑터. 실제 로직은 {@link RepayServiceImpl}(COBOL REPAY.cbl 1:1 포팅)에 위임. */
@RestController
public class RepayController {

    private final RepayService repayService;

    public RepayController(RepayService repayService) {
        this.repayService = repayService;
    }

    @PostMapping(value = "/api/repay", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<String> repay(HttpServletRequest req) {
        return CgiResp.ok(repayService.MAIN(new CgiRequest(req)));
    }
}
