package com.ksbank.minibank.strict.online.dto;

/**
 * COBOL LOGIN.cbl 자신의 WORKING-STORAGE 대응.
 * 필드는 MAIN/BUILD-JSON을 한 줄씩 옮길 때마다 하나씩 채운다.
 */
public class LOGINDto {

    // EXEC SQL BEGIN DECLARE SECTION 안의 01 HV-BR PIC X(3).
    private String HV_BR;

    public String getHV_BR() {
        return HV_BR;
    }

    public void setHV_BR(String HV_BR) {
        this.HV_BR = HV_BR;
    }

    // EXEC SQL BEGIN DECLARE SECTION 안의 01 HV-KOUZA PIC 9(7).
    private long HV_KOUZA;

    public long getHV_KOUZA() {
        return HV_KOUZA;
    }

    public void setHV_KOUZA(long HV_KOUZA) {
        this.HV_KOUZA = HV_KOUZA;
    }

    // EXEC SQL BEGIN DECLARE SECTION 안의 01 HV-PW PIC X(60).
    private String HV_PW;

    public String getHV_PW() {
        return HV_PW;
    }

    public void setHV_PW(String HV_PW) {
        this.HV_PW = HV_PW;
    }

    // EXEC SQL BEGIN DECLARE SECTION 안의 01 HV-CNT PIC 9(9).
    private long HV_CNT;

    public long getHV_CNT() {
        return HV_CNT;
    }

    public void setHV_CNT(long HV_CNT) {
        this.HV_CNT = HV_CNT;
    }

    // 01 HV-KANJI PIC X(40).
    private String HV_KANJI;
    // 01 HV-SHU PIC X(1).
    private String HV_SHU;
    // 01 HV-ZAN PIC S9(11).
    private long HV_ZAN;
    // 01 HV-JOU PIC X(1).
    private String HV_JOU;
    // 01 HV-TYPE PIC X(20).
    private String HV_TYPE;

    public String getHV_KANJI() {
        return HV_KANJI;
    }

    public void setHV_KANJI(String HV_KANJI) {
        this.HV_KANJI = HV_KANJI;
    }

    public String getHV_SHU() {
        return HV_SHU;
    }

    public void setHV_SHU(String HV_SHU) {
        this.HV_SHU = HV_SHU;
    }

    public long getHV_ZAN() {
        return HV_ZAN;
    }

    public void setHV_ZAN(long HV_ZAN) {
        this.HV_ZAN = HV_ZAN;
    }

    public String getHV_JOU() {
        return HV_JOU;
    }

    public void setHV_JOU(String HV_JOU) {
        this.HV_JOU = HV_JOU;
    }

    public String getHV_TYPE() {
        return HV_TYPE;
    }

    public void setHV_TYPE(String HV_TYPE) {
        this.HV_TYPE = HV_TYPE;
    }

    // WONLINE.cpy — 01 RESP-BUF
    private StringBuilder RESP_BUF = new StringBuilder();

    public StringBuilder getRESP_BUF() {
        return RESP_BUF;
    }

    public void setRESP_BUF(StringBuilder RESP_BUF) {
        this.RESP_BUF = RESP_BUF;
    }

    // WONLINE.cpy — 01 RESP-PTR
    private int RESP_PTR;
    // WONLINE.cpy — 01 RESP-LEN
    private int RESP_LEN;
    // 01 WK-KOUZA-Z (HV-KOUZA 편집용)
    private String WK_KOUZA_Z;

    public int getRESP_PTR() {
        return RESP_PTR;
    }

    public void setRESP_PTR(int RESP_PTR) {
        this.RESP_PTR = RESP_PTR;
    }

    public int getRESP_LEN() {
        return RESP_LEN;
    }

    public void setRESP_LEN(int RESP_LEN) {
        this.RESP_LEN = RESP_LEN;
    }

    public String getWK_KOUZA_Z() {
        return WK_KOUZA_Z;
    }

    public void setWK_KOUZA_Z(String WK_KOUZA_Z) {
        this.WK_KOUZA_Z = WK_KOUZA_Z;
    }
}
