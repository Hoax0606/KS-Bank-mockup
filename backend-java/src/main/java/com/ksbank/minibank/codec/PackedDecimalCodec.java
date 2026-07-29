package com.ksbank.minibank.codec;

/**
 * COBOL COMP-3 (packed decimal) &lt;-&gt; long 코덱.
 * COBOL copy/WPACK.cpy + PPACK.cpy(ENC-P11/DEC-P11 등) 대체.
 *
 * <p>바이트 규칙: 2 니블/바이트, 마지막 니블 = 부호(C=+, D=-, F=부호없음).
 * 자릿수↔바이트: bytes = floor(digits/2)+1. 예) S9(11)=6byte, S9(5)=3byte.
 */
public final class PackedDecimalCodec {
    private PackedDecimalCodec() {}

    /** value 를 packed-decimal {@code bytes} 바이트로 인코딩(부호 C/D). */
    public static byte[] encode(long value, int bytes) {
        int digitNibbles = bytes * 2 - 1;
        boolean neg = value < 0;
        String digits = Long.toString(Math.abs(value));
        if (digits.length() > digitNibbles) {
            throw new IllegalArgumentException(
                "value " + value + " exceeds " + bytes + " COMP-3 bytes");
        }
        byte[] out = new byte[bytes];
        int pad = digitNibbles - digits.length();
        int nib = 0;
        for (int i = 0; i < pad; i++) putNibble(out, nib++, 0);
        for (int i = 0; i < digits.length(); i++) putNibble(out, nib++, digits.charAt(i) - '0');
        putNibble(out, nib, neg ? 0x0D : 0x0C);
        return out;
    }

    /** packed-decimal 바이트를 long 으로 디코딩(부호 D=음수). */
    public static long decode(byte[] raw) {
        int nibbles = raw.length * 2;
        long v = 0;
        for (int i = 0; i < nibbles - 1; i++) v = v * 10 + getNibble(raw, i);
        return getNibble(raw, nibbles - 1) == 0x0D ? -v : v;
    }

    private static void putNibble(byte[] b, int idx, int val) {
        int bi = idx >> 1;
        if ((idx & 1) == 0) b[bi] = (byte) ((b[bi] & 0x0F) | (val << 4));
        else                b[bi] = (byte) ((b[bi] & 0xF0) | (val & 0x0F));
    }
    private static int getNibble(byte[] b, int idx) {
        int bi = idx >> 1;
        return (idx & 1) == 0 ? (b[bi] >> 4) & 0x0F : b[bi] & 0x0F;
    }
}
