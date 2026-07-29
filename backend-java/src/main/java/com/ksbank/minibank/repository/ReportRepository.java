package com.ksbank.minibank.repository;

import java.util.List;
import com.ksbank.minibank.domain.AcctAgg;
import com.ksbank.minibank.domain.TxnAgg;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** 배치(帳票/통계) 집계 조회. COBOL 배치 프로그램들의 DB 접점 대체. */
@Repository
public class ReportRepository {

    private final JdbcTemplate jdbc;

    public ReportRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<AcctAgg> allAccounts() {
        return jdbc.query("""
            SELECT kouza_no, shubetsu, joutai, zandaka, kaisetsu_bi
              FROM kouza ORDER BY kouza_no""",
            (rs, i) -> new AcctAgg(rs.getBytes(1), rs.getBytes(2), rs.getBytes(3),
                                   rs.getBytes(4), rs.getBytes(5)));
    }

    public List<TxnAgg> allTxns() {
        return jdbc.query("SELECT torihiki_kbn, kingaku, tesuryo FROM torihiki",
            (rs, i) -> new TxnAgg(rs.getBytes(1), rs.getBytes(2), rs.getBytes(3)));
    }

    /** 무거래(휴면 후보) 계좌 번호 목록(RAW). */
    public List<byte[]> dormantAccounts() {
        return jdbc.query("""
            SELECT k.kouza_no FROM kouza k
             WHERE NOT EXISTS (SELECT 1 FROM torihiki t WHERE t.kouza_no = k.kouza_no)
             ORDER BY k.kouza_no""",
            (rs, i) -> rs.getBytes(1));
    }

    public boolean hasTxn(byte[] kouzaNo) {
        Integer n = jdbc.query("SELECT count(*) FROM torihiki WHERE kouza_no = ?",
            ps -> ps.setBytes(1, kouzaNo),
            rs -> rs.next() ? rs.getInt(1) : 0);
        return n != null && n > 0;
    }

    public long txnCount() {
        Long n = jdbc.queryForObject("SELECT count(*) FROM torihiki", Long.class);
        return n == null ? 0 : n;
    }
}
