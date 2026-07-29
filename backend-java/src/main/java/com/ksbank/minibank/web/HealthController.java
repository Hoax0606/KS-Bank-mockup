package com.ksbank.minibank.web;

import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 스캐폴딩 확인용 헬스체크. 실제 업무 엔드포인트(/api/login 등)는 이후 단계에서 추가. */
@RestController
@RequestMapping("/api")
public class HealthController {

    private final JdbcTemplate jdbc;

    public HealthController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("ok", true);
        m.put("service", "minibank-backend (java)");
        try {
            jdbc.queryForObject("SELECT 1", Integer.class);
            m.put("db", "up");
        } catch (Exception e) {
            m.put("db", "down");
        }
        return m;
    }
}
