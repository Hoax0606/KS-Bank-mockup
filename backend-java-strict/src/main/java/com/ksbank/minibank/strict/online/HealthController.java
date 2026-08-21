package com.ksbank.minibank.strict.online;

import java.sql.SQLException;
import java.sql.Statement;
import com.ksbank.minibank.strict.online.db.PDBCONService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** 스캐폴딩/배포 확인용 헬스체크. DriverManager로 간단히 접속 확인만 한다. */
@RestController
public class HealthController {

    @GetMapping(value = "/api/health", produces = MediaType.APPLICATION_JSON_VALUE)
    public String health() {
        boolean dbUp = true;
        try {
            PDBCONService.DB_CONNECT();
            try (Statement st = PDBCONService.CONN().createStatement()) {
                st.execute("SELECT 1");
            }
        } catch (Exception e) {
            dbUp = false;
        } finally {
            try {
                PDBCONService.DB_DISCONNECT();
            } catch (Exception ignore) {
                // best-effort
            }
        }
        return "{\"ok\":true,\"service\":\"minibank-backend-strict\",\"db\":\"" + (dbUp ? "up" : "down") + "\"}";
    }
}
