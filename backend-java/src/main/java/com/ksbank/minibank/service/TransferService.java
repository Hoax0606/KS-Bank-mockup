package com.ksbank.minibank.service;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.Map;
import com.ksbank.minibank.codec.PackedDecimalCodec;
import com.ksbank.minibank.codec.ZonedDecimalCodec;
import com.ksbank.minibank.config.GlobalExceptionHandler.BusinessException;
import com.ksbank.minibank.domain.BalanceRow;
import com.ksbank.minibank.repository.AccountRepository;
import com.ksbank.minibank.repository.TransactionRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 振込(이체) 업무 로직. COBOL FURIKOMI.cbl 대체. ★원자적★
 * 출금측 -(금액+수수료110) + 입금측 +금액(수취계좌 자행 존재 시)를 하나의 트랜잭션으로.
 */
@Service
public class TransferService {

    private static final long FEE = 110;
    private static final DateTimeFormatter DT = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");

    private final AccountRepository accounts;
    private final TransactionRepository txns;

    public TransferService(AccountRepository accounts, TransactionRepository txns) {
        this.accounts = accounts;
        this.txns = txns;
    }

    @Transactional
    public Map<String, Object> transfer(String kouza, String aite, String kingakuStr) {
        String kz = digits7(kouza, "missing_kouza");
        String az = digits7(aite, "missing_aite");
        long amount = parseAmount(kingakuStr);
        long total = amount + FEE;

        byte[] kzRaw = ZonedDecimalCodec.encode(kz);
        byte[] azRaw = ZonedDecimalCodec.encode(az);

        BalanceRow sender = accounts.findBalance(kzRaw)
            .orElseThrow(() -> err(HttpStatus.NOT_FOUND, "kouza_not_found"));
        if (isFrozen(sender.joutai())) throw err(HttpStatus.CONFLICT, "account_frozen");
        long bal = sender.zandaka() == null ? 0 : PackedDecimalCodec.decode(sender.zandaka());
        if (bal < total) throw err(HttpStatus.CONFLICT, "insufficient_funds");

        boolean aiteExists = accounts.exists(azRaw);
        long tid = txns.nextTorihikiId();
        long rseq = txns.nextReceiptSeq();
        String dt = LocalDateTime.now().format(DT);
        byte[] dtRaw = ZonedDecimalCodec.encode(dt);          // 14 EBCDIC 숫자
        byte[] amtRaw = PackedDecimalCodec.encode(amount, 6);
        byte[] feeRaw = PackedDecimalCodec.encode(FEE, 3);

        // ===== 원자적 트랜잭션 (예외 시 @Transactional 롤백) =====
        long afterBal = bal - total;
        accounts.updateBalance(kzRaw, PackedDecimalCodec.encode(afterBal, 6));
        txns.insert(key12(tid), kzRaw, dtRaw, ZonedDecimalCodec.encode("3"),
                    amtRaw, azRaw, feeRaw);                    // 출금측 KBN3

        if (aiteExists) {
            BalanceRow rcv = accounts.findBalance(azRaw).orElseThrow(
                () -> err(HttpStatus.INTERNAL_SERVER_ERROR, "transfer_failed"));
            long rbal = rcv.zandaka() == null ? 0 : PackedDecimalCodec.decode(rcv.zandaka());
            accounts.updateBalance(azRaw, PackedDecimalCodec.encode(rbal + amount, 6));
            txns.insert(key12(txns.nextTorihikiId()), azRaw, dtRaw,
                        ZonedDecimalCodec.encode("1"), amtRaw, null, null); // 입금측 KBN1
        }
        // ===== 커밋(정상 반환 시) =====

        String receipt = "WEB" + dt.substring(0, 8) + "-" + String.format("%04d", rseq % 10000);
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("ok", true);
        res.put("kouza", kz);
        res.put("aite", az);
        res.put("receipt", receipt);
        res.put("dt", dt);
        res.put("fee", FEE);
        res.put("afterBal", afterBal);
        return res;
    }

    private static boolean isFrozen(byte[] joutai) {
        return joutai != null && joutai.length > 0 && (joutai[0] & 0xFF) == 0xF9;
    }

    private static byte[] key12(long v) {
        return ZonedDecimalCodec.encode(String.format("%012d", v));
    }

    private static String digits7(String s, String missingKey) {
        String d = s == null ? "" : s.replaceAll("[^0-9]", "");
        if (d.isEmpty()) throw err(HttpStatus.BAD_REQUEST, missingKey);
        return d.length() >= 7 ? d.substring(d.length() - 7) : "0".repeat(7 - d.length()) + d;
    }

    private static long parseAmount(String s) {
        long a;
        try { a = Long.parseLong(s == null ? "" : s.replaceAll("[^0-9]", "")); }
        catch (NumberFormatException e) { throw err(HttpStatus.BAD_REQUEST, "invalid_amount"); }
        if (a <= 0) throw err(HttpStatus.BAD_REQUEST, "invalid_amount");
        return a;
    }

    private static BusinessException err(HttpStatus s, String key) {
        return new BusinessException(s, key);
    }
}
