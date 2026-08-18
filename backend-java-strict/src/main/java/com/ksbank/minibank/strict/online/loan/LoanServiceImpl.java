package com.ksbank.minibank.strict.online.loan;

import java.sql.Connection;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.springframework.stereotype.Service;
import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.dao.LoanDao;
import com.ksbank.minibank.strict.online.db.Db;
import com.ksbank.minibank.strict.online.dto.CLoanDto;
import com.ksbank.minibank.strict.online.dto.LoanDto;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.NumFmt;

/**
 * COBOL LOAN.cbl 1:1 포팅. GET=목록(DO-LIST), POST=신청(DO-APPLY).
 * ※ 원본처럼 최상위에서 kouza 파라미터의 "누락" 자체를 체크하지 않는다 — NUMVAL(빈 값이면 0)
 *   후 그대로 진행한다(HOLDINGS와 마찬가지로 COBOL 원본의 실제 동작).
 */
@Service
public class LoanServiceImpl implements LoanService {

    private static final long LOAN_AVAIL = 3_000_000;
    private static final DateTimeFormatter DT14 = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");

    private final SqlSessionFactory sqlSessionFactory;

    public LoanServiceImpl(SqlSessionFactory sqlSessionFactory) {
        this.sqlSessionFactory = sqlSessionFactory;
    }

    @Override
    public String MAIN(CgiRequest cgi) {
        LoanDto dto = new LoanDto();
        dto.setHV_KOUZA(pic9(numval(cgi.param("kouza").value()), 7));

        Connection conn = Db.DB_CONNECT();
        try (SqlSession session = sqlSessionFactory.openSession(conn)) {
            LoanDao dao = session.getMapper(LoanDao.class);
            if ("POST".equals(cgi.method())) {
                return DO_APPLY(cgi, conn, dao, dto);
            } else {
                return DO_LIST(dao, dto);
            }
        } finally {
            Db.DB_DISCONNECT(conn);
        }
    }

    private String DO_LIST(LoanDao dao, LoanDto dto) {
        StringBuilder RESP_BUF = new StringBuilder();
        RESP_BUF.append("{\"ok\":true,\"loans\":[");
        dto.setFIRST_ROW("Y");

        // KS_JAVA_START
        try {
            List<CLoanDto> list = dao.select_01(dto);
            int SQLCODE = 0;
            int i = 0;
            while (SQLCODE == 0) {
                if (i < list.size()) {
                    dto.setCLoanDto(list.get(i));
                    i++;
                    SQLCODE = 0;
                    EMIT_LOAN(dto, RESP_BUF);
                } else {
                    SQLCODE = 100;
                }
            }
        } catch (Exception e) {
        }
        // KS_JAVA_END

        RESP_BUF.append("]}");
        return RESP_BUF.toString();
    }

    private void EMIT_LOAN(LoanDto dto, StringBuilder RESP_BUF) {
        CLoanDto c = dto.getCLoanDto();
        if ("Y".equals(dto.getFIRST_ROW())) {
            dto.setFIRST_ROW("N");
        } else {
            RESP_BUF.append(',');
        }
        RESP_BUF.append("{\"loanId\":").append(NumFmt.trim(c.getC_ID()))
                .append(",\"principal\":").append(NumFmt.trim(c.getC_PRIN()))
                .append(",\"balance\":").append(NumFmt.trim(c.getC_BAL()))
                .append(",\"method\":\"").append(c.getC_METHOD())
                .append("\",\"years\":").append(NumFmt.trim(c.getC_YEARS()))
                .append('}');
    }

