package com.ksbank.minibank.service;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.Map;
import com.ksbank.minibank.config.GlobalExceptionHandler.BusinessException;
import com.ksbank.minibank.repository.AccountRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** 新規口座開設. COBOL SIGNUP.cbl 대체(동적대역 SEQ_KOUZA_DYN 채번, 2 INSERT 원자적). */
@Service
public class SignupService {

    private static final DateTimeFormatter YMD = DateTimeFormatter.ofPattern("yyyyMMdd");

    private final AccountRepository accounts;

    public SignupService(AccountRepository accounts) {
        this.accounts = accounts;
    }

    @Transactional
    public Map<String, Object> signup(Map<String, String> p) {
        String kanji = nz(p.get("kanji"));
        String pw = nz(p.get("pw"));
        if (kanji.isEmpty() || pw.isEmpty())
            throw new BusinessException(HttpStatus.BAD_REQUEST, "missing_required");

        String kana = nz(p.get("kana"));
        String type = nz(p.get("type")).isEmpty() ? "普通" : nz(p.get("type"));
        String branch = pad3(digits(nz(p.get("branch"))));
        String shubetsu = type.startsWith("当") ? "2" : "1";

        long no = accounts.nextKouzaDyn();
        int kzNo = (int) no;
        String kz = String.format("%07d", no);
        String kaisetsu = LocalDate.now().format(YMD);

        accounts.insertKouza(kzNo, kanji, kana, shubetsu, 0, kaisetsu, "0");
        accounts.insertKouzaExt(kzNo, branch, type, pw, "N");

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("ok", true);
        res.put("kouza", kz);
        res.put("branch", branch);
        res.put("type", type);
        res.put("shubetsu", shubetsu);
        return res;
    }

    private static String nz(String s) { return s == null ? "" : s.trim(); }
    private static String digits(String s) { return s.replaceAll("[^0-9]", ""); }
    private static String pad3(String s) {
        if (s.isEmpty()) return "001";
        return s.length() >= 3 ? s.substring(s.length() - 3) : "0".repeat(3 - s.length()) + s;
    }
}
