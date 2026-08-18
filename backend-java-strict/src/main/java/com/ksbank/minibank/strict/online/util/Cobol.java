package com.ksbank.minibank.strict.online.util;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

/**
 * COBOL 언어 자체가 이름 붙인 것(내장함수/MOVE 편집 규칙)에 대응하는 공유 유틸.
 *
 * <p>COBOL 프로그래머가 이름 붙인 변수/단락은 각 프로그램의 VO/Service/Dao가 그 이름을
 * (`-`→`_`만 바꿔) 그대로 쓴다. 반면 이 클래스의 메서드들은 특정 프로그램이 지은 이름이
 * 아니라 COBOL 컴파일러/런타임이 제공하는 기능(FUNCTION NUMVAL/TRIM, PIC 편집)이므로,
 * 여러 프로그램이 공유해도 "1:1 이식 위반"이 아니다 — 이미 배치 쪽
 * {@code batch/common/Cobol.java}가 COMP-3/PIC 편집을 이런 식으로 모아둔 것과 같은 원칙.
 */
public final class Cobol {

    private static final DateTimeFormatter YMD = DateTimeFormatter.ofPattern("yyyyMMdd");

    private Cobol() {
    }

    /**
     * {@code FUNCTION NUMVAL(x)} 대응. COBOL은 숫자로 해석 가능한 문자열을 전제하지만,
     * 여기서는 HTTP 파라미터가 비어있거나 숫자가 아닐 수 있어 그 경우 0으로 처리한다
     * (원본 CGIPARM 계약상 "값 없음"이 빈 문자열로 오는 것에 대한 최소 방어).
     */
    public static long NUMVAL(String s) {
        if (s == null) return 0;
        String v = s.trim();
        if (v.isEmpty()) return 0;
        try {
            return (long) Double.parseDouble(v);
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    /** {@code FUNCTION TRIM(x)} 대응 — 앞뒤 공백 제거. */
    public static String TRIM(String s) {
        return s == null ? "" : s.trim();
    }

    /** {@code FUNCTION CURRENT-DATE(1:8)} 대응 — 8자리 yyyyMMdd. */
    public static String CURRENT_DATE() {
        return LocalDate.now().format(YMD);
    }

    /** {@code MOVE <numeric> TO PIC 9(digits)} — 숫자 값 유지, 고위자리 절단(부호 유지). */
    public static long truncate(long value, int digits) {
        long limit = (long) Math.pow(10, digits);
        long mag = Math.abs(value) % limit;
        return value < 0 ? -mag : mag;
    }

    /** {@code PIC 9(width)} 표시 편집 — zero-pad 문자열(부호 무시, 고위자리 절단). */
    public static String pic9(long value, int width) {
        String s = Long.toString(Math.abs(value));
        if (s.length() > width) s = s.substring(s.length() - width);
        return "0".repeat(width - s.length()) + s;
    }

    /**
     * {@code PIC X(width)} MOVE/참조수정 대응 — 좌측정렬 공백채움/우측절단.
     * {@code CP-VALUE(1:n)}처럼 고정폭 필드에서 앞 n글자를 꺼내는 참조수정도,
     * HTTP 파라미터(가변 길이)에서는 부족분을 공백으로 채워야 같은 폭이 되므로 동일하게 쓴다.
     */
    public static String picX(String value, int width) {
        String v = value == null ? "" : value;
        if (v.length() > width) return v.substring(0, width);
        return v + " ".repeat(width - v.length());
    }
}
