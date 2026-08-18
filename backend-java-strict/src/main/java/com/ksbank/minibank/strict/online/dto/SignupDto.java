package com.ksbank.minibank.strict.online.dto;

import lombok.Data;

@Data
public class SignupDto {

    private String HV_KANJI;
    private String HV_KANA;
    private String HV_BR;
    private String HV_TYPE;
    private String HV_PW;
    private String HV_SHU;
    private String HV_KAI;
    private long HV_NEWNO;
}
