package com.ksbank.minibank.domain;

/** LOAN_ASIS 목록 1행(RAW). */
public record LoanRow(byte[] loanId, byte[] principal, byte[] balance,
                      byte[] method, byte[] termYears) {}
