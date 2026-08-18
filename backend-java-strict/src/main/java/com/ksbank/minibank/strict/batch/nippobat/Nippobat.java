package com.ksbank.minibank.strict.batch.nippobat;

import com.ksbank.minibank.strict.batch.common.BatchProgram;
import com.ksbank.minibank.strict.batch.common.Cobol;
import com.ksbank.minibank.strict.batch.common.LineSequentialWriter;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

/**
 * {@code NIPPOBAT.cbl} 1:1 포팅 — TORIHIKI 전건(정렬 없음)을 읽어 TORIHIKI_KBN(1/2/3)별
 * 건수/금액합계를 집계해 NIPPO.RPT(env {@code NIPPO_OUT})에 3줄로 출력한다.
 */
public class Nippobat extends BatchProgram {

    public static void main(String[] a) throws Exception {
        new Nippobat().run();
    }

    private long c1 = 0, c2 = 0, c3 = 0;
    private long s1 = 0, s2 = 0, s3 = 0;

    @Override
    protected void run() throws Exception {
        String outPath = System.getenv("NIPPO_OUT");
        if (outPath == null || outPath.isEmpty()) outPath = "./data/NIPPO.RPT";

        Connection conn = dbConnect("NIPPOBAT");
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT TORIHIKI_KBN, KINGAKU FROM TORIHIKI");
             ResultSet rs = ps.executeQuery();
             LineSequentialWriter out = new LineSequentialWriter(outPath)) {
            // COBOL: PERFORM UNTIL SQLCODE NOT = 0 는 정상 EOF(SQLCODE=100)와 진짜 SQL
            // 에러를 구분하지 않는다 — 둘 다 루프 종료로 취급되고, 그때까지 집계한 값으로
            // 그대로 리포트를 마무리한다. rs.next()가 진짜 에러로 SQLException을 던져도
            // 동일하게 "루프만 조용히 종료"로 재현한다(로그 없음, 이후 로직은 정상 진행).
            try {
                while (rs.next()) {
                    accum(rs.getString(1), rs.getLong(2));
                }
            } catch (SQLException ignored) {
                // 의도적으로 무시 — COBOL의 SQLCODE 관용구는 EOF와 에러를 구분하지 않는다.
            }
            out.writeLine("KBN=1" + " CNT= " + Cobol.pic9(c1, 7) + " SUM= " + Cobol.pic9(s1, 15));
            out.writeLine("KBN=2" + " CNT= " + Cobol.pic9(c2, 7) + " SUM= " + Cobol.pic9(s2, 15));
            out.writeLine("KBN=3" + " CNT= " + Cobol.pic9(c3, 7) + " SUM= " + Cobol.pic9(s3, 15));
        }
        dbDisconnect(conn);
        System.err.println("[NIPPOBAT] done nyukin=" + Cobol.pic9(c1, 7)
                + " shukkin=" + Cobol.pic9(c2, 7)
                + " furikomi=" + Cobol.pic9(c3, 7));
    }

    /** COBOL {@code ACCUM} 단락. */
    private void accum(String kbn, long kin) {
        switch (kbn) {
            case "1" -> { c1++; s1 += kin; }
            case "2" -> { c2++; s2 += kin; }
            case "3" -> { c3++; s3 += kin; }
            default -> { }
        }
    }
}
