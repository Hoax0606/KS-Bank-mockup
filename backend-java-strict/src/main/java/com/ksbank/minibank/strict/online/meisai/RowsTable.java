package com.ksbank.minibank.strict.online.meisai;

/**
 * COBOL copy 없이 MEISAI.cbl 내부에 정의된 {@code 01 ROWS-TBL. 05 RW OCCURS 1000 TIMES}
 * 대응. 고정 크기 1000행 배열 — growable List가 아니다. COBOL이 그러하듯 1000건을
 * 넘는 명세는 조용히 무시한다(PERFORM UNTIL ... OR N >= 1000).
 */
public class RowsTable {

    public static final int MAX = 1000;

    private final String[] dt = new String[MAX];
    private final String[] kbn = new String[MAX];
    private final long[] kin = new long[MAX];
    private final long[] tes = new long[MAX];
    private final String[] tek = new String[MAX];
    private final long[] after = new long[MAX];
    private final long[] aite = new long[MAX];
    private int n = 0;

    /** COBOL: ADD 1 TO N; MOVE ... TO RW-*(N). 가득 차면(N>=1000) 조용히 무시. */
    public boolean add(String dtVal, String kbnVal, long kinVal, long tesVal, String tekVal, long aiteVal) {
        if (n >= MAX) return false;
        dt[n] = dtVal;
        kbn[n] = kbnVal;
        kin[n] = kinVal;
        tes[n] = tesVal;
        tek[n] = tekVal;
        aite[n] = aiteVal;
        n++;
        return true;
    }

    public int size() { return n; }

    public String dt(int i) { return dt[i]; }
    public String kbn(int i) { return kbn[i]; }
    public long kin(int i) { return kin[i]; }
    public long tes(int i) { return tes[i]; }
    public String tek(int i) { return tek[i]; }
    public long aite(int i) { return aite[i]; }

    public void setAfter(int i, long v) { after[i] = v; }
    public long after(int i) { return after[i]; }
}
