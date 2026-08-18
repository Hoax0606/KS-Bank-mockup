package com.ksbank.minibank.strict.batch.yakanbat;

import com.ksbank.minibank.strict.batch.common.BatchProgram;
import com.ksbank.minibank.strict.batch.common.Cobol;
import com.ksbank.minibank.strict.batch.common.FixedWidthReader;
import com.ksbank.minibank.strict.batch.common.FixedWidthWriter;
import com.ksbank.minibank.strict.batch.common.Wmeisai;
import com.ksbank.minibank.strict.batch.common.Wtrdat;

import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Arrays;

/**
 * {@code YAKANBAT.cbl} 1:1 포팅 — 日次夜間バッチ(明細+利息専任).
 *
 * <p>オンライン CGI가 이미 TORIHIKI에 INSERT하고 잔고도 즉시 반영했으므로, 본 배치는
 * (1) 당일 취급(TORIHIKI.SORTED, 하드코딩 리터럴)을 계좌별로 읽어 明細D+合計T를
 * REPORT.WORK(하드코딩 리터럴, 164byte)에 쓰고, (2) 확정잔고에 대한 일일이자를 계산해
 * KOUZA.ZANDAKA에 반영(계좌별 즉시 UPDATE+COMMIT)한다.
 *
 * <p>COBOL 단락명을 그대로 메서드명으로 옮겼다: PROCESS-SORTED/PARSE-DAT/START-ACCT/
 * APPLY-TXN/CALC-DELTA/BREAK-ACCT/RELEASE-RPTW-D/RELEASE-RPTW-T.
 */
public class Yakanbat extends BatchProgram {

    public static void main(String[] a) throws Exception {
        new Yakanbat().run();
    }

    private static final int RPTW_LEN = 164;
    private static final int RPTW_KANA_OFF = 0, RPTW_KANA_LEN = 60;
    private static final int RPTW_SEQ_OFF = 60, RPTW_SEQ_LEN = 6;
    private static final int RPTW_BODY_OFF = 66, RPTW_BODY_LEN = 98;

    /** TXTBL OCCURS 500 TIMES — 고정 크기 배열(growable List 금지, COBOL의 고정 테이블 그대로). */
    private static final int TXTBL_SIZE = 500;
    private final String[] txDt = new String[TXTBL_SIZE];
    private final String[] txKbn = new String[TXTBL_SIZE];
    private final long[] txKin = new long[TXTBL_SIZE];
    private final long[] txDelta = new long[TXTBL_SIZE];
    private int ntx = 0; // NTX PIC 9(4) COMP

    // -- control break 상태 (WORKING-STORAGE 01 항목 그대로) --
    private long curKouza = 0;
    private boolean haveAcct = false;
    private long accBal = 0;
    private long accFee = 0;
    private long accInt = 0;
    private long accTd = 0;
    private long accOpen = 0;
    private long accRun = 0;
    private long accNew = 0;
    private String accShu = "1";
    private String accKanji = "";
    private String accKana = "";
    private long wkDelta = 0;
    private long seqCnt = 0; // SEQ-CNT PIC 9(6)

    // -- DAT レコード解析(P-*) --
    private long pId;
    private long pKouza;
    private String pNichiji;
    private String pKbn;
    private long pKingaku;
    private long pAite;
    private long pTesuryo;
    private String pTekiyou; // 파싱만 하고 이후 미사용(YAKANBAT.cbl 원본의 죽은 필드, 그대로 재현)

    private Connection conn;
    private FixedWidthWriter rptw;

    @Override
    protected void run() throws Exception {
        // MAIN 의 DISPLAY 문에는 UPON SYSERR 절이 없다(YAKANBAT.cbl 원본) -> 기본 대상(표준출력).
        System.out.println("[YAKANBAT] start (reads TORIHIKI.SORTED)");
        conn = dbConnect("YAKANBAT");
        processSorted();
        dbDisconnect(conn);
        System.out.println("[YAKANBAT] done (wrote REPORT.WORK)");
    }

