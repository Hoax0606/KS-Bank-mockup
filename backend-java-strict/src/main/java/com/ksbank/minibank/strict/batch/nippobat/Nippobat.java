package com.ksbank.minibank.strict.batch.nippobat;

import com.ksbank.minibank.strict.batch.common.BatchProgram;
import com.ksbank.minibank.strict.batch.common.Cobol;
import com.ksbank.minibank.strict.batch.common.LineSequentialWriter;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

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
            while (rs.next()) {
                accum(rs.getString(1), rs.getLong(2));
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
