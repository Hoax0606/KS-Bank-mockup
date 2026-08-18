package com.ksbank.minibank.strict.online.dto;

import lombok.Data;

@Data
public class MeisaiDto {

    private long HV_KOUZA;
    private long HV_ZAN;
    private long HV_CNT;
    private String WK_FILT_KBN = "A";
    private String WK_FROM = "        ";
    private String WK_TO = "        ";
    private String FIRST_ROW = "Y";

    private CMeisaiDto CMeisaiDto = new CMeisaiDto();
}
