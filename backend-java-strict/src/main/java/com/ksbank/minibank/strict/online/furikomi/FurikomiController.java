package com.ksbank.minibank.strict.online.furikomi;

import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.cgi.CgiResp;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

/** 얇은 어댑터. 실제 로직은 {@link FurikomiServiceImpl}(COBOL FURIKOMI.cbl 1:1 포팅)에 위임. */
@RestController
public class FurikomiController {

    private final FurikomiService furikomiService;

    public FurikomiController(FurikomiService furikomiService) {
        this.furikomiService = furikomiService;
    }

    @PostMapping(value = "/api/furikomi", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<String> furikomi(HttpServletRequest req) {
        return CgiResp.ok(furikomiService.MAIN(new CgiRequest(req)));
    }
}
