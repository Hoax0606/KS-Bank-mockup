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
    public List<NoticeRow> listActive(String activeFlag) {
        return jdbc.query("""
            SELECT notice_date, tag, title FROM notice_asis
             WHERE is_active = ? ORDER BY notice_date DESC, notice_id DESC""",
            ps -> ps.setString(1, activeFlag),
            (rs, i) -> new NoticeRow(rs.getString(1), rs.getString(2), rs.getString(3)));
    }

    public void insert(long id, String date, String tag, String title,
                       String body, String active) {
        jdbc.update("""
            INSERT INTO notice_asis (notice_id, notice_date, tag, title, body, is_active)
            VALUES (?,?,?,?,?,?)""", ps -> {
            ps.setLong(1, id); ps.setString(2, date); ps.setString(3, tag);
            ps.setString(4, title);
            if (body != null) ps.setString(5, body); else ps.setNull(5, Types.VARCHAR);
            ps.setString(6, active);
        });
    }
}
