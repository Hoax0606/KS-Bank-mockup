package com.ksbank.minibank.strict.batch.tesubat;

import com.ksbank.minibank.strict.batch.common.BatchProgram;
import com.ksbank.minibank.strict.batch.common.Cobol;
import com.ksbank.minibank.strict.batch.common.LineSequentialWriter;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

/**
 * {@code TESUBAT.cbl} 1:1 포팅 — TORIHIKI.TESURYO(NULL 아닌 것만)를 집계해 건수/합계를
 * TESURYO.RPT(env {@code TESU_OUT})에 1줄 출력한다. COBOL 원본에 별도 단락이 없어
 * (ACCUM 상당 로직이 MAIN 안에 인라인) 이 포팅도 별도 메서드 없이 run() 안에 그대로 둔다.
 */
public class Tesubat extends BatchProgram {

    public static void main(String[] a) throws Exception {
        new Tesubat().run();
    }

    @Override
    protected void run() throws Exception {
        String outPath = System.getenv("TESU_OUT");
        if (outPath == null || outPath.isEmpty()) outPath = "./data/TESURYO.RPT";

        long tCnt = 0;
        long tSum = 0;

        Connection conn = dbConnect("TESUBAT");
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT TESURYO FROM TORIHIKI WHERE TESURYO IS NOT NULL");
             ResultSet rs = ps.executeQuery();
             LineSequentialWriter out = new LineSequentialWriter(outPath)) {
            while (rs.next()) {
                tCnt++;
                tSum += rs.getLong(1);
            }
            out.writeLine("FEE COUNT=" + Cobol.pic9(tCnt, 7) + " TOTAL=" + Cobol.pic9(tSum, 13));
        }
        dbDisconnect(conn);
        System.err.println("[TESUBAT] fee count=" + Cobol.pic9(tCnt, 7)
                + " total=" + Cobol.pic9(tSum, 13));
    }
}
