package com.ksbank.minibank.strict.online.db;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import com.ksbank.minibank.strict.online.err.CgiError;

public final class PDBCONService {

    private static final ThreadLocal<Connection> CURRENT = new ThreadLocal<>();

    private PDBCONService() {
    }

    public static void DB_CONNECT() {
        Connection stale = CURRENT.get();
        if (stale != null) {
            try {
                if (!stale.isClosed()) {
                    stale.close();
                }
            } catch (SQLException ignore) {
            }
            CURRENT.remove();
        }
        try {
            Connection conn = DriverManager.getConnection(
                System.getenv("DB_URL"), System.getenv("DB_USER"), System.getenv("DB_PASS"));
            conn.setAutoCommit(false);
            CURRENT.set(conn);
        } catch (SQLException e) {
            throw CgiError.ERR_500("db_connect_failed");
        }
    }

    public static Connection CONN() {
        return CURRENT.get();
    }

    public static void DB_DISCONNECT() {
        Connection conn = CURRENT.get();
        if (conn == null) return;
        try {
            if (!conn.isClosed()) {
                conn.commit();
                conn.close();
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        } finally {
            CURRENT.remove();
        }
    }
}
