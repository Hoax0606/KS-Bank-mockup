package com.ksbank.minibank.service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import com.ksbank.minibank.config.GlobalExceptionHandler.BusinessException;
import com.ksbank.minibank.domain.AccountDetail;
import com.ksbank.minibank.domain.TxnRow;
import com.ksbank.minibank.repository.AccountRepository;
import com.ksbank.minibank.repository.TransactionRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * 取引明細照会. COBOL MEISAI.cbl 대체.
 * 期首残高 = 現残高 - 부호합계 → 오름차순 누적으로 afterBal 확정 → 내림차순 + 필터 출력.
 */
@Service
public class MeisaiService {

    private final AccountRepository accounts;
    private final TransactionRepository txns;

    public MeisaiService(AccountRepository accounts, TransactionRepository txns) {
        this.accounts = accounts;
        this.txns = txns;
    }

    public Map<String, Object> list(String kouza, String kbnFilter, String from, String to) {
        String kz = digits7(kouza);
        int kzNo = Integer.parseInt(kz);
        AccountDetail acc = accounts.findDetail(kzNo)
            .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "kouza_not_found"));
        long current = acc.zandaka();

        List<TxnRow> asc = txns.findByKouza(kzNo); // 시간 오름차순
        int n = asc.size();

        // 부호합계
        String[] dt = new String[n], kbn = new String[n], memo = new String[n];
        long[] kingaku = new long[n], aite = new long[n], delta = new long[n];
        long sum = 0;
        for (int i = 0; i < n; i++) {
            TxnRow r = asc.get(i);
            dt[i] = nz(r.dt());              // 14자리 YYYYMMDDHHMMSS
            kbn[i] = nz(r.kbn());            // "1"/"2"/"3"
            kingaku[i] = r.kingaku();
            long tes = r.tesuryo();
            aite[i] = r.aite();
            memo[i] = nz(r.tekiyou());       // 온라인분 NULL → ""
            delta[i] = delta(kbn[i], kingaku[i], tes);
            sum += delta[i];
        }
        // 期首 → 오름차순 누적 afterBal
        long[] after = new long[n];
        long run = current - sum;
        for (int i = 0; i < n; i++) { run += delta[i]; after[i] = run; }

        String nf = digitsOrEmpty(from), nt = digitsOrEmpty(to);
        String filt = normalizeKbn(kbnFilter);

        // 내림차순 출력 + 필터
        List<Map<String, Object>> rows = new ArrayList<>();
        for (int i = n - 1; i >= 0; i--) {
            if (!"A".equals(filt) && !filt.equals(kbn[i])) continue;
            String d8 = dt[i].length() >= 8 ? dt[i].substring(0, 8) : dt[i];
            if (!nf.isEmpty() && d8.compareTo(nf) < 0) continue;
            if (!nt.isEmpty() && d8.compareTo(nt) > 0) continue;
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("date", d8.length() == 8 ? d8.substring(0,4)+"-"+d8.substring(4,6)+"-"+d8.substring(6,8) : d8);
            row.put("kbn", kbn[i]);
            row.put("kingaku", kingaku[i]);
            row.put("afterBal", after[i]);
            row.put("aite", aite[i]);
            row.put("memo", memo[i]);
            rows.add(row);
        }

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("ok", true);
        res.put("kouza", kz);
        res.put("rows", rows);
        return res;
    }

    /** 区分별 부호: 1=입금(+), 2=출금(-), 3=振込(-(금액+수수료)). */
    private static long delta(String kbn, long kingaku, long tesuryo) {
        return switch (kbn) {
            case "1" -> kingaku;
            case "2" -> -kingaku;
            case "3" -> -(kingaku + tesuryo);
            default -> 0;
        };
    }

    private static String nz(String s) { return s == null ? "" : s; }

    private static String normalizeKbn(String k) {
        if (k == null || k.isBlank() || "all".equalsIgnoreCase(k.trim())) return "A";
        return k.trim().substring(0, 1);
    }
    private static String digitsOrEmpty(String s) {
        return s == null ? "" : s.replaceAll("[^0-9]", "");
    }
    private static String digits7(String s) {
        String d = s == null ? "" : s.replaceAll("[^0-9]", "");
        if (d.isEmpty()) throw new BusinessException(HttpStatus.BAD_REQUEST, "missing_kouza");
        return d.length() >= 7 ? d.substring(d.length() - 7) : "0".repeat(7 - d.length()) + d;
    }
}
