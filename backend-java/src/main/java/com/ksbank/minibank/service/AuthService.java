package com.ksbank.minibank.service;

import java.util.LinkedHashMap;
import java.util.Map;
import com.ksbank.minibank.config.GlobalExceptionHandler.BusinessException;
import com.ksbank.minibank.domain.AccountRow;
import com.ksbank.minibank.repository.AccountRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * 로그인 업무 로직. COBOL LOGIN.cbl 대체.
 * 店番/口座/PW 로 조회 후 결과를 UTF-8 응답으로 구성(일반 타입).
 */
@Service
public class AuthService {

    private final AccountRepository accounts;

    public AuthService(AccountRepository accounts) {
        this.accounts = accounts;
    }

    public Map<String, Object> login(String branch, String acct, String pw) {
        String br = leftPad(digits(branch), 3);   // "001"
        String kz = leftPad(digits(acct), 7);     // "1000123"
        if (pw == null || pw.isEmpty() || kz.isBlank()) throw invalid();

        AccountRow r = accounts.findForLogin(Integer.parseInt(kz), br, pw)
            .orElseThrow(AuthService::invalid);

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("ok", true);
        res.put("kouza", kz);
        res.put("branch", br);
        res.put("meigiKanji", r.meigiKanji() == null ? "" : r.meigiKanji());
        res.put("shubetsu", r.shubetsu());   // "1"/"2"
        res.put("type", r.acctType());       // 普通/当座
        res.put("joutai", r.joutai());       // "0"/"9"
        res.put("zandaka", r.zandaka());
        return res;
    }

    private static BusinessException invalid() {
        return new BusinessException(HttpStatus.CONFLICT, "invalid_login");
    }

    private static String digits(String s) {
        return s == null ? "" : s.replaceAll("[^0-9]", "");
    }
    private static String leftPad(String s, int len) {
        if (s.length() >= len) return s.substring(s.length() - len);
        return "0".repeat(len - s.length()) + s;
    }
}
