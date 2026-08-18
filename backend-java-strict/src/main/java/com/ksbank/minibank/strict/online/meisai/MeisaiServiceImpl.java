package com.ksbank.minibank.strict.online.meisai;

import java.sql.Connection;
import java.util.ArrayList;
import java.util.List;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.springframework.stereotype.Service;
import com.ksbank.minibank.strict.online.cgi.CgiParam;
import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.dao.MeisaiDao;
import com.ksbank.minibank.strict.online.db.Db;
import com.ksbank.minibank.strict.online.dto.CMeisaiDto;
import com.ksbank.minibank.strict.online.dto.MeisaiDto;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.Cobol;
import com.ksbank.minibank.strict.online.util.NumFmt;

/**
 * COBOL MEISAI.cbl 1:1 포팅.
 * 전체 명세를 시간 오름차순으로 (COBOL {@code ROWS-TBL OCCURS 1000 TIMES} 대응) 1000건
 * 상한으로 적재하며 CALC-DELTA로 부호합계를 누적 -> 期首残高 = 현재잔액 - 합계 ->
 * 오름차순 재통과로 afterBal 확정 -> 내림차순 + 필터로 출력.
 */
@Service
public class MeisaiServiceImpl implements MeisaiService {

    private static final int ROWS_MAX = 1000;

    private final SqlSessionFactory sqlSessionFactory;

    public MeisaiServiceImpl(SqlSessionFactory sqlSessionFactory) {
        this.sqlSessionFactory = sqlSessionFactory;
    }

    @Override
    public String MAIN(CgiRequest cgi) {
        MeisaiDto dto = new MeisaiDto();
        CgiParam kouzaParam = cgi.param("kouza");
        if (!kouzaParam.found()) {
            throw CgiError.ERR_400("missing_kouza");
        }
        dto.setHV_KOUZA(Cobol.truncate(Cobol.NUMVAL(kouzaParam.value()), 7));

        READ_FILTERS(cgi, dto);

        List<CMeisaiDto> rows;
        int n;

        Connection conn = Db.DB_CONNECT();
        try (SqlSession session = sqlSessionFactory.openSession(conn)) {
            MeisaiDao dao = session.getMapper(MeisaiDao.class);

            // KS_JAVA_START
            try {
                long result = dao.select_02(dto);
                dto.setHV_CNT(result);
            } catch (Exception e) {
            }
            // KS_JAVA_END

            if (dto.getHV_CNT() == 0) {
                throw CgiError.ERR_404("kouza_not_found");
            }

            // KS_JAVA_START
            try {
                long result = dao.select_03(dto);
                dto.setHV_ZAN(result);
            } catch (Exception e) {
            }
            // KS_JAVA_END

            long wkSum = 0;
            // KS_JAVA_START
            try {
                List<CMeisaiDto> fetched = dao.select_01(dto);
                rows = fetched.size() > ROWS_MAX
                    ? new ArrayList<>(fetched.subList(0, ROWS_MAX))
                    : fetched;
                int SQLCODE = 0;
                int i = 0;
                while (SQLCODE == 0) {
                    if (i < rows.size()) {
                        dto.setCMeisaiDto(rows.get(i));
                        i++;
                        SQLCODE = 0;
                        wkSum += CALC_DELTA(dto.getCMeisaiDto());
                    } else {
                        SQLCODE = 100;
                    }
                }
            } catch (Exception e) {
                rows = new ArrayList<>();
            }
            // KS_JAVA_END

            n = rows.size();
            long wkOpening = dto.getHV_ZAN() - wkSum;
            long wkRun = wkOpening;
            for (int i = 0; i < n; i++) {
                wkRun += CALC_DELTA(rows.get(i));
                rows.get(i).setRW_AFTER(wkRun);
            }
        } finally {
            Db.DB_DISCONNECT(conn);
        }

        return BUILD_JSON(dto, rows, n);
    }

    /** COBOL CALC-DELTA — 이 프로그램 전용 독립 사본(배치 쪽과 공유하지 않음). */
    private long CALC_DELTA(CMeisaiDto row) {
        String kbn = row.getRW_KBN();
        if ("1".equals(kbn)) {
            return row.getRW_KIN();
        }
        if ("2".equals(kbn)) {
            return -row.getRW_KIN();
        }
        if ("3".equals(kbn)) {
            return -(row.getRW_KIN() + row.getRW_TES());
        }
        return 0;
    }

