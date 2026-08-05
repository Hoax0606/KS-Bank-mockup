package com.ksbank.minibank.batch;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import com.ksbank.minibank.batch.report.JsonRenderer;
import com.ksbank.minibank.batch.report.ReportWriter;
import com.ksbank.minibank.domain.AcctAgg;
import com.ksbank.minibank.domain.BatchTxn;
import com.ksbank.minibank.domain.TxnAgg;
import com.ksbank.minibank.repository.AccountRepository;
import com.ksbank.minibank.repository.ReportRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 日次夜間バッチ. COBOL {@code run_batch.sh}(10스텝) 이식.
 *
 * <pre>
 *   1 MKDAT   + 2 SORTDAT  → ReportRepository.allTxnsForBatch() 의 ORDER BY 로 흡수
 *   3 YAKANBAT + 4 SORTRPT → MeisaiBuilder (明細 D/T + 일일이자)
 *   5..10                  → 帳票 6종 (取引日報/残高一覧/手数料集計/休眠/マスタ一覧/統計)
 * </pre>
 *
 * 구조는 <b>compute → apply → render</b>. 한 번 계산해 JSON과 파일 7종으로 각각 렌더링한다.
 */
@Service
public class BatchService {

    private final ReportRepository reports;
    private final AccountRepository accounts;
    private final ReportWriter writer;

    public BatchService(ReportRepository reports, AccountRepository accounts,
                        ReportWriter writer) {
        this.reports = reports;
        this.accounts = accounts;
        this.writer = writer;
    }

    /**
     * 배치 실행 진입점. 응답 JSON 을 돌려주고, 부수효과로 帳票 7종을 파일로 쓴다.
     *
     * <p>트랜잭션 경계는 <b>이 메서드 하나</b>다. {@link #run()} 에 {@code @Transactional} 을 달아
     * 여기서 호출하면 self-invocation 으로 프록시를 우회해 트랜잭션이 시작되지 않으므로,
     * 애너테이션은 외부에서 호출되는 이 메서드에만 붙인다.
     */
    @Transactional
    public Map<String, Object> runAll() {
        BatchResult r = run();
        writer.write(r);
        return JsonRenderer.render(r);
    }

    /** 계산 + 잔액 반영. 트랜잭션은 {@link #runAll()} 이 관리한다. */
    BatchResult run() {
        // --- 1 MKDAT / 2 SORTDAT --------------------------------------------
        //  明細은 posting "이전" 잔액을 봐야 한다 (YAKANBAT START-ACCT 의 ACC-BAL)
        List<AcctAgg> before = reports.allAccounts();
        List<BatchTxn> txns = reports.allTxnsForBatch();

        // --- 3 YAKANBAT / 4 SORTRPT -----------------------------------------
        MeisaiBuilder.Result m = MeisaiBuilder.build(before, txns);
        for (long[] u : m.balanceUpdates()) {
            accounts.updateBalance((int) u[0], u[1]);
        }

        // --- 5..10 帳票 ------------------------------------------------------
        //  COBOL 5-10 은 YAKANBAT 이 COMMIT 한 뒤의 별 프로세스이므로 갱신 후 잔액을 읽는다
        List<AcctAgg> after = reports.allAccounts();
        List<TxnAgg> allTxns = reports.allTxns();

        return new BatchResult(
                m.accountsPosted(), m.interestTotal(), m.accountsWithTxn(), m.records(),
                dailyTxnReport(allTxns),          // 5  NIPPOBAT
                balanceList(after),               // 6  ZANDABAT
                feeSummary(allTxns),              // 7  TESUBAT
                reports.dormantAccounts(),        // 8  KYUMBAT
                masterList(after),                // 9  MASTBAT
                stats(after));                    // 10 TOKEBAT
    }

    /** 5. NIPPOBAT: 区分별 건수·금액. */
    private static BatchResult.Nippo dailyTxnReport(List<TxnAgg> txns) {
        long[] cnt = new long[4], sum = new long[4];
        for (TxnAgg t : txns) {
            int k = kbnIndex(t.kbn());
            cnt[k]++;
            sum[k] += t.kingaku();
        }
        return new BatchResult.Nippo(cnt, sum);
    }

    /** 6. ZANDABAT: 잔액일람(계좌수·총잔액 + 목록). */
    private static BatchResult.Zandaka balanceList(List<AcctAgg> accts) {
        List<BatchResult.ZandakaRow> rows = new ArrayList<>();
        long total = 0;
        for (AcctAgg a : accts) {
            total += a.zandaka();
            rows.add(new BatchResult.ZandakaRow(a.kouzaNo(), a.shubetsu(), a.joutai(),
                                                a.zandaka()));
        }
        return new BatchResult.Zandaka(rows, total);
    }

    /**
     * 7. TESUBAT: 手数料 집계.
     * ★{@code WHERE TESURYO IS NOT NULL} — 区分 무관 전건이다.
     * 明細 T레코드의 {@code 手数料合計}(区分3만)와는 <b>의도적으로 다른 집계</b>다.
     */
    private static BatchResult.Tesuryo feeSummary(List<TxnAgg> txns) {
        long cnt = 0, total = 0;
        for (TxnAgg t : txns) {
            if (t.tesuryo() == null) continue;
            cnt++;
            total += t.tesuryo();
        }
        return new BatchResult.Tesuryo(cnt, total);
    }

    /** 9. MASTBAT: 계좌 마스터 일람. */
    private static List<BatchResult.MasterRow> masterList(List<AcctAgg> accts) {
        List<BatchResult.MasterRow> rows = new ArrayList<>();
        for (AcctAgg a : accts) {
            rows.add(new BatchResult.MasterRow(a.kouzaNo(), a.shubetsu(), a.joutai(),
                                               a.kaisetsu(), a.zandaka()));
        }
        return rows;
    }

    /** 10. TOKEBAT: 통계 서머리. */
    private BatchResult.Tokei stats(List<AcctAgg> accts) {
        long n = 0, futsu = 0, touza = 0, frozen = 0, totalBal = 0;
        for (AcctAgg a : accts) {
            n++;
            if ("1".equals(a.shubetsu())) futsu++;
            if ("2".equals(a.shubetsu())) touza++;
            if ("9".equals(a.joutai())) frozen++;
            totalBal += a.zandaka();
        }
        return new BatchResult.Tokei(n, futsu, touza, frozen, totalBal, reports.txnCount());
    }

    private static int kbnIndex(String kbn) {
        if (kbn == null) return 0;
        return switch (kbn) { case "1" -> 1; case "2" -> 2; case "3" -> 3; default -> 0; };
    }
}
