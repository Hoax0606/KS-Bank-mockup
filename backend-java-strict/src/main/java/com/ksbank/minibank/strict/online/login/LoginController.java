package com.ksbank.minibank.strict.online.login;

import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.cgi.CgiResp;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class LoginController {

    private final LoginService loginService;

    public LoginController(LoginService loginService) {
        this.loginService = loginService;
    }

    @PostMapping(value = "/api/login", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<String> login(HttpServletRequest req) {
        return CgiResp.ok(loginService.MAIN(new CgiRequest(req)));
    }
}
