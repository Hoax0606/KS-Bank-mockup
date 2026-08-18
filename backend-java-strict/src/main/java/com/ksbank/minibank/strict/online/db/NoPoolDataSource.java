package com.ksbank.minibank.strict.online.db;

import java.io.PrintWriter;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.logging.Logger;
import javax.sql.DataSource;

/**
 * MyBatis {@code Environment}가 요구하는 최소 {@link DataSource}.
 * 실제 커넥션은 전부 {@link Db#DB_CONNECT()}가 담당하고, 모든 SqlSession은
 * {@code sqlSessionFactory.openSession(conn)}처럼 이미 얻은 Connection으로만 연다.
 * 이 클래스의 {@code getConnection()}은 정상 흐름에서는 절대 호출되지 않지만,
 * 혹시 호출되더라도 Db와 동일한 방식(DriverManager, 풀 없음)으로 동작하도록 구현한다.
 */
public class NoPoolDataSource implements DataSource {

    @Override
    public Connection getConnection() throws SQLException {
        return DriverManager.getConnection(
            System.getenv("DB_URL"), System.getenv("DB_USER"), System.getenv("DB_PASS"));
    }

    @Override
    public Connection getConnection(String username, String password) throws SQLException {
        return DriverManager.getConnection(System.getenv("DB_URL"), username, password);
    }

    @Override
    public <T> T unwrap(Class<T> iface) {
        throw new UnsupportedOperationException();
    }

    @Override
    public boolean isWrapperFor(Class<?> iface) {
        return false;
    }

    @Override
    public PrintWriter getLogWriter() {
        return null;
    }

    @Override
    public void setLogWriter(PrintWriter out) {
    }

    @Override
    public void setLoginTimeout(int seconds) {
    }

    @Override
    public int getLoginTimeout() {
        return 0;
    }

    @Override
    public Logger getParentLogger() {
        return Logger.getLogger("global");
    }
}
