package com.ksbank.minibank.repository;

import java.util.Optional;
import com.ksbank.minibank.domain.AccountRow;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * KOUZA/KOUZA_EXT 접근. COBOL EXEC SQL + GixSQL 대체.
 * RAW 컬럼은 {@code bytea} 이므로 {@code setBytes/getBytes} 로 바이트 직접 바인딩(HEXTORAW 불필요).
 */
@Repository
public class AccountRepository {

    private final JdbcTemplate jdbc;

    public AccountRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static final String LOGIN_SQL = """
        SELECT k.meigi_kanji, k.shubetsu, k.joutai, k.zandaka,
               e.acct_type, e.kanji_utf8
          FROM kouza k
          JOIN kouza_ext e ON e.kouza_no = k.kouza_no
         WHERE e.kouza_no    = ?
           AND e.branch_code = ?
           AND e.password    = ?
        """;

    /** 店番+口座+PW(모두 RAW 바이트) 일치 계좌 조회. 없으면 empty(=invalid_login). */
    public Optional<AccountRow> findForLogin(byte[] kouzaNo, byte[] branchCode, byte[] password) {
        return jdbc.query(LOGIN_SQL,
            ps -> {
                ps.setBytes(1, kouzaNo);
                ps.setBytes(2, branchCode);
                ps.setBytes(3, password);
            },
            rs -> rs.next()
                ? Optional.of(new AccountRow(
                    rs.getBytes("meigi_kanji"), rs.getBytes("shubetsu"),
                    rs.getBytes("joutai"), rs.getBytes("zandaka"),
                    rs.getBytes("acct_type"), rs.getString("kanji_utf8")))
                : Optional.empty());
    }
}
