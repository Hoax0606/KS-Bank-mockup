package com.ksbank.minibank.repository;

import java.sql.Types;
import java.util.List;
import com.ksbank.minibank.domain.NoticeRow;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** NOTICE_ASIS 접근. COBOL NOTICE.cbl 의 EXEC SQL 대체. */
@Repository
public class NoticeRepository {

    private final JdbcTemplate jdbc;

    public NoticeRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public long nextNoticeId() {
        Long v = jdbc.queryForObject("SELECT nextval('seq_notice_asis')", Long.class);
        return v == null ? 0 : v;
    }

    /** 유효 공지 목록(새로운 순). */
    public List<NoticeRow> listActive(byte[] activeFlag) {
        return jdbc.query("""
            SELECT notice_date, tag, title FROM notice_asis
             WHERE is_active = ? ORDER BY notice_date DESC, notice_id DESC""",
            ps -> ps.setBytes(1, activeFlag),
            (rs, i) -> new NoticeRow(rs.getBytes(1), rs.getBytes(2), rs.getBytes(3)));
    }

    public void insert(byte[] id, byte[] date, byte[] tag, byte[] title,
                       byte[] body, byte[] active) {
        jdbc.update("""
            INSERT INTO notice_asis (notice_id, notice_date, tag, title, body, is_active)
            VALUES (?,?,?,?,?,?)""", ps -> {
            ps.setBytes(1, id); ps.setBytes(2, date); ps.setBytes(3, tag);
            ps.setBytes(4, title);
            if (body != null) ps.setBytes(5, body); else ps.setNull(5, Types.BINARY);
            ps.setBytes(6, active);
        });
    }
}
