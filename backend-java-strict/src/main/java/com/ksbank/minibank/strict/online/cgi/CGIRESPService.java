package com.ksbank.minibank.strict.online.cgi;

import java.io.IOException;

import org.springframework.http.ResponseEntity;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import jakarta.servlet.http.HttpServletResponse;

/**
 * COBOL {@code CALL "CGIRESP" USING RESP} 대응.
 * 지금은 MAIN에서 {@code new CGIRESPService()}로 호출만 하는 상태라, 실제로
 * RESP(응답 버퍼)를 받아서 내보내는 배선은 아직 없음 — 추후 보완 필요.
 *
 * <p>{@link #status(int)}는 CGIRESP가 9개 온라인 프로그램 전체의 공유 서브루틴이라
 * PERRJSON.cpy의 ERR-EMIT(에러 응답)도 이 지점을 거치기 때문에 남겨둔 정적 유틸이다
 * (com.ksbank.minibank.strict.online.err.CgiErrorHandler에서 사용).
 */
public class CGIRESPService {

    /** 임의 상태코드 응답 빌더 — CgiErrorHandler(PERRJSON.cpy ERR-EMIT 대응) 전용. */
    public static ResponseEntity.BodyBuilder status(int httpStatus) {
        return ResponseEntity.status(httpStatus)
            .header("Cache-Control", "no-store");
    }

    /** COBOL RESP(응답 버퍼)는 프로그램마다 다른 Dto에 들어있지만, 결국 문자열 하나다. */
    public CGIRESPService(String respBuf) {
        HttpServletResponse resp = ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes())
            .getResponse();
            resp.setHeader("Cache-Control", "no-store");
            resp.setContentType("application/json;charset=UTF-8");

            try{
                resp.getWriter().write(respBuf);
            } catch(IOException e) {
            }
    }
}
