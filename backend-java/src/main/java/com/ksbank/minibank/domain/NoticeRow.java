package com.ksbank.minibank.domain;

/** NOTICE_ASIS 목록 1행(RAW): 일자·태그·제목. */
public record NoticeRow(byte[] noticeDate, byte[] tag, byte[] title) {}
