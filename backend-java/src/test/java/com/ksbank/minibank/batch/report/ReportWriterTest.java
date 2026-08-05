package com.ksbank.minibank.batch.report;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import com.ksbank.minibank.batch.BatchResult;
import com.ksbank.minibank.batch.MeisaiBuilder;
import com.ksbank.minibank.batch.ParityFixture;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * {@link ReportWriter} — COBOL 帳票 서식 재현 검증.
 *
 * <p>골든 문자열은 COBOL 각 프로그램의 {@code L-*} 그룹 정의에서 바이트 단위로 도출한 것이다.
 * 특히 {@code NIPPOBAT} 의 {@code " CNT="}/{@code " SUM="} 는 5글자 VALUE 가 {@code PIC X(6)} 에
 * 들어가 {@code =} 뒤에 공백이 1개 더 붙는다 — 이게 틀리면 파일 대 파일 diff 가 깨진다.
 */
class ReportWriterTest {

    @TempDir Path tmp;
    private ReportWriter writer;

    @BeforeEach
    void setUp() {
        writer = new ReportWriter(tmp.toString());
    }

    private String write(BatchResult r, String name) throws IOException {
        writer.write(r);
        return Files.readString(tmp.resolve(name), StandardCharsets.UTF_8);
    }

    @Test
    @DisplayName("NIPPO.RPT — X(6)\" CNT=\" 의 여분 공백까지 재현")
    void nippo() throws IOException {
        assertEquals("""
            KBN=1 CNT= 0000004 SUM= 000000000080000
            KBN=2 CNT= 0000002 SUM= 000000000016000
            KBN=3 CNT= 0000002 SUM= 000000000011000
            """, write(Golden.result(), "NIPPO.RPT"));
    }

    @Test
    @DisplayName("ZANDAKA.RPT — 명세행 + TOTAL 행")
    void zandaka() throws IOException {
        assertEquals("""
            1000123 1 0 00000523401
            1001011 2 0 00000045000
            1001819 2 0 00000920500
            2000456 1 0 00000088250
            3000789 1 0 00001204003
            4001213 1 0 00000003000
            5001415 1 9 00000670001
            6001617 1 0 00000158900
            TOTAL  BAL=000000003613055
            """, write(Golden.result(), "ZANDAKA.RPT"));
    }

    @Test
    @DisplayName("TESURYO.RPT")
    void tesuryo() throws IOException {
        assertEquals("FEE COUNT=0000002 TOTAL=0000000000220\n",
            write(Golden.result(), "TESURYO.RPT"));
    }

    @Test
    @DisplayName("KYUMIN.RPT")
    void kyumin() throws IOException {
        assertEquals("""
            DORMANT= 1001819
            DORMANT= 6001617
            """, write(Golden.result(), "KYUMIN.RPT"));
    }

    @Test
    @DisplayName("KOUZA.LST")
    void kouzaList() throws IOException {
        assertEquals("""
            ACCT=1000123 TYP=1 ST=0 OPEN=20180415 BAL=00000523401
            ACCT=1001011 TYP=2 ST=0 OPEN=20210101 BAL=00000045000
            ACCT=1001819 TYP=2 ST=0 OPEN=20210901 BAL=00000920500
            ACCT=2000456 TYP=1 ST=0 OPEN=20200501 BAL=00000088250
            ACCT=3000789 TYP=1 ST=0 OPEN=20190610 BAL=00001204003
            ACCT=4001213 TYP=1 ST=0 OPEN=20220301 BAL=00000003000
            ACCT=5001415 TYP=1 ST=9 OPEN=20200801 BAL=00000670001
            ACCT=6001617 TYP=1 ST=0 OPEN=20230501 BAL=00000158900
            """, write(Golden.result(), "KOUZA.LST"));
    }

    @Test
    @DisplayName("TOKEI.RPT — X(11) 고정폭 라벨")
    void tokei() throws IOException {
        assertEquals("""
            ACCOUNTS  =0000008
            FUTSU(1)  =0000006
            TOUZA(2)  =0000002
            FROZEN(9) =0000001
            TOTAL BAL =000000003613055
            TXN COUNT =000000008
            """, write(Golden.result(), "TOKEI.RPT"));
    }

