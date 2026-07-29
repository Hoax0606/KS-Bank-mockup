package com.ksbank.minibank.service;

import java.util.LinkedHashMap;
import java.util.Map;
import com.ksbank.minibank.codec.JefCodec;
import com.ksbank.minibank.codec.PackedDecimalCodec;
import com.ksbank.minibank.codec.ZonedDecimalCodec;
import com.ksbank.minibank.config.GlobalExceptionHandler.BusinessException;
import com.ksbank.minibank.domain.AccountRow;
import com.ksbank.minibank.repository.AccountRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * 로그인 업무 로직. COBOL LOGIN.cbl 대체.
 * 입력을 RAW 인코딩(店番/口座=존10진, PW=JEF)해 조회, 결과를 디코딩해 UTF-8 응답 구성.
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

        // 店番/口座 = 존10진(숫자), PW = JEF EBCDIC (영숫자 혼재)
        byte[] branchRaw = ZonedDecimalCodec.encode(br);
        byte[] kouzaRaw  = ZonedDecimalCodec.encode(kz);
        byte[] pwRaw     = JefCodec.encode(pw);

        AccountRow r = accounts.findForLogin(kouzaRaw, branchRaw, pwRaw)
            .orElseThrow(AuthService::invalid);

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("ok", true);
        res.put("kouza", kz);
        res.put("branch", br);
        res.put("meigiKanji", name(r));
        res.put("shubetsu", ZonedDecimalCodec.decode(r.shubetsu()));   // "1"/"2"
        res.put("type", JefCodec.decode(r.acctType()));                // 普通/当座
        res.put("joutai", ZonedDecimalCodec.decode(r.joutai()));       // "0"/"9"
        res.put("zandaka", r.zandaka() == null ? 0L : PackedDecimalCodec.decode(r.zandaka()));
        return res;
    }

    /** 명의: JEF RAW 디코드가 정본, 실패/공백이면 UTF-8 미러 폴백(COBOL RAWUTF8 방침). */
    private static String name(AccountRow r) {
        try {
            String s = JefCodec.decode(r.meigiKanji());
            if (s != null && !s.isBlank()) return s;
        } catch (RuntimeException ignore) { /* 미매핑 등 → 미러 */ }
        return r.kanjiMirror() == null ? "" : r.kanjiMirror();
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
