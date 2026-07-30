package com.ksbank.minibank.batch;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import com.ksbank.minibank.domain.AcctAgg;
import com.ksbank.minibank.domain.TxnAgg;
import com.ksbank.minibank.repository.AccountRepository;
import com.ksbank.minibank.repository.ReportRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 日次夜間バッチ. COBOL run_batch.sh(10스텝) 이식.
 *   SORTDAT/SORTRPT(SORT)는 SQL ORDER BY로 흡수 → 실질 잡 = posting + 帳票 6종.
 *   posting(YAKANBAT 옵션1): 당일거래 있는 普通계좌에만 일일이자(floor(잔액/365000)) 가산.
 *   帳票: 取引日報/残高一覧/手数料集計/休眠/マスタ一覧/統計.
 */
@Service
public class BatchService {

    private static final long INTEREST_DIV = 365000; // floor(잔액/365000) = 普通 일일이자(결정타1)

    private final ReportRepository reports;
    private final AccountRepository accounts;

    public BatchService(ReportRepository reports, AccountRepository accounts) {
        this.reports = reports;
        this.accounts = accounts;
    }

    @Transactional
    public Map<String, Object> runAll() {
        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("ok", true);
        summary.put("posting", posting());   // 3. YAKANBAT
        summary.put("nippo", dailyTxnReport());     // 5
        summary.put("zandaka", balanceList());      // 6
        summary.put("tesuryo", feeSummary());       // 7
        summary.put("kyumin", dormant());           // 8
        summary.put("master", masterList());        // 9
        summary.put("tokei", stats());              // 10
        return summary;
    }

    /** 3. YAKANBAT: 普通 + 당일거래 계좌에 일일이자 가산. */
    private Map<String, Object> posting() {
        long posted = 0, interestTotal = 0;
        for (AcctAgg a : reports.allAccounts()) {
            if (!"1".equals(a.shubetsu())) continue;      // 普通만
            if (!reports.hasTxn(a.kouzaNo())) continue;   // 당일거래 있는 계좌만
            long bal = a.zandaka();
            long interest = bal / INTEREST_DIV;
            if (interest <= 0) continue;
            accounts.updateBalance(a.kouzaNo(), bal + interest);
            posted++;
            interestTotal += interest;
        }
        return Map.of("accountsPosted", posted, "interestTotal", interestTotal);
    }

    /** 5. NIPPOBAT: 区分별 건수·금액. */
    private Map<String, Object> dailyTxnReport() {
        long[] cnt = new long[4], sum = new long[4];
        for (TxnAgg t : reports.allTxns()) {
            int k = kbnIndex(t.kbn());
            cnt[k]++;
            sum[k] += t.kingaku();
        }
        Map<String, Object> m = new LinkedHashMap<>();
        for (int k = 1; k <= 3; k++) m.put("kbn" + k, Map.of("count", cnt[k], "sum", sum[k]));
        return m;
    }

    /** 6. ZANDABAT: 잔액일람(계좌수·총잔액 + 목록). */
    private Map<String, Object> balanceList() {
        List<Map<String, Object>> rows = new ArrayList<>();
        long total = 0;
        for (AcctAgg a : reports.allAccounts()) {
            long bal = a.zandaka();
            total += bal;
            rows.add(Map.of("kouza", (long) a.kouzaNo(), "zandaka", bal));
        }
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("count", rows.size());
        m.put("totalBalance", total);
        m.put("rows", rows);
        return m;
    }

    /** 7. TESUBAT: 手数料 집계. */
    private Map<String, Object> feeSummary() {
        long cnt = 0, total = 0;
        for (TxnAgg t : reports.allTxns()) {
            if (t.tesuryo() == null) continue;
            cnt++;
            total += t.tesuryo();
        }
        return Map.of("count", cnt, "total", total);
    }

    /** 8. KYUMBAT: 무거래(휴면) 계좌. */
    private List<Long> dormant() {
        return new ArrayList<>(reports.dormantAccounts());
    }

    /** 9. MASTBAT: 계좌 마스터 일람. */
    private List<Map<String, Object>> masterList() {
        List<Map<String, Object>> rows = new ArrayList<>();
        for (AcctAgg a : reports.allAccounts()) {
            Map<String, Object> r = new LinkedHashMap<>();
            r.put("kouza", (long) a.kouzaNo());
            r.put("shubetsu", a.shubetsu());
            r.put("joutai", a.joutai());
            r.put("kaisetsu", a.kaisetsu());
            r.put("zandaka", a.zandaka());
            rows.add(r);
        }
        return rows;
    }

    /** 10. TOKEBAT: 통계 서머리. */
    private Map<String, Object> stats() {
        long accts = 0, futsu = 0, touza = 0, frozen = 0, totalBal = 0;
        for (AcctAgg a : reports.allAccounts()) {
            accts++;
            String shu = a.shubetsu();
            if ("1".equals(shu)) futsu++;
            if ("2".equals(shu)) touza++;
            if ("9".equals(a.joutai())) frozen++;
            totalBal += a.zandaka();
        }
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("accounts", accts);
        m.put("futsu", futsu);
        m.put("touza", touza);
        m.put("frozen", frozen);
        m.put("totalBalance", totalBal);
        m.put("txnCount", reports.txnCount());
        return m;
    }

    private static int kbnIndex(String kbn) {
        return switch (kbn) { case "1" -> 1; case "2" -> 2; case "3" -> 3; default -> 0; };
    }
}
