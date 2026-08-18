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
            // COBOL: PERFORM UNTIL SQLCODE NOT = 0 는 EOF와 진짜 SQL 에러를 구분하지 않는다.
            // 스캔 도중 진짜 DB 에러가 나도 루프가 그냥 끝나고, 그때까지 쓴 레코드로
            // 정상 종료한다. 동일하게 재현: SQLException을 조용히 삼켜 루프만 빠져나온다.
            try {
                while (rs.next()) {
                    emit(rs);
                }
            } catch (SQLException ignored) {
                // 의도적으로 무시 — COBOL의 SQLCODE 관용구는 EOF와 에러를 구분하지 않는다.
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
        // MASTBAT.cbl: MOVE HV-SHU TO L-SHU / MOVE HV-JOU TO L-JOU — 둘 다 PIC X(1) 필드로의
        // MOVE다(HV-KAI를 L-DATE PIC X(8)로 옮길 때 Cobol.picX(kai, 8)를 쓰는 것과 동일 원리).
        // JDBC ResultSet 값을 그대로 문자열 결합에 쓰면 COBOL의 space-pad/우측절단 MOVE 시맨틱을
        // 우회하게 되므로, 다른 X(n) 필드들과 일관되게 picX 헬퍼를 거치도록 한다.
        out.writeLine("ACCT=" + Cobol.pic9(kz, 7)
                + " TYP=" + Cobol.picX(shu, 1)
                + " ST=" + Cobol.picX(jou, 1)
                + " OPEN=" + Cobol.picX(kai, 8)
                + " BAL=" + Cobol.pic9(bal, 11));
        nOut++;
    }
}
