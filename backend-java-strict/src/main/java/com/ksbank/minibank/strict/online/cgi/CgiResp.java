package com.ksbank.minibank.strict.online.cgi;

import org.springframework.http.ResponseEntity;

/**
 * COBOL CGIRESP.cbl 대응.
 * CGIRESP.cbl은 9개 온라인 CGI 전부가 {@code CALL "CGIRESP" USING RESP}로 호출하는
 * 단일 공유 서브루틴이며, 여기서 {@code Cache-Control: no-store} 헤더를 한 곳에서만
 * DISPLAY한다(잔액/로그인정보 등 민감정보 캐시 방지, PERRJSON.cpy의 ERR-EMIT도 동일하게
 * CGIRESP를 거치므로 에러 응답도 예외가 아니다). Java 쪽도 9개 컨트롤러 +
 * CgiErrorHandler가 각자 헤더를 반복해서 붙이지 않고, 이 유틸 하나를 거치게 해서
 * COBOL의 "공유 서브루틴 CALL" 구조를 그대로 재현한다.
 */
public final class CgiResp {

    private CgiResp() {
    }

    /** 정상 응답(HTTP 200) 조립 — 각 컨트롤러의 {@code return CgiResp.ok(...)} 지점. */
    public static ResponseEntity<String> ok(String body) {
        return ResponseEntity.ok()
            .header("Cache-Control", "no-store")
            .body(body);
    }

    /** 임의 상태코드 응답 빌더 — CgiErrorHandler(PERRJSON.cpy ERR-EMIT 대응) 전용. */
    public static ResponseEntity.BodyBuilder status(int httpStatus) {
        return ResponseEntity.status(httpStatus)
            .header("Cache-Control", "no-store");
    }
}
