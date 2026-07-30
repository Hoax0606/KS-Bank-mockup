package com.ksbank.minibank.domain;

/** KOUZA + KOUZA_EXT 상세(일반 타입). 조회 계열(zandaka/holdings)에서 사용. */
public record AccountDetail(
    String meigiKanji, String meigiKana, String shubetsu, String joutai, long zandaka,
    String acctType, String branchCode, String isPrimary
) {}
