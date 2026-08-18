package com.ksbank.minibank.strict.online.dto;

import lombok.Data;

@Data
public class NoticeDto {

    private String FIRST_ROW = "Y";
    private String WK_TITLE;
    private String WK_BODY;
    private String WK_TAG;
    private String WK_DATE;

    private String HV_TITLE;
    private String HV_BODY;
    private String HV_TAG;
    private String HV_DATE;
    private String HV_ACT = "Y";
    private long HV_NID;

    private CNoticeDto CNoticeDto = new CNoticeDto();
}