    /** COBOL {@code PROCESS-SORTED} 단락. */
    private void processSorted() throws IOException, SQLException {
        try (FixedWidthReader sdat = new FixedWidthReader("TORIHIKI.SORTED", Wtrdat.RECORD_LEN);
             FixedWidthWriter out = new FixedWidthWriter("REPORT.WORK", RPTW_LEN)) {
            this.rptw = out;
            haveAcct = false;
            seqCnt = 0;
            byte[] rec;
            while ((rec = sdat.read()) != null) {
                parseDat(rec);
                if (!haveAcct) {
                    startAcct();
                } else if (pKouza != curKouza) {
                    breakAcct();
                    startAcct();
                }
                applyTxn();
            }
            if (haveAcct) {
                breakAcct();
            }
        }
    }

    /** COBOL {@code PARSE-DAT} 단락. */
    private void parseDat(byte[] rec) {
        pId = Cobol.getPic9(rec, Wtrdat.ID_OFF, Wtrdat.ID_LEN);
        pKouza = Cobol.getPic9(rec, Wtrdat.KOUZA_OFF, Wtrdat.KOUZA_LEN);
        pNichiji = Cobol.getAscii(rec, Wtrdat.NICHIJI_OFF, Wtrdat.NICHIJI_LEN);
        pKbn = Cobol.getAscii(rec, Wtrdat.KBN_OFF, Wtrdat.KBN_LEN);
        pKingaku = Cobol.getComp3(rec, Wtrdat.KINGAKU_OFF, Wtrdat.KINGAKU_DIGITS);
        pAite = 0;
        pTesuryo = 0;
        if ("3".equals(pKbn)) {
            pAite = Cobol.getPic9(rec, Wtrdat.AITE_OFF, Wtrdat.AITE_LEN);
            pTesuryo = Cobol.getComp3(rec, Wtrdat.TESURYO_OFF, Wtrdat.TESURYO_DIGITS);
        }
        // MOVE TD-TEKIYOU TO P-TEKIYOU — kbn 무관 항상 파싱, 이후 어디서도 참조되지 않는다.
        pTekiyou = Cobol.getSjis(rec, Wtrdat.TEKIYOU_OFF, Wtrdat.TEKIYOU_LEN);
    }

