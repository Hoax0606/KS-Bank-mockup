package com.ksbank.minibank.domain;

/** 배치 집계용 계좌 레코드(RAW). */
public record AcctAgg(byte[] kouzaNo, byte[] shubetsu, byte[] joutai,
                      byte[] zandaka, byte[] kaisetsu) {}
