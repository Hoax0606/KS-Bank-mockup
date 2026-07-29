package com.ksbank.minibank.codec;

import java.nio.charset.Charset;
import java.util.Arrays;

/**
 * 富士通 JEF EBCDIC 텍스트 코덱. COBOL WTXT/PTXT(JEFCONV 브리지) 대체.
 *
 * <p>jef4j 가 charset {@code x-Fujitsu-JEF-EBCDIC}(SO=0x28/SI=0x29 포함)을 제공.
 * COBOL판이 C 브리지 + 별도 Java 서비스로 하던 걸 여기선 라이브러리 직접 호출로 대체.
 */
public final class JefCodec {
    private JefCodec() {}

    public static final Charset JEF = Charset.forName("x-Fujitsu-JEF-EBCDIC");
    private static final byte EBCDIC_SPACE = 0x40;

    /** UTF-8 문자열 -&gt; JEF 바이트, 고정 길이(0x40 패딩 / len 바이트에서 절단). */
    public static byte[] encode(String s, int fixedLen) {
        byte[] j = s.getBytes(JEF);
        byte[] out = new byte[fixedLen];
        Arrays.fill(out, EBCDIC_SPACE);
        System.arraycopy(j, 0, out, 0, Math.min(j.length, fixedLen));
        return out;
    }

    /** 가변 길이 JEF 인코딩(패딩 없음). */
    public static byte[] encode(String s) {
        return s.getBytes(JEF);
    }

    /** JEF 바이트 -&gt; UTF-8 문자열(말미 0x40 공백 제거 후 디코드). */
    public static String decode(byte[] raw) {
        int end = raw.length;
        while (end > 0 && raw[end - 1] == EBCDIC_SPACE) end--;
        return new String(raw, 0, end, JEF);
    }
}
