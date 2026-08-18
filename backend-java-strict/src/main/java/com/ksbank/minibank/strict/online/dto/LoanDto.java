package com.ksbank.minibank.strict.online.dto;

import lombok.Data;

@Data
public class LoanDto {

    private String FIRST_ROW = "Y";
    private long HV_KOUZA;
    private long HV_AMT;
    private long HV_BAL;
    private long HV_ZAN;
    private String HV_METHOD;
    private long HV_YEARS;
    private long HV_LOANID;
    private long HV_USED;
    private String HV_DT;
    private long HV_TID;
    private long HV_CNT;
    private String HV_ACT = "ACTIVE";

    private CLoanDto CLoanDto = new CLoanDto();
}
