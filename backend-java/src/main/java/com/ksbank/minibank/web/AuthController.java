package com.ksbank.minibank.web;

import java.util.Map;
import com.ksbank.minibank.service.AuthService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** 로그인 엔드포인트. COBOL CGI(LOGIN) + nginx 라우팅 대체. 계약: POST /api/login (branch, acct, pw). */
@RestController
public class AuthController {

    private final AuthService auth;

    public AuthController(AuthService auth) {
        this.auth = auth;
    }

    @PostMapping(value = "/api/login", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> login(@RequestParam String branch,
                                     @RequestParam String acct,
                                     @RequestParam(required = false) String pw) {
        return auth.login(branch, acct, pw);
    }
}
