package com.ksbank.minibank.strict.online.dao;

import org.apache.ibatis.annotations.Mapper;
import com.ksbank.minibank.strict.online.dto.HoldingsDto;

@Mapper
public interface HoldingsDao {

    long select_01(HoldingsDto dto);

    HoldingsDto select_02(HoldingsDto dto);
}
