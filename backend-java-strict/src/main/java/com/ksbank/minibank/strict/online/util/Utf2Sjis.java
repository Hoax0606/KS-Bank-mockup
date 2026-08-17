package com.ksbank.minibank.strict.online.util;

/**
 * COBOL CALL "UTF2SJIS" (backend-cobol/cobol/UTF2SJIS.c, glibc iconv UTF-8 -> Shift-JIS)
 * 대응. 이 strict 모듈의 DB는 PostgreSQL(UTF-8 저장)이므로 변환이 필요 없다 — no-op.
 * 다만 COBOL SIGNUP/NOTICE가 각 텍스트 필드마다 CALL 지점을 두는 구조를 그대로 반영해,
 * 호출 지점 자체는 유지한다(값만 같으면 되는 이식이 아니므로).
 */
public final class Utf2Sjis {

    private Utf2Sjis() {
    }

    public static String toDbCharset(String s) {
        return s;
    }
}
