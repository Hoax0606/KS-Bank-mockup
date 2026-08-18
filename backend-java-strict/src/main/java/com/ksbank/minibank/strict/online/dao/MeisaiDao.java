package com.ksbank.minibank.strict.online.dao;

import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import com.ksbank.minibank.strict.online.dto.CMeisaiDto;
import com.ksbank.minibank.strict.online.dto.MeisaiDto;

@Mapper
public interface MeisaiDao {

    List<CMeisaiDto> select_01(MeisaiDto dto);

    long select_02(MeisaiDto dto);

    long select_03(MeisaiDto dto);
}
