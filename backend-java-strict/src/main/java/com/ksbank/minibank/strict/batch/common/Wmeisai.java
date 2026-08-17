package com.ksbank.minibank.strict.batch.common;

/**
 * {@code backend-cobol/cobol/copy/WMEISAI.cpy} (MEISAI.RPT의 明細부, 98byte 고정)
 * 필드 offset/length 상수. D(明細)/T(口座合計) 모두 같은 98byte 틀을 쓴다.
 *
 * <pre>
 * MEISAI-D (98 byte)                         MEISAI-T (98 byte)
 *  MD-KUBUN        X(01)   1   'D'            MT-KUBUN      X(01)  1  'T'
 *  MD-KOUZA-NO     9(10)   2-11               MT-KOUZA-NO   9(10)  2-11
 *  MD-MEIGI-KANJI  X(60)   12-71  Shift-JIS   MT-RISOKU     S9(11) COMP-3  12-17 (6)
 *  MD-TORIHIKI-DT  X(14)   72-85               MT-TESURYO-GK S9(11) COMP-3 18-23 (6)
 *  MD-KBN          X(01)   86                  MT-KAKUTEI-ZAN S9(11) COMP-3 24-29 (6)
 *  MD-KINGAKU      S9(11) COMP-3  87-92 (6)    MT-FILLER     X(69)  30-98 (공백)
 *  MD-ZANDAKA-GO   S9(11) COMP-3  93-98 (6)
 * </pre>
 *
 * offset은 0-based. {@code tools/parity/meisai_dump.py}의 슬라이스(rec[11:71] 등)와
 * 정확히 대응한다.
 */
public final class Wmeisai {
    private Wmeisai() {}

    public static final int RECORD_LEN = 98;

    public static final int KUBUN_OFF = 0;
    public static final int KUBUN_LEN = 1;

    public static final int KOUZA_OFF = 1;
    public static final int KOUZA_LEN = 10;

    // -- MEISAI-D --
    public static final int D_KANJI_OFF = 11;
    public static final int D_KANJI_LEN = 60;

    public static final int D_DT_OFF = 71;
    public static final int D_DT_LEN = 14;

    public static final int D_KBN_OFF = 85;
    public static final int D_KBN_LEN = 1;

    public static final int D_KINGAKU_OFF = 86;
    public static final int D_KINGAKU_DIGITS = 11; // COMP-3 -> 6 byte

    public static final int D_ZANDAKA_OFF = 92;
    public static final int D_ZANDAKA_DIGITS = 11; // COMP-3 -> 6 byte

    // -- MEISAI-T --
    public static final int T_RISOKU_OFF = 11;
    public static final int T_RISOKU_DIGITS = 11;

    public static final int T_TESURYO_OFF = 17;
    public static final int T_TESURYO_DIGITS = 11;

    public static final int T_KAKUTEI_OFF = 23;
    public static final int T_KAKUTEI_DIGITS = 11;
    // T filler: 29,69
}
