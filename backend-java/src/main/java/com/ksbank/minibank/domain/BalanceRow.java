package com.ksbank.minibank.domain;

/** 잔액/상태 조회 결과(일반 타입). JOUTAI="0"/"9". */
public record BalanceRow(long zandaka, String joutai) {}
