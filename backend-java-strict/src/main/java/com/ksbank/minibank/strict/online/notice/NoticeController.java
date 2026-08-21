package com.ksbank.minibank.strict.online.notice;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;
import com.ksbank.minibank.strict.online.dto.NOTICEDto;

@RestController
public class NOTICEController {

    private final NOTICEService noticeService;

    public NOTICEController(NOTICEService noticeService) {
        this.noticeService = noticeService;
    }

    @RequestMapping(value = "/api/notice", method = {RequestMethod.GET, RequestMethod.POST})
    public void notice() {
        NOTICEDto dto = new NOTICEDto();
        noticeService.MAIN(dto);
    }
}
