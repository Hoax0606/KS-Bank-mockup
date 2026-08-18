package com.ksbank.minibank.strict.online.dao;

import org.apache.ibatis.annotations.Mapper;
import com.ksbank.minibank.strict.online.dto.LoginDto;

@Mapper
public interface LoginDao {

    long select_01(LoginDto dto);

    LoginDto select_02(LoginDto dto);
}
