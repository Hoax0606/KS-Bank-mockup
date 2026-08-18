package com.ksbank.minibank.strict.online.zandaka;

import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.cgi.CgiResp;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ZandakaController {

    private final ZandakaService zandakaService;

    public ZandakaController(ZandakaService zandakaService) {
        this.zandakaService = zandakaService;
    }

    @GetMapping(value = "/api/zandaka", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<String> zandaka(HttpServletRequest req) {
        return CgiResp.ok(zandakaService.MAIN(new CgiRequest(req)));
    }
}
