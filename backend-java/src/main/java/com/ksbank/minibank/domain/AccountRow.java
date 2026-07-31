package com.ksbank.minibank.domain;

/** KOUZA + KOUZA_EXT 로그인 조회 결과(일반 타입, UTF-8). */
public record AccountRow(
    String meigiKanji,   // 名義(漢字)
    String shubetsu,     // "1"/"2"
    String joutai,       // "0"/"9"
    long   zandaka,      // 残高
    String acctType      // 普通/当座 …
) {}
