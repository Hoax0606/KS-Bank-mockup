package com.ksbank.minibank.strict.online.dto;

import lombok.Data;

@Data
public class LoginDto {

    private String HV_BR;
    private long HV_KOUZA;
    private String HV_PW;
    private long HV_CNT;
    private String HV_KANJI;
    private String HV_SHU;
    private long HV_ZAN;
    private String HV_JOU;
    private String HV_TYPE;
}
