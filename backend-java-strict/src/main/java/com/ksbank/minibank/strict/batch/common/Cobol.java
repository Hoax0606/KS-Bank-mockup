package com.ksbank.minibank.strict.batch.common;

import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;

/**
 * COBOL 언어 시맨틱스(MOVE 정규화 / COMP-3 팩10진 / Shift-JIS) 대응 유틸.
 *
 * <p>여러 배치 프로그램이 공통으로 COPY 하는 규칙(사실상 GnuCOBOL 런타임이 처리하는
 * MOVE 규칙)이라 여기 모아둬도 "1:1 이식" 원칙 위반이 아니다 — 각 프로그램은 여전히
 * 자기 COPY북(WTRDAT/WMEISAI)의 offset/length 상수를 직접 들고 필드 단위로 조립한다.
 *
 * <p>COMP-3 pack/unpack 알고리즘은 {@code tools/parity/meisai_dump.py}의 {@code comp3()}와
 * 동일 규칙(마지막 바이트 하위 니블 0x0D=음수, 그 외=양수)을 그대로 포팅한 것이다.
 */
public final class Cobol {
    private Cobol() {}

    /** COBOL ネイティブ Shift-JIS(GnuCOBOL CP932 상당). 2026-08 이후 파일 레벨까지 전부 이 인코딩. */
    public static final Charset SJIS = Charset.forName("MS932");

    // ================================================================
    //  PIC 9(n) — 부호 없는 표시 숫자로의 MOVE (zero-pad, 고위 절단)
    // ================================================================

    /** COBOL {@code MOVE x TO <PIC 9(width)>} 상당. 음수는 절댓값(부호 소실), 자리수 초과는 고위 절단. */
    public static String pic9(long value, int width) {
        String s = Long.toString(Math.abs(value));
        if (s.length() > width) s = s.substring(s.length() - width);
        return "0".repeat(width - s.length()) + s;
    }

    /** {@code MOVE} 로 더 작은 PIC 9(digits)로 옮길 때의 고위자리 절단(부호는 유지) — 예: HV-KZ7 PIC 9(7) 대입. */
    public static long truncate(long value, int digits) {
        long limit = (long) Math.pow(10, digits);
        long mag = Math.abs(value) % limit;
        return value < 0 ? -mag : mag;
    }

    // ================================================================
    //  PIC X(n) — 영숫자 MOVE (space-pad / 우측 절단)
    // ================================================================

    /** COBOL {@code MOVE x TO <PIC X(width)>} 상당 — 좌측정렬 공백채움/절단. */
    public static String picX(String value, int width) {
        String v = value == null ? "" : value;
        if (v.length() > width) return v.substring(0, width);
        return v + " ".repeat(width - v.length());
    }

    // ================================================================
    //  고정길이 레코드(byte[]) 필드 write/read 헬퍼 — ASCII 표시 숫자/영숫자
    // ================================================================

    public static void putPic9(byte[] rec, int off, int len, long value) {
        byte[] b = pic9(value, len).getBytes(StandardCharsets.US_ASCII);
        System.arraycopy(b, 0, rec, off, len);
    }

    public static void putPicX(byte[] rec, int off, int len, String value) {
        byte[] b = picX(value, len).getBytes(StandardCharsets.US_ASCII);
        System.arraycopy(b, 0, rec, off, len);
    }

    public static String getAscii(byte[] rec, int off, int len) {
        return new String(rec, off, len, StandardCharsets.US_ASCII);
    }

    public static long getPic9(byte[] rec, int off, int len) {
        String s = getAscii(rec, off, len).trim();
        return s.isEmpty() ? 0L : Long.parseLong(s);
    }

    // ================================================================
    //  Shift-JIS 필드(名義/摘要 등) — 바이트 단위 space-pad, 문자경계 절단
    // ================================================================

    /** SJIS로 인코딩해 {@code len}byte 고정폭으로 만든다(부족분 0x20 채움, 초과분은 문자경계에서 절단). */
    public static byte[] sjisFixed(String value, int len) {
        String v = value == null ? "" : value;
        byte[] out = new byte[len];
        Arrays.fill(out, (byte) 0x20);
        int pos = 0;
        for (int i = 0; i < v.length(); ) {
            int cp = v.codePointAt(i);
            byte[] cb = new String(Character.toChars(cp)).getBytes(SJIS);
            if (pos + cb.length > len) break;
            System.arraycopy(cb, 0, out, pos, cb.length);
            pos += cb.length;
            i += Character.charCount(cp);
        }
        return out;
    }

    public static void putSjis(byte[] rec, int off, int len, String value) {
        System.arraycopy(sjisFixed(value, len), 0, rec, off, len);
    }

    public static String getSjis(byte[] rec, int off, int len) {
        return new String(rec, off, len, SJIS);
    }

    // ================================================================
    //  COMP-3 (packed decimal) — tools/parity/meisai_dump.py comp3() 포팅
    // ================================================================

    /** PIC S9(digits) COMP-3 의 바이트 폭 (digits 자리 + 부호 니블 1개, 2자리당 1byte). */
    public static int comp3Len(int digits) {
        return digits / 2 + 1;
    }

    /** value를 PIC S9(digits) COMP-3 바이트열로 팩(pack)한다. */
    public static byte[] pack(long value, int digits) {
        int len = comp3Len(digits);
        int nibbleDigits = len * 2 - 1;
        String s = Long.toString(Math.abs(value));
        if (s.length() > nibbleDigits) {
            s = s.substring(s.length() - nibbleDigits);
        } else {
            s = "0".repeat(nibbleDigits - s.length()) + s;
        }
        byte[] out = new byte[len];
        int signNibble = value < 0 ? 0x0D : 0x0C;
        int di = 0;
        for (int bi = 0; bi < len - 1; bi++) {
            int hi = s.charAt(di++) - '0';
            int lo = s.charAt(di++) - '0';
            out[bi] = (byte) ((hi << 4) | lo);
        }
        int lastDigit = s.charAt(di) - '0';
        out[len - 1] = (byte) ((lastDigit << 4) | signNibble);
        return out;
    }

    public static void putComp3(byte[] rec, int off, int digits, long value) {
        byte[] packed = pack(value, digits);
        System.arraycopy(packed, 0, rec, off, packed.length);
    }

    /** COMP-3 바이트열 -> long. 마지막 바이트 하위 니블 0x0D=음수, 그 외=양수(meisai_dump.py comp3()와 동일 규칙). */
    public static long unpack(byte[] rec, int off, int len) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < len - 1; i++) {
            int b = rec[off + i] & 0xFF;
            sb.append(b >> 4).append(b & 0x0F);
        }
        int last = rec[off + len - 1] & 0xFF;
        sb.append(last >> 4);
        String digits = sb.toString();
        long value = digits.isEmpty() ? 0L : Long.parseLong(digits);
        return (last & 0x0F) == 0x0D ? -value : value;
    }

    public static long getComp3(byte[] rec, int off, int digits) {
        return unpack(rec, off, comp3Len(digits));
    }
}
