package com.ksbank.minibank.strict.online.notice;

import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.cgi.CgiResp;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class NoticeController {

    private final NoticeService noticeService;

    public NoticeController(NoticeService noticeService) {
        this.noticeService = noticeService;
    }

    @RequestMapping(value = "/api/notice", method = {RequestMethod.GET, RequestMethod.POST},
                     produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<String> notice(HttpServletRequest req) {
        return CgiResp.ok(noticeService.MAIN(new CgiRequest(req)));
    }
}