    /** COBOL {@code START-ACCT} 단락. */
    private void startAcct() throws SQLException {
        curKouza = pKouza;
        haveAcct = true;
        accFee = 0;
        accTd = 0;
        ntx = 0;

        long hvKz7 = Cobol.truncate(pKouza, 7);
        boolean found = false;
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT MEIGI_KANJI, MEIGI_KANA, SHUBETSU, ZANDAKA FROM KOUZA WHERE KOUZA_NO = ?")) {
            ps.setLong(1, hvKz7);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    found = true;
                    accKanji = rs.getString(1);
                    accKana = rs.getString(2);
                    accShu = rs.getString(3);
                    accBal = rs.getLong(4);
                }
            }
        } catch (SQLException e) {
            // COBOL: SQLCODE<>0 이면 무조건 ELSE 분기(진짜 DB 에러도 "미발견"과 동일 취급) —
            // 이 비대칭을 재현하기 위해 여기서도 예외를 삼키고 기본값 분기로 떨어뜨린다.
            found = false;
        }
        if (!found) {
            accKanji = "";
            accKana = "";
            accShu = "1";
            accBal = 0;
            System.out.println("  WARN kouza not in master: " + Cobol.pic9(pKouza, 7));
        }
    }

    /** COBOL {@code APPLY-TXN} 단락. */
    private void applyTxn() {
        calcDelta();
        accTd += wkDelta;
        if ("3".equals(pKbn)) {
            accFee += pTesuryo;
        }
        txDt[ntx] = pNichiji;
        txKbn[ntx] = pKbn;
        txKin[ntx] = pKingaku;
        txDelta[ntx] = wkDelta;
        ntx++;
    }

    /** COBOL {@code CALC-DELTA} 단락. */
    private void calcDelta() {
        switch (pKbn) {
            case "1" -> wkDelta = pKingaku;
            case "2" -> wkDelta = -pKingaku;
            case "3" -> wkDelta = -(pKingaku + pTesuryo);
            default -> wkDelta = 0;
        }
    }

    /** COBOL {@code BREAK-ACCT} 단락. */
    private void breakAcct() throws SQLException, IOException {
        accOpen = accBal - accTd;
        accInt = 0;
        if ("1".equals(accShu) && accBal > 0) {
            // FUNCTION INTEGER-PART(WK-DIV / 365000) — 정수 나눗셈(절삭). Math.floorDiv 아님.
            accInt = accBal / 365000L;
        }
        accNew = accBal + accInt;

        long hvKz7 = Cobol.truncate(curKouza, 7);
        long hvNewBal = Cobol.truncate(accNew, 11);

        // COBOL: EXEC SQL UPDATE KOUZA ... END-EXEC 뒤에 SQLCODE 체크가 전혀 없다.
        // UPDATE가 실패해도(예: 락 충돌, 제약 위반) 무시하고 그대로 다음 문장(COMMIT)으로
        // 진행하는 것이 원본의 실제 동작이므로, 여기서도 SQLException을 조용히 삼켜서
        // (로그도 남기지 않음 — COBOL도 아무 표시를 남기지 않는다) 이후 로직이 UPDATE
        // 성공 여부와 무관하게 무조건 실행되도록 재현한다.
        try (PreparedStatement ps = conn.prepareStatement(
                "UPDATE KOUZA SET ZANDAKA = ? WHERE KOUZA_NO = ?")) {
            ps.setLong(1, hvNewBal);
            ps.setLong(2, hvKz7);
            ps.executeUpdate();
        } catch (SQLException ignored) {
            // 의도적으로 무시 — COBOL 원본에 SQLCODE 체크 자체가 없다.
        }
        // EXEC SQL COMMIT — 계좌별 즉시 커밋(전체 일괄 아님). UPDATE 성공/실패와 무관하게
        // 그대로 다음 계좌로 진행한다(원본과 동일).
        conn.commit();

        accRun = accOpen;
        for (int tix = 0; tix < ntx; tix++) {
            accRun += txDelta[tix];
            releaseRptwD(tix);
        }
        releaseRptwT();
        haveAcct = false;
    }

    /** COBOL {@code RELEASE-RPTW-D} 단락. */
    private void releaseRptwD(int tix) throws IOException {
        seqCnt++;
        byte[] body = new byte[Wmeisai.RECORD_LEN];
        Arrays.fill(body, (byte) ' ');
        body[Wmeisai.KUBUN_OFF] = 'D';
        Cobol.putPic9(body, Wmeisai.KOUZA_OFF, Wmeisai.KOUZA_LEN, curKouza);
        Cobol.putSjis(body, Wmeisai.D_KANJI_OFF, Wmeisai.D_KANJI_LEN, accKanji);
        Cobol.putPicX(body, Wmeisai.D_DT_OFF, Wmeisai.D_DT_LEN, txDt[tix]);
        Cobol.putPicX(body, Wmeisai.D_KBN_OFF, Wmeisai.D_KBN_LEN, txKbn[tix]);
        Cobol.putComp3(body, Wmeisai.D_KINGAKU_OFF, Wmeisai.D_KINGAKU_DIGITS, txKin[tix]);
        Cobol.putComp3(body, Wmeisai.D_ZANDAKA_OFF, Wmeisai.D_ZANDAKA_DIGITS, accRun);
        writeRptw(body);
    }

    /** COBOL {@code RELEASE-RPTW-T} 단락. */
    private void releaseRptwT() throws IOException {
        seqCnt++;
        byte[] body = new byte[Wmeisai.RECORD_LEN];
        Arrays.fill(body, (byte) ' ');
        body[Wmeisai.KUBUN_OFF] = 'T';
        Cobol.putPic9(body, Wmeisai.KOUZA_OFF, Wmeisai.KOUZA_LEN, curKouza);
        Cobol.putComp3(body, Wmeisai.T_RISOKU_OFF, Wmeisai.T_RISOKU_DIGITS, accInt);
        Cobol.putComp3(body, Wmeisai.T_TESURYO_OFF, Wmeisai.T_TESURYO_DIGITS, accFee);
        Cobol.putComp3(body, Wmeisai.T_KAKUTEI_OFF, Wmeisai.T_KAKUTEI_DIGITS, accNew);
        writeRptw(body);
    }

    private void writeRptw(byte[] body) throws IOException {
        byte[] rec = new byte[RPTW_LEN];
        Arrays.fill(rec, (byte) ' ');
        Cobol.putSjis(rec, RPTW_KANA_OFF, RPTW_KANA_LEN, accKana);
        Cobol.putPic9(rec, RPTW_SEQ_OFF, RPTW_SEQ_LEN, seqCnt);
        System.arraycopy(body, 0, rec, RPTW_BODY_OFF, RPTW_BODY_LEN);
        rptw.write(rec);
    }
}
