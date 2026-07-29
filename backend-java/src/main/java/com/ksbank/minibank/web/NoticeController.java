package com.ksbank.minibank.web;

import java.util.Map;
import com.ksbank.minibank.service.NoticeService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** お知らせ. GET /api/notice(목록) / POST /api/notice(생성). */
@RestController
public class NoticeController {

    private final NoticeService notices;

    public NoticeController(NoticeService notices) {
        this.notices = notices;
    }

    @GetMapping(value = "/api/notice", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> list() {
        return notices.list();
    }

    @PostMapping(value = "/api/notice", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> create(@RequestParam(required = false) String title,
                                      @RequestParam(required = false) String body,
                                      @RequestParam(required = false) String tag) {
        return notices.create(title, body, tag);
    }
}
