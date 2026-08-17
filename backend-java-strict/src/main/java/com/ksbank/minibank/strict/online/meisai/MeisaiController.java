package com.ksbank.minibank.strict.online.meisai;

import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** 얇은 어댑터. 실제 로직은 {@link Meisai}(COBOL MEISAI.cbl 1:1 포팅)에 위임. */
@RestController
public class MeisaiController {

    @GetMapping(value = "/api/meisai", produces = MediaType.APPLICATION_JSON_VALUE)
    public String meisai(HttpServletRequest req) {
        return new Meisai().run(new CgiRequest(req));
    }
}
