package com.ksbank.minibank.strict.batch.common;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

/**
 * {@code backend-cobol/cobol/copy/PDBCONB.cpy}(DB-CONNECT / DB-DISCONNECT) 대응 공통 베이스.
 *
 * <p>COBOL 원본은 Oracle 접속(ORA_CONN/ORA_USER/ORA_PASS 환경변수)이지만, 이 Java 이식판은
 * 별도의 PostgreSQL(minibankstrict)에 붙으므로 {@code compose.strict.yml}과 동일한 이름 체계인
 * DB_URL/DB_USER/DB_PASS 를 쓴다.
 *
 * <p>배치 10프로그램은 각자 독립 JVM 프로세스({@code run_batch.sh}에서 10번 {@code java -cp} 호출)이므로
 * Spring 컨텍스트 없이 이 추상 클래스만 상속한다.
 */
public abstract class BatchProgram {

    /** COBOL {@code MAIN} 단락 상당. main()에서 {@code new X().run()} 형태로 1회 호출된다. */
    protected abstract void run() throws Exception;

    /**
     * COBOL {@code DB-CONNECT}(PDBCONB.cpy) 상당.
     * 실패 시 SYSERR 로그 후 {@code STOP RUN} 상당인 {@code System.exit(1)}.
     */
    protected Connection dbConnect(String tag) {
        String url = System.getenv("DB_URL");
        String user = System.getenv("DB_USER");
        String pass = System.getenv("DB_PASS");
        try {
            Connection conn = DriverManager.getConnection(url, user, pass);
            conn.setAutoCommit(false);
            return conn;
        } catch (SQLException e) {
            // PDBCONB.cpy의 DB-CONNECT 단락은 모든 배치 프로그램에 COPY되는데, 정작
            // 에러 메시지 리터럴은 "[YAKANBAT] DB connect failed SQLCODE=..." 로
            // 하드코딩돼 있다(복사본이 공유하는 리터럴 버그). MKDAT에서 실패하든
            // TOKEBAT에서 실패하든 이 문자열이 그대로 찍힌다 — tag 인자는 로그 목적으로
            // 남겨두되, 원본의 이 비대칭을 그대로 재현하기 위해 메시지 자체는 고정한다.
            System.err.println("[YAKANBAT] DB connect failed SQLCODE=" + e.getMessage()
                    + " (program=" + tag + ")");
            System.exit(1);
            throw new IllegalStateException("unreachable");
        }
    }

    /**
     * COBOL {@code DB-DISCONNECT}(PDBCONB.cpy) 상당 — {@code EXEC SQL COMMIT}만 하고 끝난다.
     * 원본 주석("WORK RELEASE는 GixSQL/ODPI에서 이후 처리를 멈추기 때문에 회피")대로 진짜
     * disconnect는 하지 않고, commit 실패에 대한 롤백 경로도 없다. 이 비대칭을 그대로
     * 보존하기 위해 여기서도 try/catch로 감싸지 않고 예외를 그대로 전파한다.
     */
    protected void dbDisconnect(Connection conn) throws SQLException {
        conn.commit();
    }
}
