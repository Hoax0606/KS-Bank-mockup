package com.ksbank.minibank.strict.online.util;

/**
 * COBOL {@code CALL "UTF2SJIS" ... IF RETURN-CODE NOT = 0} 분기 대응.
 * backend-cobol/cobol/UTF2SJIS.c의 RETURN-CODE 1(iconv 초기화 실패, CP932 미지원 환경)/
 * 2(불정 UTF-8 또는 CP932로 표현 불가능한 문자)를 표현하는 체크 예외.
 *
 * 이 strict 모듈의 DB는 PostgreSQL(UTF-8 저장)이라 {@link Utf2Sjis#toDbCharset(String)}은
 * 실제로 변환을 수행하지 않는 no-op이고, 이 예외도 실제로는 절대 던져지지 않는다.
 * 그럼에도 체크 예외로 선언해 두는 이유는, COBOL SIGNUP/NOTICE가 텍스트 필드를 변환할
 * 때마다 CALL 직후 IF RETURN-CODE NOT = 0 으로 실패를 검사하는 지점을 두는 구조 자체를
 * Java 쪽에서도 구조적으로 보존하기 위함이다(호출부는 try/catch로 이 지점을 감싸고
 * 400 invalid_text_encoding으로 변환한다).
 */
public class Utf2SjisException extends Exception {

    public Utf2SjisException(String message) {
        super(message);
    }
}
