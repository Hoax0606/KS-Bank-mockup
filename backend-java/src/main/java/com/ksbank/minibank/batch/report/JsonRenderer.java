package com.ksbank.minibank.batch.report;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import com.ksbank.minibank.batch.BatchResult;
import com.ksbank.minibank.domain.MeisaiRec;

/**
 * {@link BatchResult} → {@code POST /api/batch/run} 응답 JSON.
 *
 * <p><b>기존 계약은 추가만 한다.</b> 기존 키({@code ok/posting/nippo/zandaka/tesuryo/kyumin/
 * master/tokei})와 {@code posting.accountsPosted}/{@code interestTotal} 의 의미는 불변이다.
 * 추가분: {@code posting.accountsUpdated}, {@code posting.meisaiCount}, 최상위 {@code meisai[]},
 * 그리고 {@code zandaka.rows[]} 의 {@code shubetsu}/{@code joutai}.
 */
public final class JsonRenderer {

    private JsonRenderer() {}

    public static Map<String, Object> render(BatchResult r) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("ok", true);
        out.put("posting", posting(r));
        out.put("meisai", meisai(r.meisai()));
        out.put("nippo", nippo(r));
        out.put("zandaka", zandaka(r));
        out.put("tesuryo", Map.of("count", r.tesuryo().count(), "total", r.tesuryo().total()));
        out.put("kyumin", r.kyumin());
        out.put("master", master(r));
        out.put("tokei", tokei(r));
        return out;
    }

    private static Map<String, Object> posting(BatchResult r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("accountsPosted", r.accountsPosted());
        m.put("interestTotal", r.interestTotal());
        m.put("accountsUpdated", r.accountsUpdated());
        m.put("meisaiCount", r.meisai().size());
        return m;
    }

    /** カナ순 flat 배열. 이 배열이 곧 MEISAI 帳票이다. */
    private static List<Map<String, Object>> meisai(List<MeisaiRec> recs) {
        List<Map<String, Object>> rows = new ArrayList<>(recs.size());
        for (MeisaiRec rec : recs) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("kubun", rec.kubun());
            m.put("kouza", rec.kouzaNo());
            if (rec instanceof MeisaiRec.D d) {
                m.put("dt", d.torihikiDt());
                m.put("kbn", d.kbn());
                m.put("kingaku", d.kingaku());
                m.put("zandakaGo", d.zandakaGo());
                m.put("meigi", d.meigiKanji());
            } else if (rec instanceof MeisaiRec.T t) {
                m.put("risoku", t.risoku());
                m.put("tesuryoGoukei", t.tesuryoGoukei());
                m.put("kakuteiZan", t.kakuteiZan());
            }
            rows.add(m);
        }
        return rows;
    }

    private static Map<String, Object> nippo(BatchResult r) {
        Map<String, Object> m = new LinkedHashMap<>();
        for (int k = 1; k <= 3; k++) {
            m.put("kbn" + k, Map.of("count", r.nippo().count()[k], "sum", r.nippo().sum()[k]));
        }
        return m;
    }

    private static Map<String, Object> zandaka(BatchResult r) {
        List<Map<String, Object>> rows = new ArrayList<>();
        for (BatchResult.ZandakaRow z : r.zandaka().rows()) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("kouza", (long) z.kouzaNo());
            m.put("shubetsu", z.shubetsu());
            m.put("joutai", z.joutai());
            m.put("zandaka", z.zandaka());
            rows.add(m);
        }
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("count", rows.size());
        m.put("totalBalance", r.zandaka().total());
        m.put("rows", rows);
        return m;
    }

    private static List<Map<String, Object>> master(BatchResult r) {
        List<Map<String, Object>> rows = new ArrayList<>();
        for (BatchResult.MasterRow a : r.master()) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("kouza", (long) a.kouzaNo());
            m.put("shubetsu", a.shubetsu());
            m.put("joutai", a.joutai());
            m.put("kaisetsu", a.kaisetsu());
            m.put("zandaka", a.zandaka());
            rows.add(m);
        }
        return rows;
    }

    private static Map<String, Object> tokei(BatchResult r) {
        BatchResult.Tokei t = r.tokei();
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("accounts", t.accounts());
        m.put("futsu", t.futsu());
        m.put("touza", t.touza());
        m.put("frozen", t.frozen());
        m.put("totalBalance", t.totalBalance());
        m.put("txnCount", t.txnCount());
        return m;
    }
}
