package com.ksbank.minibank.strict.batch.mkdat;

import com.ksbank.minibank.strict.batch.common.BatchProgram;
import com.ksbank.minibank.strict.batch.common.Cobol;
import com.ksbank.minibank.strict.batch.common.FixedWidthWriter;
import com.ksbank.minibank.strict.batch.common.Wtrdat;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.Arrays;

/**
 * {@code MKDAT.cbl} 1:1 포팅 — TORIHIKI 전건을 (KOUZA_NO,TORIHIKI_ID)순으로 추출해
 * 97byte 고정 TORIHIKI.DAT(env {@code DAT_IN})를 만든다. YAKANBAT 의 입력 시작점.
 */
public class Mkdat extends BatchProgram {

    public static void main(String[] a) throws Exception {
        new Mkdat().run();
    }

    private long nOut = 0;

    @Override
    protected void run() throws Exception {
        String outPath = System.getenv("DAT_IN");
        if (outPath == null || outPath.isEmpty()) outPath = "./data/TORIHIKI.DAT";

        Connection conn = dbConnect("MKDAT");
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT TORIHIKI_ID, KOUZA_NO, TORIHIKI_DT, TORIHIKI_KBN, KINGAKU, "
                        + "AITE_KOUZA, TESURYO, TEKIYOU FROM TORIHIKI ORDER BY KOUZA_NO, TORIHIKI_ID");
             ResultSet rs = ps.executeQuery();
             FixedWidthWriter out = new FixedWidthWriter(outPath, Wtrdat.RECORD_LEN)) {
            while (rs.next()) {
                out.write(buildRec(rs));
                nOut++;
            }
        }
        dbDisconnect(conn);
        System.err.println("[MKDAT] extracted " + Cobol.pic9(nOut, 6) + " recs from TORIHIKI");
    }

    /** COBOL {@code BUILD-REC} 단락 상당. */
    private byte[] buildRec(ResultSet rs) throws java.sql.SQLException {
        byte[] rec = new byte[Wtrdat.RECORD_LEN];
        // INITIALIZE TR-DAT-REC: PIC 9 -> 0, PIC X -> spaces, COMP-3 -> 0
        Arrays.fill(rec, (byte) ' ');
        Cobol.putPic9(rec, Wtrdat.ID_OFF, Wtrdat.ID_LEN, 0);
        Cobol.putPic9(rec, Wtrdat.KOUZA_OFF, Wtrdat.KOUZA_LEN, 0);
        Cobol.putComp3(rec, Wtrdat.KINGAKU_OFF, Wtrdat.KINGAKU_DIGITS, 0);

        long id = rs.getLong("TORIHIKI_ID");
        long kouza = rs.getLong("KOUZA_NO");
        String nichiji = rs.getString("TORIHIKI_DT");
        String kbn = rs.getString("TORIHIKI_KBN");
        long kingaku = rs.getLong("KINGAKU");

        Cobol.putPic9(rec, Wtrdat.ID_OFF, Wtrdat.ID_LEN, id);
        Cobol.putPic9(rec, Wtrdat.KOUZA_OFF, Wtrdat.KOUZA_LEN, kouza);
        Cobol.putPicX(rec, Wtrdat.NICHIJI_OFF, Wtrdat.NICHIJI_LEN, nichiji);
        Cobol.putPicX(rec, Wtrdat.KBN_OFF, Wtrdat.KBN_LEN, kbn);
        Cobol.putComp3(rec, Wtrdat.KINGAKU_OFF, Wtrdat.KINGAKU_DIGITS, kingaku);

        // MOVE SPACES TO TD-EXT
        for (int i = 0; i < Wtrdat.EXT_LEN; i++) rec[Wtrdat.EXT_OFF + i] = ' ';

        // ★ MKDAT은 (YAKANBAT과 달리) TORIHIKI_KBN 값으로 분기하지 않고 JDBC null
        //   indicator(IND-AITE/IND-TES/IND-TEK 상당, rs.wasNull())로만 분기한다 —
        //   원본 COBOL 구조를 그대로 재현(둘의 결과가 같은 건 DB 제약상 우연일 뿐).
        long aite = rs.getLong("AITE_KOUZA");
        boolean aiteNull = rs.wasNull();
        if (!aiteNull) {
            Cobol.putPic9(rec, Wtrdat.AITE_OFF, Wtrdat.AITE_LEN, aite);
        }

        long tesuryo = rs.getLong("TESURYO");
        boolean tesNull = rs.wasNull();
        if (!tesNull) {
            Cobol.putComp3(rec, Wtrdat.TESURYO_OFF, Wtrdat.TESURYO_DIGITS, tesuryo);
        }

        String tekiyou = rs.getString("TEKIYOU");
        boolean tekNull = rs.wasNull();
        if (!tekNull) {
            Cobol.putSjis(rec, Wtrdat.TEKIYOU_OFF, Wtrdat.TEKIYOU_LEN, tekiyou);
        }
        return rec;
    }
}
