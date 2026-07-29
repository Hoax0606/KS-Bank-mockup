package com.ksbank.minibank.config;

import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * COBOL PERRJSON(에러 JSON) 대체. 실패 응답을 계약대로 {"ok":false,"error":"..."} 로 통일.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final org.slf4j.Logger log =
        org.slf4j.LoggerFactory.getLogger(GlobalExceptionHandler.class);

    /** 업무 규칙 위반 등 명시적 오류(예: 잔액부족, 계좌없음). */
    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<Map<String, Object>> business(BusinessException e) {
        return ResponseEntity.status(e.status)
            .body(Map.of("ok", false, "error", e.getMessage()));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> unexpected(Exception e) {
        log.error("unexpected error", e);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(Map.of("ok", false, "error", "internal_error"));
    }

    /** 업무 오류(HTTP 상태 + error 키). */
    public static class BusinessException extends RuntimeException {
        public final HttpStatus status;
        public BusinessException(HttpStatus status, String errorKey) {
            super(errorKey);
            this.status = status;
        }
    }
}
