package com.ksbank.minibank.domain;

/** KOUZA + KOUZA_EXT 상세(RAW). 조회 계열(zandaka/holdings)에서 사용. */
public record AccountDetail(
    byte[] meigiKanji, byte[] meigiKana, byte[] shubetsu, byte[] joutai, byte[] zandaka,
    byte[] acctType, byte[] branchCode, byte[] isPrimary,
    String kanjiMirror, String kanaMirror
) {}
