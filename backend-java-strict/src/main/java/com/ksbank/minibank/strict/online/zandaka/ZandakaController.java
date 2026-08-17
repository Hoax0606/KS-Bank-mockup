package com.ksbank.minibank.strict.online.zandaka;

import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** 얇은 어댑터. 실제 로직은 {@link Zandaka}(COBOL ZANDAKA.cbl 1:1 포팅)에 위임. */
@RestController
public class ZandakaController {

    @GetMapping(value = "/api/zandaka", produces = MediaType.APPLICATION_JSON_VALUE)
    public String zandaka(HttpServletRequest req) {
        return new Zandaka().run(new CgiRequest(req));
    }
}