    @Test
    @DisplayName("MEISAI.TXT — カナ순 D/T. tools/parity/meisai_dump.py 출력과 같은 포맷")
    void meisai() throws IOException {
        assertEquals("""
            D kouza=2000456 dt=20260801110000 kbn=1 kingaku=10000 zandakaGo=88250 meigi=佐藤花子
            T kouza=2000456 risoku=0 tesuryoGoukei=0 kakuteiZan=88250
            D kouza=1001011 dt=20260801130000 kbn=1 kingaku=20000 zandakaGo=45000 meigi=鈴木一郎
            T kouza=1001011 risoku=0 tesuryoGoukei=0 kakuteiZan=45000
            D kouza=3000789 dt=20260801120000 kbn=2 kingaku=4000 zandakaGo=1204000 meigi=髙橋圭子
            T kouza=3000789 risoku=3 tesuryoGoukei=0 kakuteiZan=1204003
            D kouza=4001213 dt=20260801140000 kbn=3 kingaku=1000 zandakaGo=3000 meigi=田中美咲
            T kouza=4001213 risoku=0 tesuryoGoukei=110 kakuteiZan=3000
            D kouza=1000123 dt=20260801090000 kbn=1 kingaku=30000 zandakaGo=545510 meigi=山田太郎
            D kouza=1000123 dt=20260801100000 kbn=2 kingaku=12000 zandakaGo=533510 meigi=山田太郎
            D kouza=1000123 dt=20260801110000 kbn=3 kingaku=10000 zandakaGo=523400 meigi=山田太郎
            T kouza=1000123 risoku=1 tesuryoGoukei=110 kakuteiZan=523401
            D kouza=5001415 dt=20260801150000 kbn=1 kingaku=20000 zandakaGo=670000 meigi=渡辺健
            T kouza=5001415 risoku=1 tesuryoGoukei=0 kakuteiZan=670001
            """, write(Golden.result(), "MEISAI.TXT"));
    }

    @Test
    @DisplayName("7개 파일 전부 생성")
    void writesSevenFiles() {
        List<String> files = writer.write(Golden.result());
        assertEquals(7, files.size());
        for (String f : files) {
            assertEquals(true, Files.exists(Path.of(f)), f);
        }
    }

    /** 파리티 픽스처를 배치에 통과시킨 뒤의 기대 결과. */
    private static final class Golden {

        static BatchResult result() {
            MeisaiBuilder.Result m = MeisaiBuilder.build(ParityFixture.accounts(),
                                                         ParityFixture.txns());
            return new BatchResult(
                m.accountsPosted(), m.interestTotal(), m.accountsWithTxn(), m.records(),
                new BatchResult.Nippo(new long[] { 0, 4, 2, 2 },
                                      new long[] { 0, 80000, 16000, 11000 }),
                new BatchResult.Zandaka(List.of(
                    new BatchResult.ZandakaRow(1000123, "1", "0",  523401),
                    new BatchResult.ZandakaRow(1001011, "2", "0",   45000),
                    new BatchResult.ZandakaRow(1001819, "2", "0",  920500),
                    new BatchResult.ZandakaRow(2000456, "1", "0",   88250),
                    new BatchResult.ZandakaRow(3000789, "1", "0", 1204003),
                    new BatchResult.ZandakaRow(4001213, "1", "0",    3000),
                    new BatchResult.ZandakaRow(5001415, "1", "9",  670001),
                    new BatchResult.ZandakaRow(6001617, "1", "0",  158900)), 3613055),
                new BatchResult.Tesuryo(2, 220),
                List.of(1001819L, 6001617L),
                List.of(
                    new BatchResult.MasterRow(1000123, "1", "0", "20180415",  523401),
                    new BatchResult.MasterRow(1001011, "2", "0", "20210101",   45000),
                    new BatchResult.MasterRow(1001819, "2", "0", "20210901",  920500),
                    new BatchResult.MasterRow(2000456, "1", "0", "20200501",   88250),
                    new BatchResult.MasterRow(3000789, "1", "0", "20190610", 1204003),
                    new BatchResult.MasterRow(4001213, "1", "0", "20220301",    3000),
                    new BatchResult.MasterRow(5001415, "1", "9", "20200801",  670001),
                    new BatchResult.MasterRow(6001617, "1", "0", "20230501",  158900)),
                new BatchResult.Tokei(8, 6, 2, 1, 3613055, 8));
        }
    }
}
