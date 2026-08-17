package com.ksbank.minibank.strict.online.login;

import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

/** 얇은 어댑터. 실제 로직은 {@link Login}(COBOL LOGIN.cbl 1:1 포팅)에 위임. */
@RestController
public class LoginController {

    @PostMapping(value = "/api/login", produces = MediaType.APPLICATION_JSON_VALUE)
    public String login(HttpServletRequest req) {
        return new Login().run(new CgiRequest(req));
    }
}
