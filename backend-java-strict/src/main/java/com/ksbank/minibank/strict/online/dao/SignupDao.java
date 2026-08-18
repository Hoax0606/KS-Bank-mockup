package com.ksbank.minibank.strict.online.dao;

import org.apache.ibatis.annotations.Mapper;
import com.ksbank.minibank.strict.online.dto.SignupDto;

@Mapper
public interface SignupDao {

    long select_01(SignupDto dto);

    int insert_01(SignupDto dto);

    int insert_02(SignupDto dto);
}
