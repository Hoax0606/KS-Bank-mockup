package com.ksbank.minibank.strict.online.dao;

import com.ksbank.minibank.strict.online.dto.LOGINDto;

public interface LOGINDao {

    // EXEC SQL SELECT COUNT(*) INTO :HV-CNT FROM KOUZA_EXT WHERE ... END-EXEC
    long select_01(LOGINDto dto);

    // EXEC SQL SELECT K.MEIGI_KANJI, K.SHUBETSU, K.ZANDAKA, K.JOUTAI, X.ACCT_TYPE
    //     INTO :HV-KANJI, :HV-SHU, :HV-ZAN, :HV-JOU, :HV-TYPE
    //     FROM KOUZA K, KOUZA_EXT X WHERE ... END-EXEC
    LOGINDto select_02(LOGINDto dto);
}
