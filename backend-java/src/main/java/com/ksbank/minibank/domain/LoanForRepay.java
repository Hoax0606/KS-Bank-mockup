package com.ksbank.minibank.domain;

/** 返済 처리에 필요한 대출 정보(RAW): 잔액·이율·소유 계좌. */
public record LoanForRepay(byte[] balance, byte[] rate, byte[] kouzaNo) {}
