package com.ksbank.minibank.strict.online.util;

/**
 * COBOL CALL "UTF2SJIS" (backend-cobol/cobol/UTF2SJIS.c, glibc iconv UTF-8 -> Shift-JIS)
 * 대응. 이 strict 모듈의 DB는 PostgreSQL(UTF-8 저장)이므로 변환이 필요 없다 — no-op.
 * 다만 COBOL SIGNUP/NOTICE가 각 텍스트 필드마다 CALL 지점을 두고, 그 직후
 * {@code IF RETURN-CODE NOT = 0}으로 실패를 검사하는 구조를 그대로 반영하기 위해,
 * 이 메서드는 실패를 표현할 수 있는 체크 예외 {@link Utf2SjisException}을 던질 수 있는
 * 시그니처로 선언한다. PostgreSQL/UTF-8 환경에서는 변환이 항상 성공하므로 이 예외는
 * 실제로는 절대 발생하지 않는다(구조적 보존 목적 — 호출 지점 자체는 값만 같으면
 * 되는 이식이 아니므로 유지한다).
 */
public final class Utf2Sjis {

    private Utf2Sjis() {
    }

    public static String toDbCharset(String s) throws Utf2SjisException {
        return s;
    }
}
