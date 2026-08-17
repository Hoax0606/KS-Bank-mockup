package com.ksbank.minibank.strict.batch.common;

/**
 * {@code backend-cobol/cobol/copy/WTRDAT.cpy} (TORIHIKI.DAT / TORIHIKI.SORTED, 97byte 고정)
 * 필드 offset/length 상수. offset은 0-based(Java 배열 인덱스), COBOL 원본 주석의
 * 1-based 컬럼 번호(1-12, 13-22, ...)에서 -1 한 값이다.
 *
 * <pre>
 * TD-ID            PIC 9(12)              1-12   (12)
 * TD-KOUZA-NO      PIC 9(10)              13-22  (10)
 * TD-NICHIJI       PIC X(14)              23-36  (14) YYYYMMDDHHMMSS
 * TD-KBN           PIC X(01)              37     (1)  1=入金 2=出金 3=振込
 * TD-KINGAKU       PIC S9(11) COMP-3      38-43  (6)
 * TD-EXT           PIC X(14)              44-57  (14) 種別別 REDEFINES 영역
 *   TD-AITE-KOUZA  PIC 9(10)              44-53  (10)
 *   TD-TESURYO     PIC S9(05) COMP-3      54-56  (3)
 *   FILLER         PIC X(01)              57     (1)
 * TD-TEKIYOU       PIC X(40)              58-97  (40) Shift-JIS
 * </pre>
 */
public final class Wtrdat {
    private Wtrdat() {}

    public static final int RECORD_LEN = 97;

    public static final int ID_OFF = 0;
    public static final int ID_LEN = 12;

    public static final int KOUZA_OFF = 12;
    public static final int KOUZA_LEN = 10;

    public static final int NICHIJI_OFF = 22;
    public static final int NICHIJI_LEN = 14;

    public static final int KBN_OFF = 36;
    public static final int KBN_LEN = 1;

    public static final int KINGAKU_OFF = 37;
    public static final int KINGAKU_DIGITS = 11; // COMP-3 -> 6 byte

    public static final int EXT_OFF = 43;
    public static final int EXT_LEN = 14;

    // TD-EXT-FURIKOMI REDEFINES TD-EXT
    public static final int AITE_OFF = 43;
    public static final int AITE_LEN = 10;

    public static final int TESURYO_OFF = 53;
    public static final int TESURYO_DIGITS = 5; // COMP-3 -> 3 byte
    // EXT filler: 56,1

    public static final int TEKIYOU_OFF = 57;
    public static final int TEKIYOU_LEN = 40;
}
