package com.ksbank.minibank.strict.online.dto;

/**
 * COBOL NOTICE.cbl 자신의 WORKING-STORAGE 대응.
 * 필드는 DO_LIST/DO_CREATE를 한 줄씩 옮길 때마다 하나씩 채운다.
 */
public class NOTICEDto {

    // WONLINE.cpy — 01 RESP-PTR
    private int RESP_PTR;
    // WONLINE.cpy — 01 RESP-BUF
    private StringBuilder RESP_BUF;

    public int getRESP_PTR() {
        return RESP_PTR;
    }

    public void setRESP_PTR(int RESP_PTR) {
        this.RESP_PTR = RESP_PTR;
    }

    public StringBuilder getRESP_BUF() {
        return RESP_BUF;
    }

    public void setRESP_BUF(StringBuilder RESP_BUF) {
        this.RESP_BUF = RESP_BUF;
    }

    public String FIRST_ROW = "Y";

    public String getFIRST_ROW() {
        return FIRST_ROW;
    }

    public void setFIRST_ROW(String FIRST_ROW) {
        this.FIRST_ROW = FIRST_ROW;
    }

    // EXEC SQL BEGIN DECLARE SECTION 안의 01 HV-ACT PIC X(1) VALUE 'Y'.
    private String HV_ACT = "Y";

    public String getHV_ACT() {
        return HV_ACT;
    }

    public void setHV_ACT(String HV_ACT) {
        this.HV_ACT = HV_ACT;
    }

    // 01 C-DATE / C-TAG / C-TITLE — EXEC SQL FETCH C-NOTICE INTO 대상
    private String C_DATE;
    private String C_TAG;
    private String C_TITLE;

    public String getC_DATE() {
        return C_DATE;
    }

    public void setC_DATE(String C_DATE) {
        this.C_DATE = C_DATE;
    }

    public String getC_TAG() {
        return C_TAG;
    }

    public void setC_TAG(String C_TAG) {
        this.C_TAG = C_TAG;
    }

    public String getC_TITLE() {
        return C_TITLE;
    }

    public void setC_TITLE(String C_TITLE) {
        this.C_TITLE = C_TITLE;
    }

    // WONLINE.cpy — 01 RESP-LEN
    private int RESP_LEN;

    public int getRESP_LEN() {
        return RESP_LEN;
    }

    public void setRESP_LEN(int RESP_LEN) {
        this.RESP_LEN = RESP_LEN;
    }

    // 01 WK-TITLE PIC X(600).
    private String WK_TITLE;

    public String getWK_TITLE() {
        return WK_TITLE;
    }

    public void setWK_TITLE(String WK_TITLE) {
        this.WK_TITLE = WK_TITLE;
    }

    // EXEC SQL BEGIN DECLARE SECTION 안의 01 HV-TITLE PIC X(600).
    private String HV_TITLE;

    public String getHV_TITLE() {
        return HV_TITLE;
    }

    public void setHV_TITLE(String HV_TITLE) {
        this.HV_TITLE = HV_TITLE;
    }

    // 01 WK-BODY PIC X(2000).
    private String WK_BODY;

    public String getWK_BODY() {
        return WK_BODY;
    }

    public void setWK_BODY(String WK_BODY) {
        this.WK_BODY = WK_BODY;
    }

    // EXEC SQL BEGIN DECLARE SECTION 안의 01 HV-BODY PIC X(2000).
    private String HV_BODY;

    public String getHV_BODY() {
        return HV_BODY;
    }

    public void setHV_BODY(String HV_BODY) {
        this.HV_BODY = HV_BODY;
    }

    // 01 WK-TAG PIC X(30).
    private String WK_TAG;

    public String getWK_TAG() {
        return WK_TAG;
    }

    public void setWK_TAG(String WK_TAG) {
        this.WK_TAG = WK_TAG;
    }

    // EXEC SQL BEGIN DECLARE SECTION 안의 01 HV-TAG PIC X(30).
    private String HV_TAG;

    public String getHV_TAG() {
        return HV_TAG;
    }

    public void setHV_TAG(String HV_TAG) {
        this.HV_TAG = HV_TAG;
    }

    // 01 WK-DATE PIC X(8).
    private String WK_DATE;

    public String getWK_DATE() {
        return WK_DATE;
    }

    public void setWK_DATE(String WK_DATE) {
        this.WK_DATE = WK_DATE;
    }

    // EXEC SQL BEGIN DECLARE SECTION 안의 01 HV-DATE PIC X(8).
    private String HV_DATE;

    public String getHV_DATE() {
        return HV_DATE;
    }

    public void setHV_DATE(String HV_DATE) {
        this.HV_DATE = HV_DATE;
    }

    // 01 UC-OUT PIC X(2000).
    private String UC_OUT;
    // 01 UC-INLEN PIC 9(4).
    private int UC_INLEN;
    // 01 UC-OUTLEN PIC 9(4).
    private int UC_OUTLEN;

    public String getUC_OUT() {
        return UC_OUT;
    }

    public void setUC_OUT(String UC_OUT) {
        this.UC_OUT = UC_OUT;
    }

    public int getUC_INLEN() {
        return UC_INLEN;
    }

    public void setUC_INLEN(int UC_INLEN) {
        this.UC_INLEN = UC_INLEN;
    }

    public int getUC_OUTLEN() {
        return UC_OUTLEN;
    }

    public void setUC_OUTLEN(int UC_OUTLEN) {
        this.UC_OUTLEN = UC_OUTLEN;
    }

    // EXEC SQL BEGIN DECLARE SECTION 안의 01 HV-NID PIC 9(12).
    private long HV_NID;

    public long getHV_NID() {
        return HV_NID;
    }

    public void setHV_NID(long HV_NID) {
        this.HV_NID = HV_NID;
    }
}
