package com.ksbank.minibank.strict.online.dao;

import org.apache.ibatis.annotations.Mapper;
import com.ksbank.minibank.strict.online.dto.FurikomiDto;

@Mapper
public interface FurikomiDao {

    FurikomiDto select_01(FurikomiDto dto);

    long select_02(FurikomiDto dto);

    FurikomiDto select_03(FurikomiDto dto);

    int update_01(FurikomiDto dto);

    int insert_01(FurikomiDto dto);

    long select_04(FurikomiDto dto);

    int update_02(FurikomiDto dto);

    long select_05(FurikomiDto dto);

    int insert_02(FurikomiDto dto);
}
