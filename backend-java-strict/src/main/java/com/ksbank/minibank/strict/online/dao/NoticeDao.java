package com.ksbank.minibank.strict.online.dao;

import org.apache.ibatis.cursor.Cursor;
import com.ksbank.minibank.strict.online.dto.CNOTICEDto;
import com.ksbank.minibank.strict.online.dto.NOTICEDto;

public interface NOTICEDao {

    // EXEC SQL DECLARE C-NOTICE CURSOR FOR ... / EXEC SQL OPEN C-NOTICE END-EXEC
    Cursor<CNOTICEDto> select_01(NOTICEDto dto);

    // EXEC SQL SELECT SEQ_NOTICE_ASIS.NEXTVAL INTO :HV-NID FROM DUAL END-EXEC
    long select_02(NOTICEDto dto);

    // IF WK-BODY = SPACES EXEC SQL INSERT ... NULL ... END-EXEC (본문 없음)
    int insert_01(NOTICEDto dto);

    // ELSE EXEC SQL INSERT ... RTRIM(:HV-BODY) ... END-EXEC (본문 있음)
    int insert_02(NOTICEDto dto);
}
