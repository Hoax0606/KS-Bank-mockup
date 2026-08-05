package com.ksbank.minibank.domain;

/**
 * 取引 区分別 잔액 증감(부호) 규칙. COBOL {@code YAKANBAT.CALC-DELTA} 상당.
 *
 * <p><b>온라인 明細照会와 야간배치가 반드시 같은 식을 쓰도록</b> 여기 한 곳에만 둔다.
 * 파리티에서 가장 중요한 수식이므로 두 벌 존재하면 안 된다.
 * 사용처: {@link com.ksbank.minibank.service.MeisaiService},
 * {@link com.ksbank.minibank.batch.MeisaiBuilder}.
 */
public final class TxnDelta {

    private TxnDelta() {}

    /** 1=入金(+금액) 2=出金(-금액) 3=振込(-(금액+수수료)) 그 외 0. */
    public static long of(String kbn, long kingaku, long tesuryo) {
        if (kbn == null) return 0;
        return switch (kbn) {
            case "1" -> kingaku;
            case "2" -> -kingaku;
            case "3" -> -(kingaku + tesuryo);
            default -> 0;
        };
    }
}
