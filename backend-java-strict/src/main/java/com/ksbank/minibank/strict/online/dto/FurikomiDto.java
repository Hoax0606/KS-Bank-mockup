package com.ksbank.minibank.strict.online.dto;

import lombok.Data;

@Data
public class FurikomiDto {

    private long HV_KOUZA;
    private long HV_AITE;
    private long HV_AMT;
    private long HV_FEE = 110;
    private long HV_TOTAL;
    private long HV_ZAN;
    private long HV_AZAN;
    private String HV_JOU;
    private String HV_DT;
    private long HV_TID;
    private long HV_TID2;
    private long HV_RSEQ;
    private long HV_CNT;
}
