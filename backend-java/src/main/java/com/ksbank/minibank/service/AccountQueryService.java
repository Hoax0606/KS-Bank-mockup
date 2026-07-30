package com.ksbank.minibank.service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import com.ksbank.minibank.config.GlobalExceptionHandler.BusinessException;
import com.ksbank.minibank.domain.AccountDetail;
import com.ksbank.minibank.repository.AccountRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/** 残高照会(zandaka) + 保有口座(holdings). COBOL ZANDAKA.cbl / HOLDINGS.cbl 대체. */
@Service
public class AccountQueryService {

    private final AccountRepository accounts;

    public AccountQueryService(AccountRepository accounts) {
        this.accounts = accounts;
    }

    /** GET /api/zandaka */
    public Map<String, Object> zandaka(String kouza) {
        String kz = digits7(kouza);
        AccountDetail a = detail(kz);
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("ok", true);
        m.put("kouza", kz);
        m.put("meigiKanji", nz(a.meigiKanji()));
        m.put("meigiKana", nz(a.meigiKana()));
        m.put("shubetsu", nz(a.shubetsu()));
        m.put("zandaka", a.zandaka());
        m.put("joutai", nz(a.joutai()));
        return m;
    }

    /** GET /api/holdings — 지정 계좌를 1요소 배열로. */
    public Map<String, Object> holdings(String kouza) {
        String kz = digits7(kouza);
        AccountDetail a = detail(kz);
        Map<String, Object> h = new LinkedHashMap<>();
        h.put("kouza", kz);
        h.put("branch", nz(a.branchCode()));
        h.put("meigiKanji", nz(a.meigiKanji()));
        h.put("shubetsu", nz(a.shubetsu()));
        h.put("type", nz(a.acctType()));
        h.put("joutai", nz(a.joutai()));
        h.put("isPrimary", nz(a.isPrimary()));   // "Y"/"N"
        h.put("zandaka", a.zandaka());
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("ok", true);
        m.put("holdings", List.of(h));
        return m;
    }

    private AccountDetail detail(String kz) {
        return accounts.findDetail(Integer.parseInt(kz))
            .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "kouza_not_found"));
    }

    private static String nz(String s) { return s == null ? "" : s; }

    private static String digits7(String s) {
        String d = s == null ? "" : s.replaceAll("[^0-9]", "");
        if (d.isEmpty()) throw new BusinessException(HttpStatus.BAD_REQUEST, "missing_kouza");
        return d.length() >= 7 ? d.substring(d.length() - 7) : "0".repeat(7 - d.length()) + d;
    }
}
