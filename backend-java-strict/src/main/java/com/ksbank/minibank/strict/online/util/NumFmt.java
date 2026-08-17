package com.ksbank.minibank.strict.online.util;

/**
 * COBOL copy/PFMTNUM.cpy (FMT-NUM: WK-NUM11 -(11)9 편집 -> FUNCTION TRIM) 대응.
 * S9(11) 수치를 부호 있는 최소 표기(선행 0 없음)로 바꾸는 것 뿐이므로,
 * Java에서는 Long.toString 이 그대로 동일한 결과를 낸다.
 */
public final class NumFmt {

    private NumFmt() {
    }

    public static String trim(long v) {
        return Long.toString(v);
    }
}
