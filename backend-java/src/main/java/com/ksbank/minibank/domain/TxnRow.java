package com.ksbank.minibank.domain;

/** TORIHIKI 1행(RAW). MEISAI 조회에서 사용. */
public record TxnRow(
    byte[] dt, byte[] kbn, byte[] kingaku, byte[] tesuryo, byte[] tekiyou, byte[] aite
) {}
