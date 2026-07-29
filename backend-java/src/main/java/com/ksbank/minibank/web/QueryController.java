package com.ksbank.minibank.web;

import java.util.Map;
import com.ksbank.minibank.service.AccountQueryService;
import com.ksbank.minibank.service.MeisaiService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** 조회 계열 엔드포인트(GET): zandaka / holdings / meisai. */
@RestController
public class QueryController {

    private final AccountQueryService query;
    private final MeisaiService meisai;

    public QueryController(AccountQueryService query, MeisaiService meisai) {
        this.query = query;
        this.meisai = meisai;
    }

    @GetMapping(value = "/api/zandaka", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> zandaka(@RequestParam(required = false) String kouza) {
        return query.zandaka(kouza);
    }

    @GetMapping(value = "/api/holdings", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> holdings(@RequestParam(required = false) String kouza) {
        return query.holdings(kouza);
    }

    @GetMapping(value = "/api/meisai", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> meisai(@RequestParam(required = false) String kouza,
                                      @RequestParam(required = false) String kbn,
                                      @RequestParam(required = false) String from,
                                      @RequestParam(required = false) String to) {
        return meisai.list(kouza, kbn, from, to);
    }
}
