package com.ksbank.minibank.batch;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import com.ksbank.minibank.domain.AcctAgg;
import com.ksbank.minibank.domain.BatchTxn;
import com.ksbank.minibank.domain.MeisaiRec;
import com.ksbank.minibank.domain.TxnDelta;

/**
 * 明細帳票 생성 + 일일이자 산출. COBOL {@code YAKANBAT.cbl}(3단계) + {@code SORTRPT.cbl}(4단계) 이식.
 *
 * <p><b>순수 함수</b>다 — DB/Spring 의존이 없어 컨테이너 없이 단위테스트할 수 있다.
 * 잔액 갱신은 하지 않고 {@link Result#balanceUpdates()} 로 돌려주며, 적용은 호출측
 * ({@link BatchService}) 책임이다.
 *
 * <p>COBOL 대응:
 * <ul>
 *   <li>{@code PROCESS-SORTED} — 거래 스트림에 대한 control break</li>
 *   <li>{@code START-ACCT} — 계좌 마스터에서 배치 전 잔액/명의/종별 취득</li>
 *   <li>{@code APPLY-TXN} / {@code CALC-DELTA} — 증감 누적 + 수수료 누적</li>
 *   <li>{@code BREAK-ACCT} — 期首 역산, 이자 계산, D/T 레코드 생성</li>
 *   <li>{@code RELEASE-RPTW-*} + {@code SORTRPT} — カナ+SEQ 정렬</li>
 * </ul>
 *
 * <p>⚠️ <b>계좌 목록을 순회하지 않고 거래 스트림을 순회한다.</b> COBOL은
 * {@code TORIHIKI.SORTED}(=거래 파일)를 읽으므로 거래가 없는 계좌는 明細도 T레코드도
 * 만들지 않고 잔액 UPDATE 대상도 아니다. 계좌를 순회하는 구현으로 바꾸면 이 동작이 깨진다.
 */
public final class MeisaiBuilder {

    /** 普通예금 일일이자 제수. {@code FUNCTION INTEGER-PART(残高 / 365000)}. */
    static final long INTEREST_DIV = 365_000L;

    private MeisaiBuilder() {}

    /**
     * @param records        カナ순 정렬이 끝난 明細(D/T) 전건
     * @param balanceUpdates {@code {kouzaNo, newBal}} — COBOL이 UPDATE 하는 계좌 전부
     *                       (当座·이자0 포함. 값이 안 바뀌는 계좌도 포함된다)
     * @param accountsWithTxn 거래가 있는 계좌수 = T레코드 수 = COBOL UPDATE 횟수
     * @param accountsPosted  이자가 실제로 가산된(이자>0) 계좌수 — 기존 JSON 키 의미 유지
     * @param interestTotal   가산된 이자 총액
     */
    public record Result(List<MeisaiRec> records,
                         List<long[]> balanceUpdates,
                         long accountsWithTxn,
                         long accountsPosted,
                         long interestTotal) {}

    /**
     * @param accounts 계좌 마스터 — <b>posting 이전</b> 잔액이어야 한다({@code START-ACCT} 의 {@code ACC-BAL})
     * @param txns     거래 전건 — <b>{@code (kouzaNo, torihikiId)} 순</b>이어야 한다(MKDAT + SORTDAT)
     */
    public static Result build(List<AcctAgg> accounts, List<BatchTxn> txns) {
        Map<Integer, AcctAgg> master = new HashMap<>();
        for (AcctAgg a : accounts) master.put(a.kouzaNo(), a);

        List<MeisaiRec> recs = new ArrayList<>();
        List<long[]> updates = new ArrayList<>();
        Counters c = new Counters();

        int i = 0;
        while (i < txns.size()) {
            int kouzaNo = txns.get(i).kouzaNo();
            int from = i;
            while (i < txns.size() && txns.get(i).kouzaNo() == kouzaNo) i++;   // control break
            breakAcct(master.get(kouzaNo), kouzaNo, txns.subList(from, i), recs, updates, c);
        }

        recs.sort(Comparator.comparing(MeisaiRec::sortKey, KanaSortKey.ORDER)
                            .thenComparingInt(MeisaiRec::seq));
        return new Result(recs, updates, c.accountsWithTxn, c.accountsPosted, c.interestTotal);
    }

    /** COBOL {@code START-ACCT} + {@code APPLY-TXN} + {@code BREAK-ACCT} 를 한 계좌분 수행. */
    private static void breakAcct(AcctAgg acct, int kouzaNo, List<BatchTxn> txns,
                                  List<MeisaiRec> recs, List<long[]> updates, Counters c) {
        // START-ACCT: 마스터에 없으면 COBOL 의 WARN 경로와 동형(명의 공백, 종별 1, 잔액 0)
        String kanji = acct == null ? "" : nz(acct.meigiKanji());
        String kana  = acct == null ? "" : nz(acct.meigiKana());
        String shu   = acct == null ? "1" : acct.shubetsu();
        long accBal  = acct == null ? 0L : acct.zandaka();          // ACC-BAL (배치 전 잔액)

        // APPLY-TXN / CALC-DELTA
        long[] deltas = new long[txns.size()];
        long accTd = 0;                                             // ACC-TD  당일증감 합계
        long accFee = 0;                                            // ACC-FEE 手数料合計
        for (int k = 0; k < txns.size(); k++) {
            BatchTxn t = txns.get(k);
            deltas[k] = TxnDelta.of(t.kbn(), t.kingaku(), t.tesuryo());
            accTd += deltas[k];
            // ★ kbn=='3'(振込) 게이트. "tesuryo != null" 게이트로 바꾸면 区分1/2 에 붙은
            //   수수료가 MT-TESURYO-GK 에 섞인다. TESUBAT 은 반대로 non-null 전부를 세므로
            //   두 합계는 의도적으로 다른 집계다(COBOL도 동일).
            if ("3".equals(t.kbn())) accFee += t.tesuryo();
        }

        // BREAK-ACCT
        long accOpen = accBal - accTd;                              // ACC-OPEN 期首
        long accInt = ("1".equals(shu) && accBal > 0)               // ACC-INT 普通 && 残高>0
                ? accBal / INTEREST_DIV                             // 양수 long 나눗셈 = INTEGER-PART
                : 0;
        long accNew = accBal + accInt;                              // ACC-NEW 確定残高

        // COBOL 은 파일에 있는 계좌를 무조건 UPDATE 한다(当座·이자0 포함, 값은 불변)
        updates.add(new long[] { kouzaNo, accNew });
        c.accountsWithTxn++;
        if (accInt > 0) { c.accountsPosted++; c.interestTotal += accInt; }

        byte[] key = KanaSortKey.of(kana);
        long run = accOpen;
        for (int k = 0; k < txns.size(); k++) {                     // D レコード
            BatchTxn t = txns.get(k);
            run += deltas[k];
            recs.add(new MeisaiRec.D(kouzaNo, kanji, t.dt(), t.kbn(),
                                     t.kingaku(), run, key, ++c.seq));
        }
        // T レコード — 当座·이자0 계좌도 반드시 생성한다
        recs.add(new MeisaiRec.T(kouzaNo, accInt, accFee, accNew, key, ++c.seq));
    }

    private static String nz(String s) { return s == null ? "" : s; }

    /** {@code SEQ-CNT} 는 실행 전체를 관통하는 단일 카운터(계좌별이 아니다). */
    private static final class Counters {
        int seq = 0;
        long accountsWithTxn = 0;
        long accountsPosted = 0;
        long interestTotal = 0;
    }
}
