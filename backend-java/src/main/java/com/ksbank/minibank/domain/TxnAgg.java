package com.ksbank.minibank.domain;

/** 배치 집계용 거래 레코드(일반 타입). tesuryo 는 nullable(振込만). */
public record TxnAgg(String kbn, long kingaku, Long tesuryo) {}
