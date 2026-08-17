package com.ksbank.minibank.strict.online.notice;

import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

/**
 * 얇은 어댑터. GET/POST 모두 /api/notice 하나로 매핑하고, COBOL이 한 프로그램 안에서
 * IF CGI-METHOD="POST" 로 분기하듯 {@link Notice#run} 내부에서 분기한다.
 */
@RestController
public class NoticeController {

    @RequestMapping(value = "/api/notice", method = {RequestMethod.GET, RequestMethod.POST},
                     produces = MediaType.APPLICATION_JSON_VALUE)
    public String notice(HttpServletRequest req) {
        return new Notice().run(new CgiRequest(req));
    }
}
