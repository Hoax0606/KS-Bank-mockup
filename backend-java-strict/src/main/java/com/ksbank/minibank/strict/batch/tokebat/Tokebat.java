package com.ksbank.minibank.strict.batch.tokebat;

import com.ksbank.minibank.strict.batch.common.BatchProgram;
import com.ksbank.minibank.strict.batch.common.Cobol;
import com.ksbank.minibank.strict.batch.common.LineSequentialWriter;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

/**
 * {@code TOKEBAT.cbl} 1:1 포팅 — KOUZA에서 계좌수/종별내역(보통/당좌)/동결수/총잔고를,
 * TORIHIKI에서 거래 총건수를 집계해 TOKEI.RPT(env {@code TOKE_OUT})에 6줄로 출력한다.
 */
public class Tokebat extends BatchProgram {

    public static void main(String[] a) throws Exception {
        new Tokebat().run();
    }

    private long nAcct = 0, nFutsu = 0, nTouza = 0, nFrozen = 0, tBal = 0;

    @Override
    protected void run() throws Exception {
        String outPath = System.getenv("TOKE_OUT");
        if (outPath == null || outPath.isEmpty()) outPath = "./data/TOKEI.RPT";

        Connection conn = dbConnect("TOKEBAT");
        long hvTx;
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT SHUBETSU, JOUTAI, ZANDAKA FROM KOUZA");
             ResultSet rs = ps.executeQuery();
             LineSequentialWriter out = new LineSequentialWriter(outPath)) {
            while (rs.next()) {
                accum(rs);
            }

            try (PreparedStatement ps2 = conn.prepareStatement("SELECT COUNT(*) FROM TORIHIKI");
                 ResultSet rs2 = ps2.executeQuery()) {
                rs2.next();
                hvTx = rs2.getLong(1);
            }

            out.writeLine("ACCOUNTS  =" + Cobol.pic9(nAcct, 7));
            out.writeLine("FUTSU(1)  =" + Cobol.pic9(nFutsu, 7));
            out.writeLine("TOUZA(2)  =" + Cobol.pic9(nTouza, 7));
            out.writeLine("FROZEN(9) =" + Cobol.pic9(nFrozen, 7));
            out.writeLine("TOTAL BAL =" + Cobol.pic9(tBal, 15));
            out.writeLine("TXN COUNT =" + Cobol.pic9(hvTx, 9));
        }
        dbDisconnect(conn);
        System.err.println("[TOKEBAT] accounts=" + Cobol.pic9(nAcct, 7)
                + " totalBal=" + Cobol.pic9(tBal, 15)
                + " txn=" + Cobol.pic9(hvTx, 9));
    }

    /** COBOL {@code ACCUM} 단락. */
    private void accum(ResultSet rs) throws java.sql.SQLException {
        String shu = rs.getString(1);
        String jou = rs.getString(2);
        long zan = rs.getLong(3);
        boolean zanNull = rs.wasNull(); // IND-ZAN
        nAcct++;
        if ("1".equals(shu)) nFutsu++;
        if ("2".equals(shu)) nTouza++;
        if ("9".equals(jou)) nFrozen++;
        if (!zanNull) tBal += zan;
    }
}
