package com.ksbank.minibank.strict.batch.common;

import java.io.BufferedWriter;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;

/**
 * NIPPOBAT/ZANDABAT/TESUBAT/KYUMBAT/MASTBAT/TOKEBAT — {@code ORGANIZATION IS LINE SEQUENTIAL}
 * 텍스트 帳票 6종 공통 WRITE 대응. 레이블/숫자 모두 ASCII 라 인코딩은 고정, 개행은 LF
 * (GnuCOBOL LINE SEQUENTIAL on Linux 와 동일 — CRLF 아님).
 */
public final class LineSequentialWriter implements AutoCloseable {
    private final BufferedWriter w;

    public LineSequentialWriter(String path) throws IOException {
        this.w = new BufferedWriter(
                new OutputStreamWriter(new FileOutputStream(path), StandardCharsets.US_ASCII));
    }

    /** COBOL {@code WRITE REP-REC FROM L-xxx} 상당. */
    public void writeLine(String line) throws IOException {
        w.write(line);
        w.write('\n');
    }

    @Override
    public void close() throws IOException {
        w.close();
    }
}
