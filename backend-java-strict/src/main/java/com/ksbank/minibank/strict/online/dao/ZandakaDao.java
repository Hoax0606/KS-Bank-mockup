package com.ksbank.minibank.strict.online.dao;

import org.apache.ibatis.annotations.Mapper;
import com.ksbank.minibank.strict.online.dto.ZandakaDto;

@Mapper
public interface ZandakaDao {

    ZandakaDto select_01(ZandakaDto dto);
}
