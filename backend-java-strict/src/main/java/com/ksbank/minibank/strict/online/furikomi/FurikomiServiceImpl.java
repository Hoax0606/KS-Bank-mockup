package com.ksbank.minibank.strict.online.furikomi;

import java.sql.Connection;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.springframework.stereotype.Service;
import com.ksbank.minibank.strict.online.cgi.CgiParam;
import com.ksbank.minibank.strict.online.cgi.CgiRequest;
import com.ksbank.minibank.strict.online.dao.FurikomiDao;
import com.ksbank.minibank.strict.online.db.Db;
import com.ksbank.minibank.strict.online.dto.FurikomiDto;
import com.ksbank.minibank.strict.online.err.CgiError;
import com.ksbank.minibank.strict.online.util.NumFmt;

/**
 * COBOL FURIKOMI.cbl 1:1 포팅. ★원자적★
 * 출금측 -(금액+수수료110) + (수취계좌 자행 존재 시) 입금측 +금액을 한 트랜잭션으로 처리.
 * 실패 시 named 메서드 {@link #txnAbort}로 여러 지점에서 재사용(ROLLBACK 후 CgiError).
 */
@Service
public class FurikomiServiceImpl implements FurikomiService {

    private static final DateTimeFormatter DT14 = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");

    private final SqlSessionFactory sqlSessionFactory;

    public FurikomiServiceImpl(SqlSessionFactory sqlSessionFactory) {
        this.sqlSessionFactory = sqlSessionFactory;
    }

