package com.ksbank.minibank.domain;

/** 잔액/상태 조회 결과(RAW). ZANDAKA=COMP-3, JOUTAI=존10진 1byte(F0/F9). */
public record BalanceRow(byte[] zandaka, byte[] joutai) {}
