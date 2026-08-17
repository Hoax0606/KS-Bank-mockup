package com.ksbank.minibank.strict.online.cgi;

/**
 * COBOL CGIPARM.cbl / copy/WCGI.cpy 의 CGI-PARAM(CP-NAME/CP-VALUE/CP-FOUND) 대응.
 * COBOL은 "이름 -> 값 + 존재여부(Y/N)"만 반환한다 — 값이 없을 때(찾지 못함)와
 * 빈 문자열로 존재하는 경우를 구분해야 하는 프로그램(NOTICE의 tag 기본값 등)이 있다.
 */
public record CgiParam(String value, boolean found) {
}