    private String DO_APPLY(CgiRequest cgi, Connection conn, LoanDao dao, LoanDto dto) {
        dto.setHV_AMT(numval(cgi.param("amt").value()));

        String rawMethod = cgi.param("method").value();
        String hvMethod = rawMethod.isEmpty() ? " " : rawMethod.substring(0, 1);
        if (!"A".equals(hvMethod) && !"B".equals(hvMethod) && !"C".equals(hvMethod)) {
            hvMethod = "A";
        }
        dto.setHV_METHOD(hvMethod);

        dto.setHV_YEARS(pic9(numval(cgi.param("years").value()), 3));

        if (dto.getHV_AMT() <= 0) {
            throw CgiError.ERR_400("invalid_amount");
        }

        // KS_JAVA_START
        try {
            long result = dao.select_02(dto);
            dto.setHV_USED(result);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
        // KS_JAVA_END
        if (dto.getHV_USED() + dto.getHV_AMT() > LOAN_AVAIL) {
            throw CgiError.ERR_409("loan_over_limit");
        }

        // KS_JAVA_START
        try {
            long result = dao.select_03(dto);
            dto.setHV_CNT(result);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
        // KS_JAVA_END
        if (dto.getHV_CNT() == 0) {
            throw CgiError.ERR_404("kouza_not_found");
        }

        // KS_JAVA_START
        try {
            LoanDto result = dao.select_04(dto);
            dto.setHV_LOANID(result.getHV_LOANID());
            dto.setHV_TID(result.getHV_TID());
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
        // KS_JAVA_END

        dto.setHV_DT(LocalDateTime.now().format(DT14));
        dto.setHV_BAL(dto.getHV_AMT());

        // KS_JAVA_START
        try {
            dao.insert_01(dto);
        } catch (Exception e) {
            throw loanAbort(conn);
        }
        // KS_JAVA_END

        // COBOL도 이 SELECT ZANDAKA 뒤에는 SQLCODE 체크가 없지만(방금 KOUZA_NO 존재를
        // 확인했으니 실패하지 않는다는 전제), 위 INSERT INTO LOAN_ASIS가 이미 실행된
        // 상태이므로 Java에서 여기서 예외가 나면 반드시 ROLLBACK을 거쳐야 한다.
        // KS_JAVA_START
        try {
            long result = dao.select_05(dto);
            dto.setHV_ZAN(result);
        } catch (Exception e) {
            throw loanAbort(conn);
        }
        // KS_JAVA_END
        dto.setHV_ZAN(dto.getHV_ZAN() + dto.getHV_AMT());

        // KS_JAVA_START
        try {
            dao.update_01(dto);
        } catch (Exception e) {
            throw loanAbort(conn);
        }
        // KS_JAVA_END

        // KS_JAVA_START
        try {
            dao.insert_02(dto);
        } catch (Exception e) {
            throw loanAbort(conn);
        }
        // KS_JAVA_END

        try {
            conn.commit();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }

        StringBuilder sb = new StringBuilder();
        sb.append("{\"ok\":true,\"loanId\":").append(NumFmt.trim(dto.getHV_LOANID()))
          .append(",\"kouza\":\"").append(zpad7(dto.getHV_KOUZA()))
          .append("\",\"amount\":").append(NumFmt.trim(dto.getHV_AMT()))
          .append('}');
        return sb.toString();
    }

    /**
     * COBOL LOAN-ABORT(named) — ROLLBACK 후 CgiError. disconnect는 run()의 finally가 담당.
     * 직접 throw하지 않고 CgiError를 반환해서 호출부가 {@code throw loanAbort(conn);}으로
     * 쓰게 한다 — SELECT 직후 지역변수에 대입하는 자리(대출 INSERT 후 잔액 재조회)에서도
     * catch 블록이 반드시 흐름을 끊는다는 것을 컴파일러의 definite-assignment 분석이
     * 인식하게 하기 위함.
     */
    private static CgiError loanAbort(Connection conn) {
        try {
            conn.rollback();
        } catch (Exception ignore) {
            // best-effort, COBOL EXEC SQL ROLLBACK도 결과를 확인하지 않는다.
        }
        return CgiError.ERR_500("loan_failed");
    }

    static long numval(String s) {
        if (s == null) return 0;
        s = s.trim();
        if (s.isEmpty()) return 0;
        try {
            return (long) Double.parseDouble(s);
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    static long pic9(long v, int digits) {
        long av = Math.abs(v);
        long mod = (long) Math.pow(10, digits);
        return av % mod;
    }

    static String zpad7(long v) {
        return String.format("%07d", v);
    }
}
