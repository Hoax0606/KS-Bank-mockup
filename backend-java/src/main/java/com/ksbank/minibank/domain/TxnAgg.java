package com.ksbank.minibank.domain;

/** 배치 집계용 거래 레코드(RAW). */
public record TxnAgg(byte[] kbn, byte[] kingaku, byte[] tesuryo) {}
