package com.ksbank.minibank.domain;

/** LOAN_ASIS 목록 1행(일반 타입). */
public record LoanRow(long loanId, long principal, long balance,
                      String method, int termYears) {}
