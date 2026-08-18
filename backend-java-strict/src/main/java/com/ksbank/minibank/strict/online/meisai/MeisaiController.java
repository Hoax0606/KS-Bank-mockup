package com.ksbank.minibank.strict.online.meisai;

import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.cgi.CgiResp;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class MeisaiController {

    private final MeisaiService meisaiService;

    public MeisaiController(MeisaiService meisaiService) {
        this.meisaiService = meisaiService;
    }

    @GetMapping(value = "/api/meisai", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<String> meisai(HttpServletRequest req) {
        return CgiResp.ok(meisaiService.MAIN(new CgiRequest(req)));
    }
}