    @Override
    public String MAIN(CgiRequest cgi) {
        FurikomiDto dto = new FurikomiDto();

        CgiParam kouzaParam = cgi.param("kouza");
        if (!kouzaParam.found()) {
            throw CgiError.ERR_400("missing_kouza");
        }
        dto.setHV_KOUZA(pic9(numval(kouzaParam.value()), 7));

        CgiParam aiteParam = cgi.param("aite");
        if (!aiteParam.found()) {
            throw CgiError.ERR_400("missing_aite");
        }
        dto.setHV_AITE(pic9(numval(aiteParam.value()), 7));

        dto.setHV_AMT(numval(cgi.param("kingaku").value()));
        if (dto.getHV_AMT() <= 0) {
            throw CgiError.ERR_400("invalid_amount");
        }
        dto.setHV_FEE(110);
        dto.setHV_TOTAL(dto.getHV_AMT() + dto.getHV_FEE());

        String receipt;
        Connection conn = Db.DB_CONNECT();
        try (SqlSession session = sqlSessionFactory.openSession(conn)) {
            FurikomiDao dao = session.getMapper(FurikomiDao.class);

            boolean wkFound = false;
            // KS_JAVA_START
            try {
                FurikomiDto result = dao.select_01(dto);
                if (result != null) {
                    dto.setHV_ZAN(result.getHV_ZAN());
                    dto.setHV_JOU(result.getHV_JOU());
                    wkFound = true;
                }
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
            // KS_JAVA_END
            if (!wkFound) {
                throw CgiError.ERR_404("kouza_not_found");
            }
            if ("9".equals(dto.getHV_JOU())) {
                throw CgiError.ERR_409("account_frozen");
            }
            if (dto.getHV_ZAN() < dto.getHV_TOTAL()) {
                throw CgiError.ERR_409("insufficient_funds");
            }

            int wkAiteCnt;
            // KS_JAVA_START
            try {
                long result = dao.select_02(dto);
                dto.setHV_CNT(result);
                wkAiteCnt = (int) dto.getHV_CNT();
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
            // KS_JAVA_END

            // KS_JAVA_START
            try {
                FurikomiDto result = dao.select_03(dto);
                dto.setHV_TID(result.getHV_TID());
                dto.setHV_RSEQ(result.getHV_RSEQ());
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
            // KS_JAVA_END

            dto.setHV_DT(LocalDateTime.now().format(DT14));

            // ===== 원자적 트랜잭션 시작 =====
            dto.setHV_ZAN(dto.getHV_ZAN() - dto.getHV_TOTAL());
            // KS_JAVA_START
            try {
                dao.update_01(dto);
            } catch (Exception e) {
                throw txnAbort(conn);
            }
            // KS_JAVA_END

            // KS_JAVA_START
            try {
                dao.insert_01(dto);
            } catch (Exception e) {
                throw txnAbort(conn);
            }
            // KS_JAVA_END

            if (wkAiteCnt > 0) {
                // COBOL은 이 SELECT 뒤에 SQLCODE 체크를 두지 않지만(WK-AITE-CNT>0으로
                // 이미 존재가 확인된 계좌라 실패 가능성이 없다고 가정), Java에서 여기서
                // 예외가 나면 위 UPDATE/INSERT가 이미 실행된 상태이므로 반드시 ROLLBACK을
                // 거쳐야 한다 — 원자적 블록 안의 "모든" 호출을 abort 경로로 통일하기 위해
                // COBOL에 없는 체크를 추가한다.
                // KS_JAVA_START
                try {
                    long result = dao.select_04(dto);
                    dto.setHV_AZAN(result);
                } catch (Exception e) {
                    throw txnAbort(conn);
                }
                // KS_JAVA_END
                dto.setHV_AZAN(dto.getHV_AZAN() + dto.getHV_AMT());
                // KS_JAVA_START
                try {
                    dao.update_02(dto);
                } catch (Exception e) {
                    throw txnAbort(conn);
                }
                // KS_JAVA_END

                // COBOL도 이 SEQ_TORIHIKI.NEXTVAL SELECT 뒤에는 체크가 없지만(시퀀스
                // 채번은 실무상 실패하지 않는다는 전제), 위와 동일한 이유로 Java에서는
                // 반드시 abort 경로를 거치게 한다.
                // KS_JAVA_START
                try {
                    long result = dao.select_05(dto);
                    dto.setHV_TID2(result);
                } catch (Exception e) {
                    throw txnAbort(conn);
                }
                // KS_JAVA_END

                // KS_JAVA_START
                try {
                    dao.insert_02(dto);
                } catch (Exception e) {
                    throw txnAbort(conn);
                }
                // KS_JAVA_END
            }

            try {
                conn.commit();
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
            // ===== 원자적 트랜잭션 종료 =====
            // HV-ZAN 은 이미 이체 후 잔액(위에서 차감 완료)

            receipt = makeReceipt(dto.getHV_DT(), dto.getHV_RSEQ());
        } finally {
            Db.DB_DISCONNECT(conn);
        }

        return buildJson(dto, receipt);
    }

    /**
     * COBOL TXN-ABORT(named, 여러 지점에서 재사용) — ROLLBACK 후 CgiError.
     * disconnect는 run()의 finally가 담당. 여기서 직접 throw하지 않고 CgiError를
     * "반환"해서 호출부가 {@code throw txnAbort(conn);} 형태로 쓰게 한다 — SELECT 직후
     * 지역변수에 대입하는 자리(예: 상대계좌 잔액 재조회)에서도 catch 블록이 반드시
     * 흐름을 끊는다는 것을 자바 컴파일러의 definite-assignment 분석이 인식하게 하기 위함.
     */
    private static CgiError txnAbort(Connection conn) {
        try {
            conn.rollback();
        } catch (Exception ignore) {
            // best-effort, COBOL EXEC SQL ROLLBACK도 결과를 확인하지 않는다.
        }
        return CgiError.ERR_500("transfer_failed");
    }

    private static String makeReceipt(String hvDt, long hvRseq) {
        long mod = hvRseq % 10000;
        return "WEB" + hvDt.substring(0, 8) + "-" + String.format("%04d", mod);
    }

    private static String buildJson(FurikomiDto dto, String receipt) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\"ok\":true,\"kouza\":\"").append(zpad7(dto.getHV_KOUZA()))
          .append("\",\"aite\":\"").append(zpad7(dto.getHV_AITE()))
          .append("\",\"receipt\":\"").append(receipt)
          .append("\",\"dt\":\"").append(dto.getHV_DT())
          .append("\",\"fee\":110,\"afterBal\":").append(NumFmt.trim(dto.getHV_ZAN()))
          .append("}");
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

    static String zpad7(long v) {
        return String.format("%07d", v);
    }
}
