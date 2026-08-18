package com.ksbank.minibank.strict.batch.kyumbat;

import com.ksbank.minibank.strict.batch.common.BatchProgram;
import com.ksbank.minibank.strict.batch.common.Cobol;
import com.ksbank.minibank.strict.batch.common.LineSequentialWriter;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

/**
 * {@code KYUMBAT.cbl} 1:1 포팅 — TORIHIKI에 거래가 한 건도 없는 KOUZA를 추출해
 * KYUMIN.RPT(env {@code KYUM_OUT})에 계좌번호를 1줄씩 출력한다. COBOL 원본에 별도
 * 단락이 없어(전부 MAIN 인라인) 이 포팅도 별도 메서드 없이 run() 안에 그대로 둔다.
 */
public class Kyumbat extends BatchProgram {

    public static void main(String[] a) throws Exception {
        new Kyumbat().run();
    }

    @Override
    protected void run() throws Exception {
        String outPath = System.getenv("KYUM_OUT");
        if (outPath == null || outPath.isEmpty()) outPath = "./data/KYUMIN.RPT";

        long nOut = 0;

        Connection conn = dbConnect("KYUMBAT");
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT K.KOUZA_NO FROM KOUZA K WHERE NOT EXISTS "
                        + "(SELECT 1 FROM TORIHIKI T WHERE T.KOUZA_NO = K.KOUZA_NO) "
                        + "ORDER BY K.KOUZA_NO");
             ResultSet rs = ps.executeQuery();
             LineSequentialWriter out = new LineSequentialWriter(outPath)) {
            // COBOL: PERFORM UNTIL SQLCODE NOT = 0 는 EOF와 진짜 SQL 에러를 구분하지 않는다.
            // 스캔 도중 진짜 DB 에러가 나도 루프가 그냥 끝나고, 그때까지 쓴 레코드로
            // 정상 종료한다. 동일하게 재현: SQLException을 조용히 삼켜 루프만 빠져나온다.
            try {
                while (rs.next()) {
                    long kz = rs.getLong(1);
                    out.writeLine("DORMANT= " + Cobol.pic9(kz, 7));
                    nOut++;
                }
            } catch (SQLException ignored) {
                // 의도적으로 무시 — COBOL의 SQLCODE 관용구는 EOF와 에러를 구분하지 않는다.
            }
        }
        dbDisconnect(conn);
        System.err.println("[KYUMBAT] dormant accounts=" + Cobol.pic9(nOut, 6));
    }
}
