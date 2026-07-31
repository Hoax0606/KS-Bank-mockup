package com.ksbank.minibank.domain;

/** 배치 집계용 계좌 레코드(일반 타입). */
public record AcctAgg(int kouzaNo, String shubetsu, String joutai,
                      long zandaka, String kaisetsu) {}
