package com.ksbank.minibank.repository;

import java.sql.Types;
import java.util.List;
import com.ksbank.minibank.domain.TxnRow;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** TORIHIKI(거래) 기록 + 시퀀스 채번. COBOL EXEC SQL(INSERT/NEXTVAL) 대체. */
@Repository
public class TransactionRepository {

    private final JdbcTemplate jdbc;

    public TransactionRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public long nextTorihikiId() {
        Long v = jdbc.queryForObject("SELECT nextval('seq_torihiki')", Long.class);
        return v == null ? 0 : v;
    }

    public long nextReceiptSeq() {
        Long v = jdbc.queryForObject("SELECT nextval('seq_receipt_asis')", Long.class);
        return v == null ? 0 : v;
    }

    private static final String INSERT_SQL = """
        INSERT INTO torihiki
          (torihiki_id, kouza_no, torihiki_dt, torihiki_kbn,
           kingaku, aite_kouza, tesuryo, tekiyou)
        VALUES (?, ?, ?, ?, ?, ?, ?, NULL)
        """;

    /** 거래 1행 기록. aite/tesuryo 는 nullable. */
    public void insert(long torihikiId, int kouzaNo, String dt, String kbn,
                       long kingaku, Integer aiteKouza, Integer tesuryo) {
        jdbc.update(INSERT_SQL, ps -> {
            ps.setLong(1, torihikiId);
            ps.setInt(2, kouzaNo);
            ps.setString(3, dt);
            ps.setString(4, kbn);
            ps.setLong(5, kingaku);
            if (aiteKouza != null) ps.setInt(6, aiteKouza); else ps.setNull(6, Types.INTEGER);
            if (tesuryo != null)   ps.setInt(7, tesuryo);   else ps.setNull(7, Types.INTEGER);
        });
    }

    private static final String BY_KOUZA_SQL = """
        SELECT torihiki_dt, torihiki_kbn, kingaku, tesuryo, tekiyou, aite_kouza
          FROM torihiki
         WHERE kouza_no = ?
         ORDER BY torihiki_dt ASC, torihiki_id ASC
        """;

    /** 계좌의 전체 거래를 시간 오름차순으로(명세 계산용). */
    public List<TxnRow> findByKouza(int kouzaNo) {
        return jdbc.query(BY_KOUZA_SQL,
            ps -> ps.setInt(1, kouzaNo),
            (rs, i) -> new TxnRow(rs.getString(1), rs.getString(2), rs.getLong(3),
                                  rs.getLong(4), rs.getString(5), rs.getLong(6)));
    }
}
