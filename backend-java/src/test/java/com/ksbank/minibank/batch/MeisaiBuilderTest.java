package com.ksbank.minibank.batch;

import java.util.List;
import com.ksbank.minibank.domain.AcctAgg;
import com.ksbank.minibank.domain.BatchTxn;
import com.ksbank.minibank.domain.MeisaiRec;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** {@link MeisaiBuilder} — COBOL YAKANBAT + SORTRPT 이식의 값·순서 검증. */
class MeisaiBuilderTest {

    private static MeisaiBuilder.Result build() {
        return MeisaiBuilder.build(ParityFixture.accounts(), ParityFixture.txns());
    }

    @Test
    @DisplayName("カナ순 정렬 + 계좌 내 seq 순 — SORTRPT(SW2-KANA, SW2-SEQ) 재현")
    void kanaThenSeqOrder() {
        List<MeisaiRec> recs = build().records();
        // サトウ(2000456) ス ズキ(1001011) タカハシ(3000789) タナカ(4001213) ヤマダ(1000123) ワタナベ(5001415)
        assertEquals(List.of(
                "D2000456", "T2000456",
                "D1001011", "T1001011",
                "D3000789", "T3000789",
                "D4001213", "T4001213",
                "D1000123", "D1000123", "D1000123", "T1000123",
                "D5001415", "T5001415"),
            recs.stream().map(r -> r.kubun() + r.kouzaNo()).toList());
        // seq 는 실행 전체를 관통하는 단일 카운터
        assertEquals(List.of(7, 8, 5, 6, 9, 10, 11, 12, 1, 2, 3, 4, 13, 14),
            recs.stream().map(MeisaiRec::seq).toList());
    }

    @Test
    @DisplayName("取引後残高 = 期首(残高 - Σdelta) 부터 파일 순서대로 누적")
    void runningBalanceFromOpeningBalance() {
        // 1000123: 잔액 523400, delta +30000/-12000/-(10000+110) → Σ=7890 → 期首 515510
        List<Long> after = build().records().stream()
                .filter(r -> r.kouzaNo() == 1000123 && r instanceof MeisaiRec.D)
                .map(r -> ((MeisaiRec.D) r).zandakaGo())
                .toList();
        assertEquals(List.of(545510L, 533510L, 523400L), after);
    }

    @Test
    @DisplayName("普通=floor(잔액/365000), 当座=0, 凍結도 이자 가산")
    void interest() {
        assertEquals(1, t(1000123).risoku());          // 523400/365000
        assertEquals(3, t(3000789).risoku());          // 1204000/365000
        assertEquals(0, t(2000456).risoku());          // 88250 → 0
        assertEquals(0, t(1001011).risoku());          // 当座
        assertEquals(1, t(5001415).risoku());          // JOUTAI='9' 이지만 이자 가산됨
        assertEquals(523401, t(1000123).kakuteiZan());
        assertEquals(45000, t(1001011).kakuteiZan());
        assertEquals(670001, t(5001415).kakuteiZan());
    }

    @Test
    @DisplayName("手数料合計은 区分3만 — TESUBAT(non-null 전건)과 다른 집계")
    void feeTotalCountsKbn3Only() {
        assertEquals(110, t(1000123).tesuryoGoukei());
        assertEquals(110, t(4001213).tesuryoGoukei());
        assertEquals(0, t(2000456).tesuryoGoukei());
    }

    @Test
    @DisplayName("거래 없는 계좌는 明細·T레코드·잔액갱신 대상 모두 아님")
    void accountsWithoutTxnAreAbsent() {
        MeisaiBuilder.Result r = build();
        assertTrue(r.records().stream().noneMatch(x -> x.kouzaNo() == 6001617));
        assertTrue(r.records().stream().noneMatch(x -> x.kouzaNo() == 1001819));
        assertTrue(r.balanceUpdates().stream().noneMatch(u -> u[0] == 6001617));
        assertTrue(r.balanceUpdates().stream().noneMatch(u -> u[0] == 1001819));
    }

    @Test
    @DisplayName("잔액갱신은 거래 있는 전 계좌 — 当座·이자0 포함(COBOL BREAK-ACCT 무조건 UPDATE)")
    void updatesEveryAccountWithTxn() {
        MeisaiBuilder.Result r = build();
        assertEquals(6, r.accountsWithTxn());
        assertEquals(6, r.balanceUpdates().size());
        assertEquals(45000, updateOf(r, 1001011));   // 当座 — 값 불변이지만 UPDATE 대상
        assertEquals(3000, updateOf(r, 4001213));    // 이자 0 — 값 불변이지만 UPDATE 대상
        // 요약 카운터는 이자>0 만 센다(기존 JSON 키 의미 유지)
        assertEquals(3, r.accountsPosted());
        assertEquals(5, r.interestTotal());
    }

    @Test
    @DisplayName("마스터에 없는 계좌의 거래는 COBOL WARN 경로와 동형(명의 공백/種別1/잔액0)")
    void unknownAccountFallsBackLikeCobol() {
        MeisaiBuilder.Result r = MeisaiBuilder.build(
            List.<AcctAgg>of(),
            List.of(new BatchTxn(1L, 9999999, "20260801090000", "1", 500, 0)));
        MeisaiRec.D d = (MeisaiRec.D) r.records().get(0);
        assertEquals("", d.meigiKanji());
        assertEquals(0, d.zandakaGo());              // 期首 = 0 - 500 = -500 → -500 + 500 = 0
        assertEquals(0, r.interestTotal());          // 잔액 0 → 이자 0 (ACC-BAL > 0 조건)
    }

    private static MeisaiRec.T t(int kouzaNo) {
        return build().records().stream()
                .filter(r -> r.kouzaNo() == kouzaNo && r instanceof MeisaiRec.T)
                .map(MeisaiRec.T.class::cast)
                .findFirst().orElseThrow();
    }

    private static long updateOf(MeisaiBuilder.Result r, int kouzaNo) {
        return r.balanceUpdates().stream()
                .filter(u -> u[0] == kouzaNo).findFirst().orElseThrow()[1];
    }
}
