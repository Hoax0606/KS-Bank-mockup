package com.ksbank.minibank.web;

import java.util.Map;
import com.ksbank.minibank.service.SignupService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** 新規口座開設. 계약: POST /api/signup (kanji, kana, type, branch, pw, 프로필…). */
@RestController
public class SignupController {

    private final SignupService signup;

    public SignupController(SignupService signup) {
        this.signup = signup;
    }

    @PostMapping(value = "/api/signup", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> signup(@RequestParam Map<String, String> params) {
        return signup.signup(params);
    }
}
