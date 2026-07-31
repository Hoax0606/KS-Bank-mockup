package com.ksbank.minibank.service;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import com.ksbank.minibank.config.GlobalExceptionHandler.BusinessException;
import com.ksbank.minibank.domain.NoticeRow;
import com.ksbank.minibank.repository.NoticeRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** お知らせ 목록/생성. COBOL NOTICE.cbl 대체. IS_ACTIVE='Y'. */
@Service
public class NoticeService {

    private static final String ACTIVE_Y = "Y";
    private static final DateTimeFormatter YMD = DateTimeFormatter.ofPattern("yyyyMMdd");

    private final NoticeRepository notices;

    public NoticeService(NoticeRepository notices) {
        this.notices = notices;
    }

    /** GET /api/notice */
    public Map<String, Object> list() {
        List<Map<String, Object>> out = new ArrayList<>();
        for (NoticeRow r : notices.listActive(ACTIVE_Y)) {
            String d = nz(r.noticeDate());   // "YYYYMMDD"
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("date", d.length() == 8 ? d.substring(0,4)+"/"+d.substring(4,6)+"/"+d.substring(6,8) : d);
            m.put("tag", nz(r.tag()));
            m.put("title", nz(r.title()));
            out.add(m);
        }
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("ok", true);
        res.put("notices", out);
        return res;
    }

    /** POST /api/notice */
    @Transactional
    public Map<String, Object> create(String title, String body, String tag) {
        if (title == null || title.isBlank())
            throw new BusinessException(HttpStatus.BAD_REQUEST, "missing_title");
        String t = (tag == null || tag.isBlank()) ? "新着" : tag;
        String date = LocalDate.now().format(YMD);
        long id = notices.nextNoticeId();

        String bodyVal = (body == null || body.isBlank()) ? null : body;
        notices.insert(id, date, t, title, bodyVal, ACTIVE_Y);

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("ok", true);
        res.put("noticeId", id);
        return res;
    }

    private static String nz(String s) { return s == null ? "" : s; }
}
