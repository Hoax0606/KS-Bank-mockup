package com.ksbank.minibank.codec;

/** RAW 필드 디코드 헬퍼(서비스 공통). COBOL DEC-TXT/DEC-P11/DEC-KEY + RAWUTF8 폴백 대응. */
public final class Fields {
    private Fields() {}

    /** EBCDIC 텍스트(종별/상태/점번/isPrimary/종별표시 등) JEF 디코드. null→"". */
    public static String text(byte[] raw) {
        return raw == null ? "" : JefCodec.decode(raw);
    }

    /** 명의: JEF RAW 디코드가 정본, 실패/공백이면 UTF-8 미러 폴백. */
    public static String nameOrMirror(byte[] raw, String mirror) {
        if (raw != null) {
            try {
                String s = JefCodec.decode(raw);
                if (!s.isBlank()) return s;
            } catch (RuntimeException ignore) { /* 미매핑 → 미러 */ }
        }
        return mirror == null ? "" : mirror;
    }

    /** COMP-3 금액 디코드. null→0. */
    public static long amount(byte[] raw) {
        return raw == null ? 0 : PackedDecimalCodec.decode(raw);
    }

    /** 존10진 키 → 숫자. null/빈값→0. */
    public static long zonedNum(byte[] raw) {
        if (raw == null) return 0;
        String d = ZonedDecimalCodec.decode(raw);
        return d.isEmpty() ? 0 : Long.parseLong(d);
    }
}
