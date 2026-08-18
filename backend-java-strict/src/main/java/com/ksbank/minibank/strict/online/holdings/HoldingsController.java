package com.ksbank.minibank.strict.online.holdings;

import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.cgi.CgiResp;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HoldingsController {

    private final HoldingsService holdingsService;

    public HoldingsController(HoldingsService holdingsService) {
        this.holdingsService = holdingsService;
    }

    @GetMapping(value = "/api/holdings", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<String> holdings(HttpServletRequest req) {
        return CgiResp.ok(holdingsService.MAIN(new CgiRequest(req)));
    }
}
