package com.ksbank.minibank.strict.batch.zandabat;

import com.ksbank.minibank.strict.batch.common.BatchProgram;
import com.ksbank.minibank.strict.batch.common.Cobol;
import com.ksbank.minibank.strict.batch.common.LineSequentialWriter;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

/**
 * {@code ZANDABAT.cbl} 1:1 포팅 — KOUZA를 KOUZA_NO순으로 읽어 계좌번호/종별/상태/잔고를
 * ZANDAKA.RPT(env {@code ZANDA_OUT})에 1줄씩, 마지막에 TOTAL줄을 출력한다.
 */
public class Zandabat extends BatchProgram {

    public static void main(String[] a) throws Exception {
        new Zandabat().run();
    }

    private long nOut = 0;
    private long tBal = 0;
    private LineSequentialWriter out;

    @Override
    protected void run() throws Exception {
        String outPath = System.getenv("ZANDA_OUT");
        if (outPath == null || outPath.isEmpty()) outPath = "./data/ZANDAKA.RPT";

        Connection conn = dbConnect("ZANDABAT");
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT KOUZA_NO, SHUBETSU, JOUTAI, ZANDAKA FROM KOUZA ORDER BY KOUZA_NO");
             ResultSet rs = ps.executeQuery();
             LineSequentialWriter w = new LineSequentialWriter(outPath)) {
            this.out = w;
            while (rs.next()) {
                emit(rs);
            }
            out.writeLine("TOTAL  " + "BAL=" + Cobol.pic9(tBal, 15));
        }
        dbDisconnect(conn);
        System.err.println("[ZANDABAT] listed " + Cobol.pic9(nOut, 6)
                + " accounts, totalBal=" + Cobol.pic9(tBal, 15));
    }

    /** COBOL {@code EMIT} 단락. */
    private void emit(ResultSet rs) throws SQLException, java.io.IOException {
        long kz = rs.getLong(1);
        String shu = rs.getString(2);
        String jou = rs.getString(3);
        long zan = rs.getLong(4);
        boolean zanNull = rs.wasNull(); // IND-ZAN
        long bal = zanNull ? 0 : zan;
        out.writeLine(Cobol.pic9(kz, 7) + " " + shu + " " + jou + " " + Cobol.pic9(bal, 11));
        if (!zanNull) tBal += zan;
        nOut++;
    }
}
