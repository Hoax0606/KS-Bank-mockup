package com.ksbank.minibank.web;

import java.util.Map;
import com.ksbank.minibank.batch.BatchService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

/** 日次夜間バッチ 실행. COBOL run_batch.sh 대체. POST /api/batch/run → 요약 JSON. */
@RestController
public class BatchController {

    private final BatchService batch;

    public BatchController(BatchService batch) {
        this.batch = batch;
    }

    @PostMapping(value = "/api/batch/run", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> run() {
        return batch.runAll();
    }
}
