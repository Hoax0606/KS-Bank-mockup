package com.ksbank.minibank.codec;

/**
 * 존10진 EBCDIC 코덱 (키/일자). COBOL WPACK(KY-*) + PPACK(ENC-KEY/DEC-KEY) 대체.
 *
 * <p>각 자리 숫자를 0xF0|digit 바이트로 저장. 예) "1000123" -&gt; F1 F0 F0 F0 F1 F2 F3.
 * 일자(YYYYMMDD)도 EBCDIC 숫자라 동일하게 처리 가능.
 */
public final class ZonedDecimalCodec {
    private ZonedDecimalCodec() {}

    /** 숫자 문자열 -&gt; 존10진 바이트(자리당 1바이트). */
    public static byte[] encode(String digits) {
        byte[] out = new byte[digits.length()];
        for (int i = 0; i < digits.length(); i++) {
            char c = digits.charAt(i);
            if (c < '0' || c > '9') throw new IllegalArgumentException("non-digit: " + digits);
            out[i] = (byte) (0xF0 | (c - '0'));
        }
        return out;
    }

    /** 존10진 바이트 -&gt; 숫자 문자열(하위 니블 추출). */
    public static String decode(byte[] raw) {
        StringBuilder sb = new StringBuilder(raw.length);
        for (byte b : raw) sb.append((char) ('0' + (b & 0x0F)));
        return sb.toString();
    }
}
