package com.ksbank.minibank.strict.online.cgi;

import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/**
 * COBOL copy WCGI.cpy (CGI-ENV/CGI-PARAM) 대응.
 * CGI-METHOD는 {@link org.springframework.web.context.request.RequestContextHolder}로
 * "현재 요청"을 몰래 가져와서 실제 HTTP 메서드를 돌려준다 — {@link com.ksbank.minibank.strict.online.db.PDBCONService#CONN()}이
 * 현재 연결을 ThreadLocal로 가져오는 것과 같은 방식.
 * CP-NAME/CP-VALUE/CP-FOUND는 {@link CGIPARMService}가 생성 시점에 실제 HTTP
 * 파라미터를 조회해서 {@link #setCP_VALUE(String)}/{@link #setCP_FOUND(String)}로 채운다.
 */
public class WCGIDto {

    /** COBOL CGI-METHOD (REQUEST_METHOD). */
    public static String getCGI_METHOD() {
        return ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes())
            .getRequest().getMethod();
    }

    private static String CP_NAME;
    private static String CP_VALUE = "";

    public static void setCP_NAME(String name) {
        CP_NAME = name;
    }

    public static String getCP_NAME() {
        return CP_NAME;
    }

    public static void setCP_VALUE(String value) {
        CP_VALUE = value;
    }

    public static String getCP_VALUE() {
        return CP_VALUE;
    }

    private static String CP_FOUND = "N";

    public static void setCP_FOUND(String found) {
        CP_FOUND = found;
    }

    public static String getCP_FOUND() {
        return CP_FOUND;
    }
}
