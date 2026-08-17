package com.ksbank.minibank.strict.batch.mastbat;

import com.ksbank.minibank.strict.batch.common.BatchProgram;
import com.ksbank.minibank.strict.batch.common.Cobol;
import com.ksbank.minibank.strict.batch.common.LineSequentialWriter;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

/**
 * {@code MASTBAT.cbl} 1:1 포팅 — KOUZA를 KOUZA_NO순으로 읽어 계좌번호/종별/상태/개설일/
 * 잔고를 KOUZA.LST(env {@code MAST_OUT})에 1줄씩 출력한다(총합 없음, 감사/조합용).
 */
public class Mastbat extends BatchProgram {

    public static void main(String[] a) throws Exception {
        new Mastbat().run();
    }

    private long nOut = 0;
    private LineSequentialWriter out;

    @Override
    protected void run() throws Exception {
        String outPath = System.getenv("MAST_OUT");
        if (outPath == null || outPath.isEmpty()) outPath = "./data/KOUZA.LST";

        Connection conn = dbConnect("MASTBAT");
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT KOUZA_NO, SHUBETSU, JOUTAI, KAISETSU_BI, ZANDAKA FROM KOUZA ORDER BY KOUZA_NO");
             ResultSet rs = ps.executeQuery();
             LineSequentialWriter w = new LineSequentialWriter(outPath)) {
            this.out = w;
            while (rs.next()) {
                emit(rs);
            }
        }
        dbDisconnect(conn);
        System.err.println("[MASTBAT] listed " + Cobol.pic9(nOut, 6) + " accounts");
    }

    /** COBOL {@code EMIT} 단락. */
    private void emit(ResultSet rs) throws SQLException, java.io.IOException {
        long kz = rs.getLong(1);
        String shu = rs.getString(2);
        String jou = rs.getString(3);
        String kai = rs.getString(4);
        long zan = rs.getLong(5);
        boolean zanNull = rs.wasNull(); // IND-ZAN
        long bal = zanNull ? 0 : zan;
        out.writeLine("ACCT=" + Cobol.pic9(kz, 7)
                + " TYP=" + shu
                + " ST=" + jou
                + " OPEN=" + Cobol.picX(kai, 8)
                + " BAL=" + Cobol.pic9(bal, 11));
        nOut++;
    }
}
