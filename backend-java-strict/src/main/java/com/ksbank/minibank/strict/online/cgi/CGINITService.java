package com.ksbank.minibank.strict.online.cgi;

/**
 * COBOL {@code CALL "CGIINIT" USING CGI-ENV} 대응.
 * 지금은 MAIN에서 {@code new CGINITService()}로 호출만 하는 상태라, 실제로
 * CGI-ENV(={@link WCGIDto})를 채워주는 배선은 아직 없음 — 추후 보완 필요.
 */
public class CGINITService {
}
