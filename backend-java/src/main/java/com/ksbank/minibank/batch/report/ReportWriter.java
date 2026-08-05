package com.ksbank.minibank.batch.report;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import com.ksbank.minibank.batch.BatchResult;
import com.ksbank.minibank.domain.MeisaiRec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * 배치 帳票 7종을 파일로 출력. COBOL {@code run_batch.sh} 의 {@code ./data/*} 산출물 대응.
 *
 * <p>6종({@code NIPPO/ZANDAKA/TESURYO/KYUMIN/KOUZA.LST/TOKEI})은 <b>COBOL 서식을 그대로</b>
 * 재현한다 — 자릿수·제로패딩·필러 공백까지. 그래서 파일 대 파일 {@code diff} 가 성립한다.
 *
 * <p>明細만 {@code MEISAI.TXT}(텍스트)로 쓴다. COBOL 은 {@code MEISAI.RPT}(98byte 고정 + COMP-3)
 * 바이너리이므로 <b>이름을 일부러 다르게</b> 해 "같은 이름 다른 포맷" 혼동을 피한다.
 * 대조 시에는 {@code tools/parity/meisai_dump.py} 가 COBOL 쪽을 이 텍스트 포맷으로 변환한다.
 *
 * <p>개행은 LF, 인코딩은 UTF-8 — GnuCOBOL {@code LINE SEQUENTIAL} on Linux 와 동일.
 */
@Component
public class ReportWriter {

    private final Path outDir;

    public ReportWriter(@Value("${app.batch.output-dir:./data}") String outputDir) {
        this.outDir = Path.of(outputDir);
    }

    /** 7개 파일을 쓰고, 쓴 경로 목록을 돌려준다. */
    public List<String> write(BatchResult r) {
        try {
            Files.createDirectories(outDir);
            List<String> written = new ArrayList<>();
            written.add(put("MEISAI.TXT", meisai(r)));
            written.add(put("NIPPO.RPT", nippo(r)));
            written.add(put("ZANDAKA.RPT", zandaka(r)));
            written.add(put("TESURYO.RPT", tesuryo(r)));
            written.add(put("KYUMIN.RPT", kyumin(r)));
            written.add(put("KOUZA.LST", kouzaList(r)));
            written.add(put("TOKEI.RPT", tokei(r)));
            return written;
        } catch (IOException e) {
            throw new UncheckedIOException("batch report write failed: " + outDir, e);
        }
    }

    private String put(String name, List<String> lines) throws IOException {
        Path p = outDir.resolve(name);
        StringBuilder sb = new StringBuilder();
        for (String l : lines) sb.append(l).append('\n');
        Files.writeString(p, sb.toString(), StandardCharsets.UTF_8);
        return p.toString();
    }

    // ---------------------------------------------------------------- 明細
    //  D kouza=1000123 dt=20260801090000 kbn=1 kingaku=30000 zandakaGo=545510 meigi=山田太郎
    //  T kouza=1000123 risoku=1 tesuryoGoukei=110 kakuteiZan=523401
    private static List<String> meisai(BatchResult r) {
        List<String> out = new ArrayList<>();
        for (MeisaiRec rec : r.meisai()) {
            if (rec instanceof MeisaiRec.D d) {
                out.add("D kouza=" + d.kouzaNo()
                        + " dt=" + d.torihikiDt()
                        + " kbn=" + d.kbn()
                        + " kingaku=" + d.kingaku()
                        + " zandakaGo=" + d.zandakaGo()
                        + " meigi=" + trunc60(d.meigiKanji()));
            } else if (rec instanceof MeisaiRec.T t) {
                out.add("T kouza=" + t.kouzaNo()
                        + " risoku=" + t.risoku()
                        + " tesuryoGoukei=" + t.tesuryoGoukei()
                        + " kakuteiZan=" + t.kakuteiZan());
            }
        }
        return out;
    }

    // ------------------------------------------------------------- 5 NIPPO
    //  NIPPOBAT L-DTL: X(4)"KBN=" X(1) X(6)" CNT=" 9(7) X(6)" SUM=" 9(15)
    //  ★ " CNT=" 는 5글자 VALUE 가 X(6) 에 들어가 뒤에 공백 1개가 더 붙는다(" SUM=" 도 동일)
    private static List<String> nippo(BatchResult r) {
        List<String> out = new ArrayList<>();
        for (int k = 1; k <= 3; k++) {
            out.add("KBN=" + k
                    + " CNT= " + z(r.nippo().count()[k], 7)
                    + " SUM= " + z(r.nippo().sum()[k], 15));
        }
        return out;
    }

    // ----------------------------------------------------------- 6 ZANDAKA
    //  ZANDABAT L-DTL: X(7) SP X(1) SP X(1) SP 9(11)
    //           L-TOT: X(7)"TOTAL  " X(4)"BAL=" 9(15)
    private static List<String> zandaka(BatchResult r) {
        List<String> out = new ArrayList<>();
        for (BatchResult.ZandakaRow z : r.zandaka().rows()) {
            out.add(z(z.kouzaNo(), 7) + " " + z.shubetsu() + " " + z.joutai()
                    + " " + z(z.zandaka(), 11));
        }
        out.add("TOTAL  BAL=" + z(r.zandaka().total(), 15));
        return out;
    }

    // ----------------------------------------------------------- 7 TESURYO
    //  TESUBAT L-TOT: X(10)"FEE COUNT=" 9(7) X(7)" TOTAL=" 9(13)
    private static List<String> tesuryo(BatchResult r) {
        return List.of("FEE COUNT=" + z(r.tesuryo().count(), 7)
                       + " TOTAL=" + z(r.tesuryo().total(), 13));
    }

    // ------------------------------------------------------------ 8 KYUMIN
    //  KYUMBAT L-DTL: X(9)"DORMANT= " X(7)
    private static List<String> kyumin(BatchResult r) {
        List<String> out = new ArrayList<>();
        for (Long kz : r.kyumin()) out.add("DORMANT= " + z(kz, 7));
        return out;
    }

    // ------------------------------------------------------------ 9 KOUZA.LST
    //  MASTBAT L-DTL: X(5)"ACCT=" X(7) X(5)" TYP=" X(1) X(4)" ST=" X(1)
    //                 X(6)" OPEN=" X(8) X(5)" BAL=" 9(11)
    private static List<String> kouzaList(BatchResult r) {
        List<String> out = new ArrayList<>();
        for (BatchResult.MasterRow a : r.master()) {
            out.add("ACCT=" + z(a.kouzaNo(), 7)
                    + " TYP=" + a.shubetsu()
                    + " ST=" + a.joutai()
                    + " OPEN=" + pad(a.kaisetsu(), 8)
                    + " BAL=" + z(a.zandaka(), 11));
        }
        return out;
    }

    // ------------------------------------------------------------ 10 TOKEI
    //  TOKEBAT L1..L6: X(11) 라벨 + 9(7) / 9(15) / 9(9)
    private static List<String> tokei(BatchResult r) {
        BatchResult.Tokei t = r.tokei();
        return List.of(
                "ACCOUNTS  =" + z(t.accounts(), 7),
                "FUTSU(1)  =" + z(t.futsu(), 7),
                "TOUZA(2)  =" + z(t.touza(), 7),
                "FROZEN(9) =" + z(t.frozen(), 7),
                "TOTAL BAL =" + z(t.totalBalance(), 15),
                "TXN COUNT =" + z(t.txnCount(), 9));
    }

    // ---------------------------------------------------------------- helpers

    /**
     * COBOL {@code PIC 9(width)} 로의 MOVE 상당 — 부호 없는 제로패딩 고정폭.
     * 음수는 절댓값(부호 소실), 자리수 초과는 고위 절단 — 둘 다 COBOL 동작과 같다.
     */
    private static String z(long v, int width) {
        String s = Long.toString(Math.abs(v));
        if (s.length() > width) s = s.substring(s.length() - width);
        return "0".repeat(width - s.length()) + s;
    }

    /** COBOL {@code PIC X(width)} 로의 MOVE 상당 — 좌측정렬 공백채움/절단. */
    private static String pad(String s, int width) {
        String v = s == null ? "" : s;
        if (v.length() > width) return v.substring(0, width);
        return v + " ".repeat(width - v.length());
    }

    /**
     * COBOL 호스트변수 {@code PIC X(60)} 용량에 맞춘 절단 + 후행공백 제거.
     * Oracle {@code VARCHAR2(40)}(JA16SJIS=바이트 의미)은 60byte를 넘지 못하지만
     * PostgreSQL {@code varchar(40)}(문자 의미)은 넘을 수 있어, COBOL 쪽 절단을 모델링한다.
     * 문자 경계에서 자르므로 COBOL의 바이트 중간 절단(→ U+FFFD)은 재현하지 않는다
     * (Oracle 백엔드에서는 도달 불가한 경로).
     */
    private static String trunc60(String s) {
        if (s == null) return "";
        String v = s.stripTrailing();
        if (v.getBytes(StandardCharsets.UTF_8).length <= 60) return v;
        StringBuilder sb = new StringBuilder();
        int bytes = 0;
        for (int i = 0; i < v.length(); ) {
            int cp = v.codePointAt(i);
            int w = new String(Character.toChars(cp)).getBytes(StandardCharsets.UTF_8).length;
            if (bytes + w > 60) break;
            sb.appendCodePoint(cp);
            bytes += w;
            i += Character.charCount(cp);
        }
        return sb.toString();
    }
}
