package com.ksbank.minibank.strict.online.dto;

import lombok.Data;

@Data
public class CLoanDto {

    private long C_ID;
    private long C_PRIN;
    private long C_BAL;
    private String C_METHOD;
    private long C_YEARS;
}
