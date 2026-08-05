package com.ksbank.minibank.batch;

import java.util.List;
import com.ksbank.minibank.domain.MeisaiRec;

/**
 * 야간배치 1회 실행 결과. 한 번 계산해서 두 가지로 렌더링한다
 * ({@link com.ksbank.minibank.batch.report.JsonRenderer} / {@link com.ksbank.minibank.batch.report.ReportWriter}).
 *
 * <p>COBOL 10스텝 대응: {@code meisai}=3 YAKANBAT + 4 SORTRPT, {@code nippo}=5,
 * {@code zandaka}=6, {@code tesuryo}=7, {@code kyumin}=8, {@code master}=9, {@code tokei}=10.
 *
 * @param accountsPosted  이자>0 계좌수 (기존 JSON 키 의미 그대로 유지)
 * @param interestTotal   가산된 이자 총액
 * @param accountsUpdated COBOL이 UPDATE 하는 계좌수(=거래 있는 계좌수=T레코드 수)
 */
public record BatchResult(
        long accountsPosted,
        long interestTotal,
        long accountsUpdated,
        List<MeisaiRec> meisai,
        Nippo nippo,
        Zandaka zandaka,
        Tesuryo tesuryo,
        List<Long> kyumin,
        List<MasterRow> master,
        Tokei tokei) {

    /** 取引日報(NIPPOBAT). index 1..3 = 区分 1/2/3. index 0 은 미사용(区分외). */
    public record Nippo(long[] count, long[] sum) {}

    /** 残高一覧 1행(ZANDABAT). */
    public record ZandakaRow(int kouzaNo, String shubetsu, String joutai, long zandaka) {}

    /** 残高一覧(ZANDABAT) — 목록 + 총잔액. */
    public record Zandaka(List<ZandakaRow> rows, long total) {}

    /** 振込手数料 집계(TESUBAT). ★TORIHIKI.TESURYO 가 non-null 인 전건(区分 무관). */
    public record Tesuryo(long count, long total) {}

    /** 口座マスタ一覧 1행(MASTBAT). */
    public record MasterRow(int kouzaNo, String shubetsu, String joutai,
                            String kaisetsu, long zandaka) {}

    /** 統計サマリ(TOKEBAT). */
    public record Tokei(long accounts, long futsu, long touza, long frozen,
                        long totalBalance, long txnCount) {}
}
