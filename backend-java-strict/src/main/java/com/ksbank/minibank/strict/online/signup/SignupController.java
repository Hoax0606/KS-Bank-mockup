package com.ksbank.minibank.strict.online.signup;

import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.cgi.CgiResp;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class SignupController {

    private final SignupService signupService;

    public SignupController(SignupService signupService) {
        this.signupService = signupService;
    }

    @PostMapping(value = "/api/signup", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<String> signup(HttpServletRequest req) {
        return CgiResp.ok(signupService.MAIN(new CgiRequest(req)));
    }
}
