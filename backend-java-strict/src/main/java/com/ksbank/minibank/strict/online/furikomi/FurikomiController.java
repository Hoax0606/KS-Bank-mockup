package com.ksbank.minibank.strict.online.furikomi;

import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

/** 얇은 어댑터. 실제 로직은 {@link Furikomi}(COBOL FURIKOMI.cbl 1:1 포팅)에 위임. */
@RestController
public class FurikomiController {

    @PostMapping(value = "/api/furikomi", produces = MediaType.APPLICATION_JSON_VALUE)
    public String furikomi(HttpServletRequest req) {
        return new Furikomi().run(new CgiRequest(req));
    }
}
