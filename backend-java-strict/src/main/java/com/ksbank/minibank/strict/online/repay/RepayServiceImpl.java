package com.ksbank.minibank.strict.online.repay;

import java.sql.Connection;
import java.time.LocalDate;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.springframework.stereotype.Service;
import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.dao.RepayDao;
import com.ksbank.minibank.strict.online.db.Db;
import com.ksbank.minibank.strict.online.dto.RepayDto;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.NumFmt;

/**
 * COBOL REPAY.cbl 1:1 포팅.
 * 경과이자 = FUNCTION INTEGER(잔액*이율/100/12 + 0.5) (floor 방식, Math.round 아님).
 * 중도수수료 550 고정, 원자적(계좌차감+대출갱신+INSERT), 실패 시 named {@link #rpAbort}.
 */
@Service
public class RepayServiceImpl implements RepayService {

    private final SqlSessionFactory sqlSessionFactory;

    public RepayServiceImpl(SqlSessionFactory sqlSessionFactory) {
        this.sqlSessionFactory = sqlSessionFactory;
    }

    @Override
    public String MAIN(CgiRequest cgi) {
        RepayDto dto = new RepayDto();
        dto.setHV_LOANID(pic9(numval(cgi.param("loanId").value()), 12));
        dto.setHV_PRIN(numval(cgi.param("principal").value()));
        if (dto.getHV_PRIN() <= 0) {
            throw CgiError.ERR_400("invalid_amount");
        }

        boolean wkClosed;
        Connection conn = Db.DB_CONNECT();
        try (SqlSession session = sqlSessionFactory.openSession(conn)) {
            RepayDao dao = session.getMapper(RepayDao.class);

            // KS_JAVA_START
            try {
                long result = dao.select_01(dto);
                dto.setHV_CNT(result);
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
            // KS_JAVA_END
            if (dto.getHV_CNT() == 0) {
                throw CgiError.ERR_404("loan_not_found");
            }

            // KS_JAVA_START
            try {
                RepayDto result = dao.select_02(dto);
                dto.setHV_BAL(result.getHV_BAL());
                dto.setHV_RATE(result.getHV_RATE());
                dto.setHV_KOUZA(result.getHV_KOUZA());
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
            // KS_JAVA_END
            if (dto.getHV_PRIN() > dto.getHV_BAL()) {
                throw CgiError.ERR_409("over_balance");
            }

            long hvInt = (long) Math.floor(dto.getHV_BAL() * dto.getHV_RATE() / 100.0 / 12.0 + 0.5);
            dto.setHV_INT(hvInt);
            dto.setHV_TOTAL(dto.getHV_PRIN() + dto.getHV_INT() + dto.getHV_FEE());

            // KS_JAVA_START
            try {
                long result = dao.select_03(dto);
                dto.setHV_ZAN(result);
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
            // KS_JAVA_END
            if (dto.getHV_ZAN() < dto.getHV_TOTAL()) {
                throw CgiError.ERR_409("insufficient_funds");
            }

            long hvNewBal = dto.getHV_BAL() - dto.getHV_PRIN();
            dto.setHV_NEWBAL(hvNewBal);
            wkClosed = hvNewBal <= 0;

            // ===== 트랜잭션 시작 =====
            dto.setHV_ZAN(dto.getHV_ZAN() - dto.getHV_TOTAL());
            // KS_JAVA_START
            try {
                dao.update_01(dto);
            } catch (Exception e) {
                throw rpAbort(conn);
            }
            // KS_JAVA_END

            if (wkClosed) {
                dto.setWK_CLOSED_DATE(LocalDate.now());
                // KS_JAVA_START
                try {
                    dao.update_02(dto);
                } catch (Exception e) {
                    throw rpAbort(conn);
                }
                // KS_JAVA_END
            } else {
                // KS_JAVA_START
                try {
                    dao.update_03(dto);
                } catch (Exception e) {
                    throw rpAbort(conn);
                }
                // KS_JAVA_END
            }

            // COBOL도 이 SEQ_REPAY_ASIS.NEXTVAL SELECT 뒤에는 SQLCODE 체크가 없지만
            // (시퀀스 채번은 실무상 실패하지 않는다는 전제), 위 UPDATE들이 이미 실행된
            // 상태이므로 Java에서 여기서 예외가 나면 반드시 ROLLBACK을 거쳐야 한다.
            // KS_JAVA_START
            try {
                long result = dao.select_04(dto);
                dto.setHV_REPID(result);
            } catch (Exception e) {
                throw rpAbort(conn);
            }
            // KS_JAVA_END

            // KS_JAVA_START
            try {
                dao.insert_01(dto);
            } catch (Exception e) {
                throw rpAbort(conn);
            }
            // KS_JAVA_END

            try {
                conn.commit();
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
            // ===== 트랜잭션 종료 =====
        } finally {
            Db.DB_DISCONNECT(conn);
        }

        return buildJson(dto, wkClosed);
    }

    /**
     * COBOL RP-ABORT(named) — ROLLBACK 후 CgiError. disconnect는 run()의 finally가 담당.
     * 직접 throw하지 않고 CgiError를 반환해서 호출부가 {@code throw rpAbort(conn);}으로
     * 쓰게 한다 — SELECT 직후 지역변수에 대입하는 자리(시퀀스 채번)에서도 catch 블록이
     * 반드시 흐름을 끊는다는 것을 컴파일러의 definite-assignment 분석이 인식하게 하기 위함.
     */
    private static CgiError rpAbort(Connection conn) {
        try {
            conn.rollback();
        } catch (Exception ignore) {
            // best-effort, COBOL EXEC SQL ROLLBACK도 결과를 확인하지 않는다.
        }
        return CgiError.ERR_500("repay_failed");
    }

    private static String buildJson(RepayDto dto, boolean wkClosed) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\"ok\":true,\"loanId\":").append(NumFmt.trim(dto.getHV_LOANID()))
          .append(",\"principal\":").append(NumFmt.trim(dto.getHV_PRIN()))
          .append(",\"interest\":").append(NumFmt.trim(dto.getHV_INT()))
          .append(",\"fee\":550,\"total\":").append(NumFmt.trim(dto.getHV_TOTAL()))
          .append(",\"loanBalance\":").append(NumFmt.trim(dto.getHV_NEWBAL()))
          .append(",\"closed\":").append(wkClosed ? "true" : "false")
          .append('}');
        return sb.toString();
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
}
