package com.ksbank.minibank.web;

import java.util.Map;
import com.ksbank.minibank.service.TransferService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** 振込(이체) 엔드포인트. 계약: POST /api/furikomi (kouza, aite, kingaku). */
@RestController
public class TransferController {

    private final TransferService transfer;

    public TransferController(TransferService transfer) {
        this.transfer = transfer;
    }

    @PostMapping(value = "/api/furikomi", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> furikomi(@RequestParam(required = false) String kouza,
                                        @RequestParam(required = false) String aite,
                                        @RequestParam(required = false) String kingaku) {
        return transfer.transfer(kouza, aite, kingaku);
    }
}
