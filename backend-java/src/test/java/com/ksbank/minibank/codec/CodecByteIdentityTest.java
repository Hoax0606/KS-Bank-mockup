package com.ksbank.minibank.codec;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.HexFormat;
import org.junit.jupiter.api.Test;

/**
 * ★최우선 스파이크★ 코덱이 COBOL/Oracle판과 <b>바이트 동일</b>한지 검증.
 * 기대 hex 값은 라이브 DB(02_seed) 실측치.
 */
class CodecByteIdentityTest {

    private static final HexFormat HEX = HexFormat.of().withUpperCase();

    private static byte[] unhex(String s) { return HEX.parseHex(s); }
    private static String hex(byte[] b)    { return HEX.formatHex(b); }

    // ---- COMP-3 (금액) ----
    @Test void comp3_encode_matches_seed() {
        // KOUZA 1000123 잔액 523400 -> 6byte
        assertEquals("00000523400C", hex(PackedDecimalCodec.encode(523400, 6)));
    }
    @Test void comp3_roundtrip() {
        assertEquals(523400L, PackedDecimalCodec.decode(unhex("00000523400C")));
        assertEquals(99999999999L, PackedDecimalCodec.decode(PackedDecimalCodec.encode(99999999999L, 6)));
        assertEquals(-50000L, PackedDecimalCodec.decode(PackedDecimalCodec.encode(-50000L, 6)));
    }
    @Test void comp3_fee_3byte() {
        assertEquals("00110C", hex(PackedDecimalCodec.encode(110, 3))); // 振込手数料
    }

    // ---- 존10진 (키) ----
    @Test void zoned_encode_matches_seed() {
        assertEquals("F1F0F0F0F1F2F3", hex(ZonedDecimalCodec.encode("1000123")));
    }
    @Test void zoned_roundtrip() {
        assertEquals("1000123", ZonedDecimalCodec.decode(unhex("F1F0F0F0F1F2F3")));
        assertEquals("20180415", ZonedDecimalCodec.decode(unhex("F2F0F1F8F0F4F1F5"))); // 開設日
    }

    // ---- JEF (명의) ----
    @Test void jef_encode_matches_seed() {
        // KOUZA 1000123 MEIGI_KANJI (山田太郎, 20byte, 0x40 패딩)
        byte[] b = JefCodec.encode("山田太郎", 20);
        assertEquals("28BBB3C5C4C2C0CFBA2940404040404040404040", hex(b));
    }
    @Test void jef_decode_roundtrip() {
        byte[] raw = unhex("28BBB3C5C4C2C0CFBA2940404040404040404040");
        assertEquals("山田太郎", JefCodec.decode(raw));
    }
    @Test void jef_encode_decode_symmetry() {
        for (String s : new String[]{"山田太郎", "佐藤花子", "髙橋圭子"}) {
            assertEquals(s, JefCodec.decode(JefCodec.encode(s, 20)));
        }
    }
    @Test void jef_charset_is_available() {
        // jef4j SPI 등록 확인 (classpath 에 jef4j 없으면 여기서 실패)
        assertArrayEquals(
            unhex("28BBB3C5C4C2C0CFBA29"),
            JefCodec.encode("山田太郎"));
    }
}
