package com.ksbank.minibank.strict.online.dao;

import org.apache.ibatis.annotations.Mapper;
import com.ksbank.minibank.strict.online.dto.RepayDto;

@Mapper
public interface RepayDao {

    long select_01(RepayDto dto);

    RepayDto select_02(RepayDto dto);

    long select_03(RepayDto dto);

    int update_01(RepayDto dto);

    int update_02(RepayDto dto);

    int update_03(RepayDto dto);

    long select_04(RepayDto dto);

    int insert_01(RepayDto dto);
}
