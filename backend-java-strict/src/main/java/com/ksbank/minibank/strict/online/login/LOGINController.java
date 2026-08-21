package com.ksbank.minibank.strict.online.login;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;
import com.ksbank.minibank.strict.online.dto.LOGINDto;

@RestController
public class LOGINController {

    private final LOGINService loginService;

    public LOGINController(LOGINService loginService) {
        this.loginService = loginService;
    }

    @RequestMapping(value = "/api/login", method = {RequestMethod.GET, RequestMethod.POST})
    public void login() {
        LOGINDto dto = new LOGINDto();
        loginService.MAIN(dto);
    }
}
