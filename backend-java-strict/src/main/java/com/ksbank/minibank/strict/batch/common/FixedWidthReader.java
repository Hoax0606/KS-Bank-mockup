package com.ksbank.minibank.strict.batch.common;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

/**
 * COBOL {@code ORGANIZATION IS SEQUENTIAL FILE} + {@code RECORD CONTAINS n CHARACTERS}
 * (고정길이, ネイティブ)의 READ 대응. 진짜 파일을 읽는다 — 인메모리 객체 전달이 아니다.
 */
public final class FixedWidthReader implements AutoCloseable {
    private final InputStream in;
    private final int recordLen;

    public FixedWidthReader(String path, int recordLen) throws IOException {
        this.in = new FileInputStream(path);
        this.recordLen = recordLen;
    }

    /** 다음 고정길이 레코드를 읽는다. COBOL {@code READ ... AT END} 상당 — EOF면 {@code null}. */
    public byte[] read() throws IOException {
        byte[] buf = new byte[recordLen];
        int total = 0;
        while (total < recordLen) {
            int n = in.read(buf, total, recordLen - total);
            if (n < 0) {
                if (total == 0) return null; // AT END
                throw new IOException("truncated record: got " + total + " of " + recordLen + " bytes");
            }
            total += n;
        }
        return buf;
    }

    @Override
    public void close() throws IOException {
        in.close();
    }
}
