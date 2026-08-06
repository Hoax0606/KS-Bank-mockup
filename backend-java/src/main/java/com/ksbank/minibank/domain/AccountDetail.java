package com.ksbank.minibank.domain;

/**
 * KOUZA + KOUZA_EXT 상세(일반 타입). 조회 계열(zandaka/holdings)에서 사용.
 * birth~job 은 회원정보(会員情報) 화면용 — KOUZA_EXT 에 값이 없으면 null(신규계좌는 프로필 미입력).
 */
public record AccountDetail(
    String meigiKanji, String meigiKana, String shubetsu, String joutai, long zandaka,
    String acctType, String branchCode, String isPrimary,
    String birth, String sex, String zip, String addr, String phone, String email, String job
) {}
