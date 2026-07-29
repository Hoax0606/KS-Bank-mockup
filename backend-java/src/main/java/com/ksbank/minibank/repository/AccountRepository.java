package com.ksbank.minibank.repository;

import java.util.Optional;
import com.ksbank.minibank.domain.AccountDetail;
import com.ksbank.minibank.domain.AccountRow;
import com.ksbank.minibank.domain.BalanceRow;
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

    /** 잔액/상태 조회(이체 등에서 사용). 없으면 empty. */
    public Optional<BalanceRow> findBalance(byte[] kouzaNo) {
        return jdbc.query("SELECT zandaka, joutai FROM kouza WHERE kouza_no = ?",
            ps -> ps.setBytes(1, kouzaNo),
            rs -> rs.next()
                ? Optional.of(new BalanceRow(rs.getBytes("zandaka"), rs.getBytes("joutai")))
                : Optional.empty());
    }

    /** 자행 계좌 존재 여부. */
    public boolean exists(byte[] kouzaNo) {
        Integer n = jdbc.query("SELECT count(*) FROM kouza WHERE kouza_no = ?",
            ps -> ps.setBytes(1, kouzaNo),
            rs -> rs.next() ? rs.getInt(1) : 0);
        return n != null && n > 0;
    }

    /** 잔액 갱신(RAW COMP-3). */
    public void updateBalance(byte[] kouzaNo, byte[] zandakaRaw) {
        jdbc.update("UPDATE kouza SET zandaka = ? WHERE kouza_no = ?", ps -> {
            ps.setBytes(1, zandakaRaw);
            ps.setBytes(2, kouzaNo);
        });
    }

    private static final String DETAIL_SQL = """
        SELECT k.meigi_kanji, k.meigi_kana, k.shubetsu, k.joutai, k.zandaka,
               e.acct_type, e.branch_code, e.is_primary, e.kanji_utf8, e.kana_utf8
          FROM kouza k
          JOIN kouza_ext e ON e.kouza_no = k.kouza_no
         WHERE k.kouza_no = ?
        """;

    public long nextKouzaDyn() {
        Long v = jdbc.queryForObject("SELECT nextval('seq_kouza_dyn')", Long.class);
        return v == null ? 0 : v;
    }

    /** KOUZA 신규 삽입(개설). */
    public void insertKouza(byte[] no, byte[] kanji, byte[] kana, byte[] shubetsu,
                            byte[] zandaka, byte[] kaisetsu, byte[] joutai) {
        jdbc.update("""
            INSERT INTO kouza (kouza_no, meigi_kanji, meigi_kana, shubetsu,
                               zandaka, kaisetsu_bi, joutai)
            VALUES (?,?,?,?,?,?,?)""", ps -> {
            ps.setBytes(1, no); ps.setBytes(2, kanji); ps.setBytes(3, kana);
            ps.setBytes(4, shubetsu); ps.setBytes(5, zandaka);
            ps.setBytes(6, kaisetsu); ps.setBytes(7, joutai);
        });
    }

    /** KOUZA_EXT 신규 삽입(필수 컬럼 + UTF-8 미러; 프로필은 NULL). */
    public void insertKouzaExt(byte[] no, byte[] branch, byte[] acctType, byte[] pw,
                               byte[] isPrimary, String kanjiMirror, String kanaMirror) {
        jdbc.update("""
            INSERT INTO kouza_ext (kouza_no, branch_code, acct_type, password,
                                   is_primary, kanji_utf8, kana_utf8)
            VALUES (?,?,?,?,?,?,?)""", ps -> {
            ps.setBytes(1, no); ps.setBytes(2, branch); ps.setBytes(3, acctType);
            ps.setBytes(4, pw); ps.setBytes(5, isPrimary);
            ps.setString(6, kanjiMirror); ps.setString(7, kanaMirror);
        });
    }

    /** 계좌 상세(KOUZA+KOUZA_EXT). 없으면 empty. */
    public Optional<AccountDetail> findDetail(byte[] kouzaNo) {
        return jdbc.query(DETAIL_SQL,
            ps -> ps.setBytes(1, kouzaNo),
            rs -> rs.next()
                ? Optional.of(new AccountDetail(
                    rs.getBytes(1), rs.getBytes(2), rs.getBytes(3), rs.getBytes(4), rs.getBytes(5),
                    rs.getBytes(6), rs.getBytes(7), rs.getBytes(8), rs.getString(9), rs.getString(10)))
                : Optional.empty());
    }
}
