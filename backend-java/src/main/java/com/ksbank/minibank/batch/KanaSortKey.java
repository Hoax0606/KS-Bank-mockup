package com.ksbank.minibank.batch;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Comparator;

/**
 * 明細帳票의 名義カナ 정렬키. COBOL {@code SORTRPT.cbl} 의 {@code SW2-KANA PIC X(60)} 상당.
 *
 * <p>COBOL 측은 {@code REPORT.WORK} 의 선두 60byte(名義カナ, UTF-8)를 그대로 바이트 오름차순으로
 * 정렬한다(SORTRPT 헤더: 「名義カナ(UTF-8バイト昇順)で整列」). 그래서 Java도 <b>바이트</b> 비교여야 한다.
 *
 * <p>흔히 틀리는 3가지:
 * <ol>
 *   <li>{@code String.compareTo} — UTF-16 코드유닛 순서. UTF-8 바이트 순서와 다르다
 *       (카나는 BMP라 대개 일치하지만 "대개"는 1:1이 아니다).</li>
 *   <li>{@code java.text.Collator} — 로케일 조합 순서. 바이트 순서가 아니다.</li>
 *   <li>패딩/절단 생략 — COBOL {@code X(60)} 은 60byte 고정이다. Oracle {@code VARCHAR2(40)} 은
 *       JA16SJIS 하에서 <i>바이트</i> 의미(카나 ≤20자 → ≤60byte)라 COBOL은 절단하지 않지만,
 *       PostgreSQL {@code varchar(40)} 은 <i>문자</i> 의미(최대 120byte)라 COBOL이 절단할 값을
 *       저장할 수 있다. 그 절단을 모델링해야 충실하다.</li>
 * </ol>
 */
public final class KanaSortKey {

    /** COBOL {@code PIC X(60)}. */
    static final int WIDTH = 60;

    private KanaSortKey() {}

    /** 名義カナ → 60byte 고정 정렬키(UTF-8, 부족분은 0x20 공백 채움, 초과분은 절단). */
    public static byte[] of(String kana) {
        byte[] src = kana == null ? new byte[0] : kana.getBytes(StandardCharsets.UTF_8);
        byte[] key = new byte[WIDTH];
        Arrays.fill(key, (byte) 0x20);               // COBOL X(60) 공백 채움
        System.arraycopy(src, 0, key, 0, Math.min(src.length, WIDTH));
        return key;
    }

    /** unsigned 바이트 사전순. COBOL 영숫자 비교와 동일. */
    public static final Comparator<byte[]> ORDER = Arrays::compareUnsigned;
}
