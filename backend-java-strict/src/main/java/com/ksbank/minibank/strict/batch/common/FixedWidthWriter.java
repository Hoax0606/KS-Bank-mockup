package com.ksbank.minibank.strict.batch.common;

import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;

/**
 * COBOL {@code ORGANIZATION IS SEQUENTIAL FILE} + {@code RECORD CONTAINS n CHARACTERS}
 * (고정길이, ネイティブ)의 WRITE 대응. {@code OPEN OUTPUT} 상당(항상 새로 생성/덮어쓰기).
 */
public final class FixedWidthWriter implements AutoCloseable {
    private final OutputStream out;
    private final int recordLen;

    public FixedWidthWriter(String path, int recordLen) throws IOException {
        this.out = new FileOutputStream(path);
        this.recordLen = recordLen;
    }

    /** COBOL {@code WRITE} 상당 — 반드시 선언된 레코드 길이와 정확히 일치해야 한다. */
    public void write(byte[] record) throws IOException {
        if (record.length != recordLen) {
            throw new IllegalArgumentException(
                    "record length " + record.length + " != " + recordLen);
        }
        out.write(record);
    }

    @Override
    public void close() throws IOException {
        out.close();
    }
}
