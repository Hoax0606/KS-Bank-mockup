package com.ksbank.minibank.strict.online.holdings;

import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** 얇은 어댑터. 실제 로직은 {@link Holdings}(COBOL HOLDINGS.cbl 1:1 포팅)에 위임. */
@RestController
public class HoldingsController {

    @GetMapping(value = "/api/holdings", produces = MediaType.APPLICATION_JSON_VALUE)
    public String holdings(HttpServletRequest req) {
        return new Holdings().run(new CgiRequest(req));
    }
}
