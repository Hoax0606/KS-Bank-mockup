package com.ksbank.minibank.strict.online.err;

/**
 * COBOL copy/PERRJSON.cpy (ERR-400/404/409/500 -> ERR-EMIT -> STOP RUN) 대응.
 * WK-ERRMSG에 에러 키를 담고 PERFORM ERR-xxx 하던 것을, HTTP status + 에러 키를 담은
 * unchecked 예외로 던져 CgiErrorHandler(@RestControllerAdvice)가 JSON으로 변환한다.
 */
public class CgiError extends RuntimeException {

    public final int httpStatus;
    public final String errorKey;

    public CgiError(int httpStatus, String errorKey) {
        super(errorKey);
        this.httpStatus = httpStatus;
        this.errorKey = errorKey;
    }

    public static CgiError err400(String key) { return new CgiError(400, key); }
    public static CgiError err404(String key) { return new CgiError(404, key); }
    public static CgiError err409(String key) { return new CgiError(409, key); }
    public static CgiError err500(String key) { return new CgiError(500, key); }
}
