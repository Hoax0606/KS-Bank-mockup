package com.ksbank.minibank.strict.online.dto;

import java.time.LocalDate;
import lombok.Data;

@Data
public class RepayDto {

    private long HV_LOANID;
    private long HV_PRIN;
    private long HV_BAL;
    private double HV_RATE;
    private long HV_KOUZA;
    private long HV_INT;
    private long HV_FEE = 550;
    private long HV_TOTAL;
    private long HV_ZAN;
    private long HV_NEWBAL;
    private long HV_REPID;
    private long HV_CNT;
    private String HV_ACT = "ACTIVE";
    private String HV_CLST = "CLOSED";

    private LocalDate WK_CLOSED_DATE;
}
