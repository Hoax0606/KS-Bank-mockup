package com.ksbank.minibank.domain;

/** KOUZA + KOUZA_EXT 조회 결과(RAW 바이트 그대로). 디코딩은 service 계층에서. */
public record AccountRow(
    byte[] meigiKanji,   // JEF 20byte
    byte[] shubetsu,     // 존10진 1byte (F1/F2)
    byte[] joutai,       // 존10진 1byte (F0/F9)
    byte[] zandaka,      // COMP-3 6byte (nullable)
    byte[] acctType,     // JEF (普通/当座 …)
    String kanjiMirror   // UTF-8 미러(폴백)
) {}
