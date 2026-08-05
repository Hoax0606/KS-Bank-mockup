package com.ksbank.minibank.domain;

/**
 * 明細帳票 1레코드. COBOL {@code WMEISAI.cpy} 의 두 {@code 01} 레벨을 그대로 미러한다.
 * <ul>
 *   <li>{@link D} = 明細行 (거래 1건. {@code zandakaGo} = 取引後残高)</li>
 *   <li>{@link T} = 口座合計 (계좌 1개. 利息 / 手数料合計 / 確定残高)</li>
 * </ul>
 *
 * <p>98byte 고정길이·COMP-3 는 재현하지 않는다(2026-07-30 정상화에서 codec 폐기,
 * DESIGN.md §6/§8). 파리티는 <b>값</b> 기준이다.
 *
 * <p>{@code sortKey}/{@code seq} 는 COBOL {@code SORTRPT} 의 {@code SW2-KANA}/{@code SW2-SEQ}
 * 에 대응하는 정렬키다. {@code seq} 는 실행 전체를 관통하는 단일 카운터({@code SEQ-CNT})로,
 * 이것이 있어 comparator 가 전순서가 되고 sort 안정성에 의존하지 않는다.
 */
public sealed interface MeisaiRec {

    /** 'D' 또는 'T'. COBOL {@code MR-KUBUN}. */
    String kubun();

    int kouzaNo();

    /** {@code SW2-KANA} — 名義カナ를 X(60) 상당으로 정규화한 바이트열. */
    byte[] sortKey();

    /** {@code SW2-SEQ} — 생성 순(1-based). */
    int seq();

    /** 明細行. COBOL {@code MEISAI-D}. */
    record D(int kouzaNo, String meigiKanji, String torihikiDt, String kbn,
             long kingaku, long zandakaGo, byte[] sortKey, int seq) implements MeisaiRec {
        @Override public String kubun() { return "D"; }
    }

    /** 口座合計. COBOL {@code MEISAI-T}. */
    record T(int kouzaNo, long risoku, long tesuryoGoukei, long kakuteiZan,
             byte[] sortKey, int seq) implements MeisaiRec {
        @Override public String kubun() { return "T"; }
    }
}
