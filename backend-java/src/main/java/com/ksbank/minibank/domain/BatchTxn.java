package com.ksbank.minibank.domain;

/**
 * 배치 입력 거래 1행. COBOL {@code MKDAT} 의 {@code TR-DAT-REC}(WTRDAT.cpy) 상당.
 *
 * <p>{@code tesuryo} 는 nullable 이 아니라 {@code long} 이다 — SQL 측 {@code COALESCE(tesuryo,0)}
 * 로 0을 채운다. MKDAT 도 {@code MOVE 0 TO P-TESURYO} 로 기본값 0을 쓰므로 동형이다.
 */
public record BatchTxn(long torihikiId, int kouzaNo, String dt, String kbn,
                       long kingaku, long tesuryo) {}
