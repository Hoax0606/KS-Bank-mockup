package com.ksbank.minibank.strict.batch.sortrpt;

import com.ksbank.minibank.strict.batch.common.FixedWidthReader;
import com.ksbank.minibank.strict.batch.common.FixedWidthWriter;

import java.util.ArrayList;
import java.util.List;

/**
 * {@code SORTRPT.cbl} 1:1 포팅 — REPORT.WORK(하드코딩 리터럴, 164byte = kana60+seq6+body98)를
 * 名義カナ(Shift-JIS 바이트순) + 투입순(seq)으로 정렬한 뒤, 66byte 정렬키 프리픽스를 제거하고
 * 98byte 明細 본문만 MEISAI.RPT(env {@code RPT_OUT})에 쓴다. DB 접속 없음(COBOL도 EXEC SQL 없음).
 */
public class Sortrpt {

    private static final int RPTW_LEN = 164;
    private static final int RPT_LEN = 98;
    private static final int KANA_OFF = 0, KANA_LEN = 60;
    private static final int SEQ_OFF = 60, SEQ_LEN = 6;
    private static final int BODY_OFF = 66, BODY_LEN = 98;

    public static void main(String[] a) throws Exception {
        new Sortrpt().run();
    }

    void run() throws Exception {
        String rptPath = System.getenv("RPT_OUT");
        if (rptPath == null || rptPath.isEmpty()) rptPath = "./data/MEISAI.RPT";

        List<byte[]> recs = new ArrayList<>();
        try (FixedWidthReader in = new FixedWidthReader("REPORT.WORK", RPTW_LEN)) {
            byte[] rec;
            while ((rec = in.read()) != null) recs.add(rec);
        }

        // SORT SW2 ON ASCENDING KEY SW2-KANA SW2-SEQ
        recs.sort(Sortrpt::compareKey);

        try (FixedWidthWriter out = new FixedWidthWriter(rptPath, RPT_LEN)) {
            for (byte[] rec : recs) {
                byte[] body = new byte[BODY_LEN];
                System.arraycopy(rec, BODY_OFF, body, 0, BODY_LEN);
                out.write(body);
            }
        }
    }

    private static int compareKey(byte[] a, byte[] b) {
        int c = compareRange(a, b, KANA_OFF, KANA_LEN); // SW2-KANA(제1키)
        if (c != 0) return c;
        return compareRange(a, b, SEQ_OFF, SEQ_LEN); // SW2-SEQ(제2키, 안정화)
    }

    private static int compareRange(byte[] a, byte[] b, int off, int len) {
        for (int i = 0; i < len; i++) {
            int x = a[off + i] & 0xFF;
            int y = b[off + i] & 0xFF;
            if (x != y) return Integer.compare(x, y);
        }
        return 0;
    }
}
