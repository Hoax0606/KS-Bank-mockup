package com.ksbank.minibank.strict.online.cgi;

import jakarta.servlet.http.HttpServletRequest;

/**
 * COBOL CGIINIT.cbl + CGIPARM.cbl 대응.
 * COBOL은 CGIINIT으로 REQUEST_METHOD/QUERY_STRING/POST body를 CGI-ENV에 모으고,
 * 각 파라미터 조회마다 CGIPARM(이름 -> 값+존재여부, query 우선 -> body)을 CALL한다.
 * 이 클래스는 그 계약만 HttpServletRequest 위에서 재현한다(파싱 자체는 서블릿 컨테이너가 처리).
 */
public class CgiRequest {

    private final HttpServletRequest req;

    public CgiRequest(HttpServletRequest req) {
        this.req = req;
    }

    /** COBOL CGI-METHOD (REQUEST_METHOD). */
    public String method() {
        return req.getMethod();
    }

    /** COBOL CALL "CGIPARM" USING CGI-ENV CGI-PARAM 대응. */
    public CgiParam param(String name) {
        String v = req.getParameter(name);
        return new CgiParam(v == null ? "" : v, v != null);
    }
}
