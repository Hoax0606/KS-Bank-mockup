package com.ksbank.minibank.strict.online.signup;

import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

/** 얇은 어댑터. 실제 로직은 {@link Signup}(COBOL SIGNUP.cbl 1:1 포팅)에 위임. */
@RestController
public class SignupController {

    @PostMapping(value = "/api/signup", produces = MediaType.APPLICATION_JSON_VALUE)
    public String signup(HttpServletRequest req) {
        return new Signup().run(new CgiRequest(req));
    }
}
