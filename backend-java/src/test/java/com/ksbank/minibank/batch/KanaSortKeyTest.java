package com.ksbank.minibank.batch;

import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** {@link KanaSortKey} — COBOL SORTRPT 의 SW2-KANA PIC X(60) 재현. */
class KanaSortKeyTest {

    @Test
    @DisplayName("항상 60byte — 부족분은 0x20 공백 채움")
    void paddedTo60Bytes() {
        byte[] k = KanaSortKey.of("ヤマダタロウ");           // 6자 × 3byte = 18byte
        assertEquals(60, k.length);
        assertEquals((byte) 0xE3, k[0]);
        for (int i = 18; i < 60; i++) assertEquals((byte) 0x20, k[i], "index " + i);
    }

    @Test
    @DisplayName("null·빈 문자열도 60byte 전부 공백")
    void nullBecomesAllSpaces() {
        for (byte b : KanaSortKey.of(null)) assertEquals((byte) 0x20, b);
        for (byte b : KanaSortKey.of("")) assertEquals((byte) 0x20, b);
    }

    @Test
    @DisplayName("60byte 초과는 절단 — COBOL 호스트변수 X(60) 용량과 동일")
    void truncatedAt60Bytes() {
        String long21 = "ア".repeat(21);                    // 63byte > 60
        byte[] k = KanaSortKey.of(long21);
        assertEquals(60, k.length);
        // 앞 20자(60byte)만 남고 잘린다
        byte[] head = "ア".repeat(20).getBytes(StandardCharsets.UTF_8);
        for (int i = 0; i < 60; i++) assertEquals(head[i], k[i], "index " + i);
    }

    @Test
    @DisplayName("UTF-8 바이트 오름차순 — 시드 명의의 정렬 순서")
    void byteAscendingOrder() {
        String[] kana = {
            "サトウハナコ", "スズキイチロウ", "タカハシケイコ",
            "タナカミサキ", "ヤマダタロウ", "ワタナベケン" };
        for (int i = 0; i + 1 < kana.length; i++) {
            assertTrue(KanaSortKey.ORDER.compare(KanaSortKey.of(kana[i]),
                                                 KanaSortKey.of(kana[i + 1])) < 0,
                kana[i] + " < " + kana[i + 1]);
        }
    }

    @Test
    @DisplayName("짧은 이름이 그 이름을 접두로 갖는 긴 이름보다 먼저 — 공백(0x20)이 카나보다 작다")
    void prefixSortsFirst() {
        assertTrue(KanaSortKey.ORDER.compare(KanaSortKey.of("タナカ"),
                                             KanaSortKey.of("タナカミサキ")) < 0);
    }

    @Test
    @DisplayName("unsigned 비교여야 한다 — signed 비교면 순서가 뒤집힌다")
    void mustBeUnsignedComparison() {
        // 0xE3.. (카나) vs 0x41 ('A'): unsigned 면 'A' < 카나, signed 면 0xE3 이 음수로 취급돼 역전
        byte[] ascii = KanaSortKey.of("A");
        byte[] kana = KanaSortKey.of("ア");
        assertTrue(KanaSortKey.ORDER.compare(ascii, kana) < 0);
        assertTrue(ascii[0] > 0 && kana[0] < 0, "카나 선두바이트는 signed 로 음수");
    }
}
