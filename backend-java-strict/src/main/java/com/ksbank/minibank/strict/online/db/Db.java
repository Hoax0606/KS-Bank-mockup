package com.ksbank.minibank.strict.online.db;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import com.ksbank.minibank.strict.online.err.CgiError;

/**
 * COBOL copy/PDBCON.cpy (DB-CONNECT / DB-DISCONNECT) 대응.
 * COBOL은 CGI 프로세스마다 GixSQL로 새로 CONNECT하고, 요청이 끝나면
 * COMMIT WORK RELEASE 한다 — 커넥션 풀이 아니라 매 요청 1커넥션.
 * DriverManager로 그 모양을 그대로 재현한다(HikariCP 등 풀 사용 금지).
 */
public final class Db {

    private Db() {
    }

    /** COBOL DB-CONNECT. 실패 시 COBOL과 동일하게 500 db_connect_failed. */
    public static Connection DB_CONNECT() {
        try {
            Connection conn = DriverManager.getConnection(
                System.getenv("DB_URL"), System.getenv("DB_USER"), System.getenv("DB_PASS"));
            conn.setAutoCommit(false);
            return conn;
        } catch (SQLException e) {
            throw CgiError.ERR_500("db_connect_failed");
        }
    }

    /**
     * COBOL DB-DISCONNECT (= EXEC SQL COMMIT WORK RELEASE). COBOL은 오류 경로에서도
     * 이미 ROLLBACK 문을 실행한 뒤 이 절차를 호출하므로, 여기서도 무조건 COMMIT을
     * 시도하는 모양을 유지한다 — 단 이미 닫힌 커넥션이면 멱등하게 건너뛴다.
     */
    public static void DB_DISCONNECT(Connection conn) {
        if (conn == null) return;
        try {
            if (!conn.isClosed()) {
                conn.commit();
                conn.close();
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
    }
}
