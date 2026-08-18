package com.ksbank.minibank.strict.online.db;

import java.io.InputStream;
import org.apache.ibatis.builder.xml.XMLMapperBuilder;
import org.apache.ibatis.io.Resources;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.SqlSessionFactory;
import org.apache.ibatis.session.SqlSessionFactoryBuilder;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.springframework.context.annotation.Bean;

/**
 * SqlSessionFactory 수동 구성.
 *
 * <p>mybatis-spring-boot-starter를 안 쓰는 이유: 그건 DataSource(커넥션 풀) 위에
 * SqlSessionFactory를 자동구성하는데, 이 모듈은 매 요청 {@link Db#DB_CONNECT()}로
 * 새 커넥션을 얻는 구조라(COBOL이 매 CGI 요청마다 새로 CONNECT하는 것과 동일한 모양)
 * 풀을 두면 그 원칙이 깨진다. 여기서는 Configuration만 만들고, 각 Service가
 * {@code sqlSessionFactory().openSession(conn)}으로 이미 얻은 커넥션을 그대로 물려서 쓴다.
 *
 * <p>Dao 인터페이스(예: NoticeDao)와 Mapper XML 파일명(예: NoticeMapper.xml)이 서로
 * 다른 이름이라 {@code configuration.addMapper(Class)}의 "인터페이스와 같은 이름의 XML을
 * 자동으로 찾는" 관례를 못 쓴다. 그래서 XML 경로를 직접 나열해 {@link XMLMapperBuilder}로
 * 파싱한다 — 파싱 시 XML의 {@code namespace}(Dao 인터페이스 FQCN)를 읽어 그 인터페이스를
 * 자동으로 바인딩해준다.
 */
@org.springframework.context.annotation.Configuration
public class MyBatisConfig {

    private static final String[] MAPPER_XML_PATHS = {
        "com/ksbank/minibank/strict/online/dao/LoginMapper.xml",
        "com/ksbank/minibank/strict/online/dao/NoticeMapper.xml",
        "com/ksbank/minibank/strict/online/dao/SignupMapper.xml",
        "com/ksbank/minibank/strict/online/dao/ZandakaMapper.xml",
        "com/ksbank/minibank/strict/online/dao/HoldingsMapper.xml",
        "com/ksbank/minibank/strict/online/dao/MeisaiMapper.xml",
        "com/ksbank/minibank/strict/online/dao/FurikomiMapper.xml",
        "com/ksbank/minibank/strict/online/dao/LoanMapper.xml",
        "com/ksbank/minibank/strict/online/dao/RepayMapper.xml",
    };

    @Bean
    public SqlSessionFactory sqlSessionFactory() throws Exception {
        org.apache.ibatis.session.Configuration configuration =
            new org.apache.ibatis.session.Configuration(
                new Environment("strict", new JdbcTransactionFactory(), new NoPoolDataSource()));
        for (String path : MAPPER_XML_PATHS) {
            try (InputStream in = Resources.getResourceAsStream(path)) {
                new XMLMapperBuilder(in, configuration, path, configuration.getSqlFragments()).parse();
            }
        }
        return new SqlSessionFactoryBuilder().build(configuration);
    }
}
