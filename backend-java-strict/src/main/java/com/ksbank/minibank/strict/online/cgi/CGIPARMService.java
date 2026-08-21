package com.ksbank.minibank.strict.online.cgi;

import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/**
 * COBOL {@code CALL "CGIPARM" USING CGI-ENV CGI-PARAM} 대응.
 * 생성 시점에 {@link WCGIDto#getCP_NAME()}에 담긴 이름으로 현재 요청의 실제 HTTP
 * 파라미터를 찾아서 {@link WCGIDto#setCP_VALUE(String)}/{@link WCGIDto#setCP_FOUND(String)}를
 * 채운다 — {@link WCGIDto#getCGI_METHOD()}가 RequestContextHolder로 현재 요청을
 * 가져오는 것과 같은 방식.
 */
public class CGIPARMService {

    public CGIPARMService() {
        String name = WCGIDto.getCP_NAME();
        String value = ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes())
            .getRequest().getParameter(name);
        WCGIDto.setCP_VALUE(value == null ? "" : value);
        WCGIDto.setCP_FOUND(value != null ? "Y" : "N");
    }
}
