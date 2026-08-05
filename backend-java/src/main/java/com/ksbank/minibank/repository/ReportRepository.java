package com.ksbank.minibank.repository;

import java.util.List;
import com.ksbank.minibank.domain.AcctAgg;
import com.ksbank.minibank.domain.BatchTxn;
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
            SELECT kouza_no, meigi_kanji, meigi_kana, shubetsu, joutai,
                   zandaka, kaisetsu_bi
              FROM kouza ORDER BY kouza_no""",
            (rs, i) -> new AcctAgg(rs.getInt(1), rs.getString(2), rs.getString(3),
                                   rs.getString(4), rs.getString(5),
                                   rs.getLong(6), rs.getString(7)));
    }

    /**
     * 배치 입력 거래 전건. COBOL {@code MKDAT} + {@code SORTDAT} 를 한 쿼리로 흡수.
     *
     * <p>🔒 <b>{@code ORDER BY kouza_no, torihiki_id} 는 건드리지 말 것.</b>
     * {@code MKDAT.cbl:42} 의 {@code ORDER BY KOUZA_NO, TORIHIKI_ID} 와 정확히 같아야 한다.
     * 明細의 {@code 取引後残高} 는 이 순서대로 期首부터 누적해 만들므로 <b>순서가 값을 바꾼다.</b>
     * 온라인 {@link TransactionRepository#findByKouza}(정렬키 {@code (dt, id)})와 통일하려는
     * "정리"를 하면 COBOL 파리티가 조용히 깨진다.
     */
    public List<BatchTxn> allTxnsForBatch() {
        return jdbc.query("""
            SELECT torihiki_id, kouza_no, torihiki_dt, torihiki_kbn,
                   kingaku, COALESCE(tesuryo, 0)
              FROM torihiki
             ORDER BY kouza_no, torihiki_id""",
            (rs, i) -> new BatchTxn(rs.getLong(1), rs.getInt(2), rs.getString(3),
                                    rs.getString(4), rs.getLong(5), rs.getLong(6)));
    }

    public List<TxnAgg> allTxns() {
        return jdbc.query("SELECT torihiki_kbn, kingaku, tesuryo FROM torihiki",
            (rs, i) -> {
                Object tes = rs.getObject(3);
                return new TxnAgg(rs.getString(1), rs.getLong(2),
                                  tes == null ? null : ((Number) tes).longValue());
            });
    }

    /** 무거래(휴면 후보) 계좌 번호 목록. */
    public List<Long> dormantAccounts() {
        return jdbc.query("""
            SELECT k.kouza_no FROM kouza k
             WHERE NOT EXISTS (SELECT 1 FROM torihiki t WHERE t.kouza_no = k.kouza_no)
             ORDER BY k.kouza_no""",
            (rs, i) -> rs.getLong(1));
    }

    public boolean hasTxn(int kouzaNo) {
        Integer n = jdbc.query("SELECT count(*) FROM torihiki WHERE kouza_no = ?",
            ps -> ps.setInt(1, kouzaNo),
            rs -> rs.next() ? rs.getInt(1) : 0);
        return n != null && n > 0;
    }

    public long txnCount() {
        Long n = jdbc.queryForObject("SELECT count(*) FROM torihiki", Long.class);
        return n == null ? 0 : n;
    }
}
