package com.ksbank.minibank.codec;

/** RAW 인코딩 헬퍼(서비스 공통). key=존10진, amount=COMP-3, jef=텍스트. */
public final class Enc {
    private Enc() {}

    /** 숫자값을 digits 자리 존10진 RAW로. */
    public static byte[] key(long value, int digits) {
        return ZonedDecimalCodec.encode(String.format("%0" + digits + "d", value));
    }
    /** 숫자 문자열 그대로 존10진 RAW로. */
    public static byte[] key(String digits) {
        return ZonedDecimalCodec.encode(digits);
    }
    /** COMP-3 6byte(S9(11)). */
    public static byte[] amount(long v) { return PackedDecimalCodec.encode(v, 6); }
    /** COMP-3 3byte(S9(5)). */
    public static byte[] amount3(long v) { return PackedDecimalCodec.encode(v, 3); }
    /** COMP-3 2byte(S9(3)) — 연수. */
    public static byte[] years(long v) { return PackedDecimalCodec.encode(v, 2); }
    /** COMP-3 4byte(S9(3)V999) — 이율. rate*1000 저장. */
    public static byte[] rate(double r) { return PackedDecimalCodec.encode(Math.round(r * 1000), 4); }
    /** 가변 JEF. */
    public static byte[] jef(String s) { return JefCodec.encode(s); }
    /** 고정 길이 JEF(0x40 패딩). */
    public static byte[] jef(String s, int len) { return JefCodec.encode(s, len); }
}
