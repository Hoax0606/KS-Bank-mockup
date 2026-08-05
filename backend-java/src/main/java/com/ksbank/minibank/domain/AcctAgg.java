package com.ksbank.minibank.domain;

/**
 * 배치 집계용 계좌 레코드(일반 타입).
 * meigiKanji/meigiKana 는 明細(MEISAI) 전용 — D레코드 명의(漢字)와
 * SORTRPT 정렬키(カナ, {@link com.ksbank.minibank.batch.KanaSortKey})에 쓰인다.
 */
public record AcctAgg(int kouzaNo, String meigiKanji, String meigiKana,
                      String shubetsu, String joutai,
                      long zandaka, String kaisetsu) {}
