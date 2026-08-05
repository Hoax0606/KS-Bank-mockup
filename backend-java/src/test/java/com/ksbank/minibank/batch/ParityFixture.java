package com.ksbank.minibank.batch;

import java.util.List;
import com.ksbank.minibank.domain.AcctAgg;
import com.ksbank.minibank.domain.BatchTxn;

/**
 * 테스트용 파리티 픽스처 — SQL 픽스처와 <b>같은 데이터</b>를 Java 객체로 표현.
 *
 * <p>정본: {@code backend-cobol/sql/90_parity_fixture.sql} /
 * {@code backend-java/src/main/resources/db/90_parity_fixture.sql}.
 * SQL 쪽을 바꾸면 여기도 같이 바꿔야 한다(그래야 단위테스트가 실제 대조와 같은 것을 검증한다).
 */
public final class ParityFixture {

    private ParityFixture() {}

    /** {@code ReportRepository.allAccounts()} 와 같은 순서(kouza_no 오름차순). */
    public static List<AcctAgg> accounts() {
        return List.of(
            new AcctAgg(1000123, "山田太郎",   "ヤマダタロウ",     "1", "0",  523400, "20180415"),
            new AcctAgg(1001011, "鈴木一郎",   "スズキイチロウ",   "2", "0",   45000, "20210101"),
            new AcctAgg(1001819, "小林大輔",   "コバヤシダイスケ", "2", "0",  920500, "20210901"),
            new AcctAgg(2000456, "佐藤花子",   "サトウハナコ",     "1", "0",   88250, "20200501"),
            new AcctAgg(3000789, "髙橋圭子",   "タカハシケイコ",   "1", "0", 1204000, "20190610"),
            new AcctAgg(4001213, "田中美咲",   "タナカミサキ",     "1", "0",    3000, "20220301"),
            new AcctAgg(5001415, "渡辺健",     "ワタナベケン",     "1", "9",  670000, "20200801"),
            new AcctAgg(6001617, "中村愛",     "ナカムラアイ",     "1", "0",  158900, "20230501"));
    }

    /** {@code ReportRepository.allTxnsForBatch()} 와 같은 순서(kouza_no, torihiki_id). */
    public static List<BatchTxn> txns() {
        return List.of(
            new BatchTxn(100000000001L, 1000123, "20260801090000", "1", 30000,   0),
            new BatchTxn(100000000002L, 1000123, "20260801100000", "2", 12000,   0),
            new BatchTxn(100000000003L, 1000123, "20260801110000", "3", 10000, 110),
            new BatchTxn(100000000006L, 1001011, "20260801130000", "1", 20000,   0),
            new BatchTxn(100000000004L, 2000456, "20260801110000", "1", 10000,   0),
            new BatchTxn(100000000005L, 3000789, "20260801120000", "2",  4000,   0),
            new BatchTxn(100000000007L, 4001213, "20260801140000", "3",  1000, 110),
            new BatchTxn(100000000008L, 5001415, "20260801150000", "1", 20000,   0));
    }
}
