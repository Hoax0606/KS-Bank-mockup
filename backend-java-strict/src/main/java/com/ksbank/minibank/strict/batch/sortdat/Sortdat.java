package com.ksbank.minibank.strict.batch.sortdat;

import com.ksbank.minibank.strict.batch.common.FixedWidthReader;
import com.ksbank.minibank.strict.batch.common.FixedWidthWriter;
import com.ksbank.minibank.strict.batch.common.Wtrdat;

import java.util.ArrayList;
import java.util.List;

/**
 * {@code SORTDAT.cbl} 1:1 포팅 — TORIHIKI.DAT(env {@code DAT_IN})를 읽어
 * (KOUZA_NO,TORIHIKI_ID) 순으로 정렬해 저장한다. DB 접속 없음(COBOL도 EXEC SQL 없음
 * — gixpp가 SD를 해석 못해 SORT 전용 서브프로그램으로 분리된 원본 구조 그대로).
 *
 * <p>출력 파일명은 COBOL 원본처럼 <b>하드코딩 리터럴</b>이다(env 아님) —
 * {@code SELECT F-OUT ASSIGN TO "TORIHIKI.SORTED"}.
 *
 * <p>SW1-REC(정렬키)은 DAT-REC(97byte)를 그대로 재해석한 것: 앞 12byte가
 * 제2키(TD-ID 위치), 다음 10byte가 제1키(TD-KOUZA-NO 위치)다.
 */
public class Sortdat {

    public static void main(String[] a) throws Exception {
        new Sortdat().run();
    }

    void run() throws Exception {
        String datPath = System.getenv("DAT_IN");
        if (datPath == null || datPath.isEmpty()) datPath = "./data/TORIHIKI.DAT";

        List<byte[]> recs = new ArrayList<>();
        try (FixedWidthReader in = new FixedWidthReader(datPath, Wtrdat.RECORD_LEN)) {
            byte[] rec;
            while ((rec = in.read()) != null) {
                recs.add(rec);
            }
        }

        // SORT SW1 ON ASCENDING KEY SW1-KOUZA SW1-ID
        recs.sort(Sortdat::compareKey);

        try (FixedWidthWriter out = new FixedWidthWriter("TORIHIKI.SORTED", Wtrdat.RECORD_LEN)) {
            for (byte[] rec : recs) out.write(rec);
        }
    }

    private static int compareKey(byte[] a, byte[] b) {
        int c = compareRange(a, b, Wtrdat.KOUZA_OFF, Wtrdat.KOUZA_LEN); // SW1-KOUZA(제1키)
        if (c != 0) return c;
        return compareRange(a, b, Wtrdat.ID_OFF, Wtrdat.ID_LEN); // SW1-ID(제2키)
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
