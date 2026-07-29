package com.ksbank.minibank.repository;

import java.sql.Types;
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

    /** 거래 1행 기록(RAW 바이트). aite/tesuryo 는 nullable. */
    public void insert(byte[] torihikiId, byte[] kouzaNo, byte[] dt, byte[] kbn,
                       byte[] kingaku, byte[] aiteKouza, byte[] tesuryo) {
        jdbc.update(INSERT_SQL, ps -> {
            ps.setBytes(1, torihikiId);
            ps.setBytes(2, kouzaNo);
            ps.setBytes(3, dt);
            ps.setBytes(4, kbn);
            ps.setBytes(5, kingaku);
            if (aiteKouza != null) ps.setBytes(6, aiteKouza); else ps.setNull(6, Types.BINARY);
            if (tesuryo != null)   ps.setBytes(7, tesuryo);   else ps.setNull(7, Types.BINARY);
        });
    }
}
