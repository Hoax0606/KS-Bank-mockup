package com.ksbank.minibank.strict.online.dao;

import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import com.ksbank.minibank.strict.online.dto.CNoticeDto;
import com.ksbank.minibank.strict.online.dto.NoticeDto;

@Mapper
public interface NoticeDao {

    List<CNoticeDto> select_01(NoticeDto dto);

    long select_02(NoticeDto dto);

    int insert_01(NoticeDto dto);

    int insert_02(NoticeDto dto);
}
