package com.ksbank.minibank.strict.online.err;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import com.ksbank.minibank.strict.online.cgi.CGIRESPService;

/**
 * COBOL copy/PERRJSON.cpy 의 ERR-EMIT(STRING '{"ok":false,"error":"' ... '"}') 대응.
 * Jackson을 쓰지 않고 STRING 문처럼 수동으로 문자열을 결합한다.
 * ERR-EMIT도 {@code CALL "CGIRESP"}를 거치므로 {@link CGIRESPService}로 no-store 헤더를 붙인다.
 */
@RestControllerAdvice
public class CgiErrorHandler {

    private static final org.slf4j.Logger log =
        org.slf4j.LoggerFactory.getLogger(CgiErrorHandler.class);

    @ExceptionHandler(CgiError.class)
    public ResponseEntity<String> handle(CgiError e) {
        return emit(e.httpStatus, e.errorKey);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<String> handleUnexpected(Exception e) {
        log.error("unexpected error", e);
        return emit(HttpStatus.INTERNAL_SERVER_ERROR.value(), "internal_error");
    }

    private static ResponseEntity<String> emit(int status, String errorKey) {
        String body = "{\"ok\":false,\"error\":\"" + errorKey + "\"}";
        return CGIRESPService.status(status)
            .contentType(MediaType.valueOf("application/json;charset=UTF-8"))
            .body(body);
    }
}
