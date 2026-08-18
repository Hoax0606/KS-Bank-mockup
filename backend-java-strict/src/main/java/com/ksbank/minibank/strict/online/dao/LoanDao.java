package com.ksbank.minibank.strict.online.dao;

import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import com.ksbank.minibank.strict.online.dto.CLoanDto;
import com.ksbank.minibank.strict.online.dto.LoanDto;

@Mapper
public interface LoanDao {

    List<CLoanDto> select_01(LoanDto dto);

    long select_02(LoanDto dto);

    long select_03(LoanDto dto);

    LoanDto select_04(LoanDto dto);

    int insert_01(LoanDto dto);

    long select_05(LoanDto dto);

    int update_01(LoanDto dto);

    int insert_02(LoanDto dto);
}
