package com.ksbank.minibank.domain;

/** TORIHIKI 1행(일반 타입). MEISAI 조회에서 사용. tekiyou 는 nullable. */
public record TxnRow(
    String dt, String kbn, long kingaku, long tesuryo, String tekiyou, long aite
) {}