    private void READ_FILTERS(CgiRequest cgi, MeisaiDto dto) {
        dto.setWK_FILT_KBN("A");
        CgiParam kbnParam = cgi.param("kbn");
        if (kbnParam.found() && !kbnParam.value().isEmpty() && kbnParam.value().charAt(0) != ' ') {
            String v = kbnParam.value();
            if (v.length() >= 3 && v.substring(0, 3).equals("all")) {
                dto.setWK_FILT_KBN("A");
            } else {
                dto.setWK_FILT_KBN(v.substring(0, 1));
            }
        }
        CgiParam fromParam = cgi.param("from");
        if (fromParam.found()) {
            NORM_FROM(fromParam.value(), dto);
        }
        CgiParam toParam = cgi.param("to");
        if (toParam.found()) {
            NORM_TO(toParam.value(), dto);
        }
    }

    /** COBOL NORM-FROM: '-'/'/' -> ' ' 치환 -> TRIM -> PIC X(8) 이동(절단/공백채움). */
    private void NORM_FROM(String cpValue, MeisaiDto dto) {
        dto.setWK_FROM(normDate8(cpValue));
    }

    /** COBOL NORM-TO: '-'/'/' -> ' ' 치환 -> TRIM -> PIC X(8) 이동(절단/공백채움). */
    private void NORM_TO(String cpValue, MeisaiDto dto) {
        dto.setWK_TO(normDate8(cpValue));
    }

    private static String normDate8(String raw) {
        String tmp = raw == null ? "" : raw;
        if (tmp.length() > 16) {
            tmp = tmp.substring(0, 16);
        }
        tmp = tmp.replace('-', ' ').replace('/', ' ');
        String trimmed = tmp.trim();
        if (trimmed.length() >= 8) {
            return trimmed.substring(0, 8);
        }
        StringBuilder sb = new StringBuilder(trimmed);
        while (sb.length() < 8) {
            sb.append(' ');
        }
        return sb.toString();
    }

    private String BUILD_JSON(MeisaiDto dto, List<CMeisaiDto> rows, int n) {
        StringBuilder RESP_BUF = new StringBuilder();
        String WK_KOUZA_Z = Cobol.pic9(dto.getHV_KOUZA(), 7);
        RESP_BUF.append("{\"ok\":true,\"kouza\":\"").append(WK_KOUZA_Z).append("\",\"rows\":[");
        dto.setFIRST_ROW("Y");
        boolean fromBlank = dto.getWK_FROM() == null || dto.getWK_FROM().isBlank();
        boolean toBlank = dto.getWK_TO() == null || dto.getWK_TO().isBlank();
        for (int i = n - 1; i >= 0; i--) {
            CMeisaiDto row = rows.get(i);
            String kbn = row.getRW_KBN();
            if (!("A".equals(dto.getWK_FILT_KBN()) || dto.getWK_FILT_KBN().equals(kbn))) {
                continue;
            }
            String dt = row.getRW_DT();
            String dt8 = dt != null && dt.length() >= 8 ? dt.substring(0, 8) : dt;
            if (!fromBlank && dt8.compareTo(dto.getWK_FROM()) < 0) {
                continue;
            }
            if (!toBlank && dt8.compareTo(dto.getWK_TO()) > 0) {
                continue;
            }

            EMIT_ROW(dto, row, dt8, RESP_BUF);
        }
        RESP_BUF.append("]}");
        return RESP_BUF.toString();
    }

    private void EMIT_ROW(MeisaiDto dto, CMeisaiDto row, String dt8, StringBuilder RESP_BUF) {
        if ("Y".equals(dto.getFIRST_ROW())) {
            dto.setFIRST_ROW("N");
        } else {
            RESP_BUF.append(',');
        }
        RESP_BUF.append("{\"date\":\"")
                .append(dt8, 0, 4).append('-').append(dt8, 4, 6).append('-').append(dt8, 6, 8)
                .append("\",\"kbn\":\"").append(row.getRW_KBN())
                .append("\",\"kingaku\":").append(NumFmt.trim(row.getRW_KIN()))
                .append(",\"afterBal\":").append(NumFmt.trim(row.getRW_AFTER()))
                .append(",\"aite\":").append(NumFmt.trim(row.getRW_AITE()))
                .append(",\"memo\":\"");
        String tek = row.getRW_TEK();
        if (tek != null && !tek.isBlank()) {
            RESP_BUF.append(tek.trim());
        }
        RESP_BUF.append("\"}");
    }
}
