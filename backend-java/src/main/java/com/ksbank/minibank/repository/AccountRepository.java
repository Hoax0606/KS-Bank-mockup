package com.ksbank.minibank.repository;

import java.util.Optional;
import com.ksbank.minibank.domain.AccountDetail;
import com.ksbank.minibank.domain.AccountRow;
import com.ksbank.minibank.domain.BalanceRow;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * KOUZA/KOUZA_EXT 접근. COBOL EXEC SQL + GixSQL 대체.
 * 전 컬럼 일반 타입(UTF-8 텍스트 / integer·bigint 숫자) — setInt/setLong/setString 로 직접 바인딩.
 */
@Repository
public class AccountRepository {

    private final JdbcTemplate jdbc;

    public AccountRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static final String LOGIN_SQL = """
        SELECT k.meigi_kanji, k.shubetsu, k.joutai, k.zandaka,
               e.acct_type
          FROM kouza k
          JOIN kouza_ext e ON e.kouza_no = k.kouza_no
         WHERE e.kouza_no    = ?
           AND e.branch_code = ?
           AND e.password    = ?
        """;

    /** 店番+口座+PW 일치 계좌 조회. 없으면 empty(=invalid_login). */
    public Optional<AccountRow> findForLogin(int kouzaNo, String branchCode, String password) {
        return jdbc.query(LOGIN_SQL,
            ps -> {
                ps.setInt(1, kouzaNo);
                ps.setString(2, branchCode);
                ps.setString(3, password);
            },
            rs -> rs.next()
                ? Optional.of(new AccountRow(
                    rs.getString("meigi_kanji"), rs.getString("shubetsu"),
                    rs.getString("joutai"), rs.getLong("zandaka"),
                    rs.getString("acct_type")))
                : Optional.empty());
    }

    /** 잔액/상태 조회(이체 등에서 사용). 없으면 empty. */
    public Optional<BalanceRow> findBalance(int kouzaNo) {
        return jdbc.query("SELECT zandaka, joutai FROM kouza WHERE kouza_no = ?",
            ps -> ps.setInt(1, kouzaNo),
            rs -> rs.next()
                ? Optional.of(new BalanceRow(rs.getLong("zandaka"), rs.getString("joutai")))
                : Optional.empty());
    }

    /** 자행 계좌 존재 여부. */
    public boolean exists(int kouzaNo) {
        Integer n = jdbc.query("SELECT count(*) FROM kouza WHERE kouza_no = ?",
            ps -> ps.setInt(1, kouzaNo),
            rs -> rs.next() ? rs.getInt(1) : 0);
        return n != null && n > 0;
    }

    /** 잔액 갱신. */
    public void updateBalance(int kouzaNo, long zandaka) {
        jdbc.update("UPDATE kouza SET zandaka = ? WHERE kouza_no = ?", ps -> {
            ps.setLong(1, zandaka);
            ps.setInt(2, kouzaNo);
        });
    }

    private static final String DETAIL_SQL = """
        SELECT k.meigi_kanji, k.meigi_kana, k.shubetsu, k.joutai, k.zandaka,
               e.acct_type, e.branch_code, e.is_primary
          FROM kouza k
          JOIN kouza_ext e ON e.kouza_no = k.kouza_no
         WHERE k.kouza_no = ?
        """;

    public long nextKouzaDyn() {
        Long v = jdbc.queryForObject("SELECT nextval('seq_kouza_dyn')", Long.class);
        return v == null ? 0 : v;
    }

    /** KOUZA 신규 삽입(개설). */
    public void insertKouza(int no, String kanji, String kana, String shubetsu,
                            long zandaka, String kaisetsu, String joutai) {
        jdbc.update("""
            INSERT INTO kouza (kouza_no, meigi_kanji, meigi_kana, shubetsu,
                               zandaka, kaisetsu_bi, joutai)
            VALUES (?,?,?,?,?,?,?)""", ps -> {
            ps.setInt(1, no); ps.setString(2, kanji); ps.setString(3, kana);
            ps.setString(4, shubetsu); ps.setLong(5, zandaka);
            ps.setString(6, kaisetsu); ps.setString(7, joutai);
        });
    }

    /** KOUZA_EXT 신규 삽입(필수 컬럼; 프로필은 NULL). */
    public void insertKouzaExt(int no, String branch, String acctType, String pw,
                               String isPrimary) {
        jdbc.update("""
            INSERT INTO kouza_ext (kouza_no, branch_code, acct_type, password,
                                   is_primary)
            VALUES (?,?,?,?,?)""", ps -> {
            ps.setInt(1, no); ps.setString(2, branch); ps.setString(3, acctType);
            ps.setString(4, pw); ps.setString(5, isPrimary);
        });
    }

    /** 계좌 상세(KOUZA+KOUZA_EXT). 없으면 empty. */
    public Optional<AccountDetail> findDetail(int kouzaNo) {
        return jdbc.query(DETAIL_SQL,
            ps -> ps.setInt(1, kouzaNo),
            rs -> rs.next()
                ? Optional.of(new AccountDetail(
                    rs.getString(1), rs.getString(2), rs.getString(3), rs.getString(4), rs.getLong(5),
                    rs.getString(6), rs.getString(7), rs.getString(8)))
                : Optional.empty());
    }
}
