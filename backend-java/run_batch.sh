#!/bin/sh
# ============================================================
#  Java(TOBE) 야간배치 실행 스크립트
#   COBOL 쪽 backend-cobol/build/run_batch.sh(JCL 스텝분할 상당)와
#   대칭되는 파일. 리눅스에는 JCL도 .ps1도 못 쓰므로, ASIS/TOBE 둘 다
#   .sh로 배치를 실행하기로 확정(원인: JCL은 리눅스 네이티브 실행 불가,
#   .ps1은 Windows PowerShell 전용 — 둘 다 리눅스에선 성립하지 않음).
#
#   Java는 COBOL처럼 여러 실행체를 순서대로 부르는 게 아니라
#   BatchService.run() 하나가 10단계를 전부 순서대로 처리하므로,
#   이 스크립트는 그 진입점(POST /api/batch/run)을 한 번 호출하는
#   얇은 셸 래퍼다. 산출물은 backend-java/data/ 에 COBOL과 같은
#   帳票 7종(MEISAI.TXT + 6종)으로 떨어진다.
#
#   실행: sh backend-java/run_batch.sh (Java 앱이 이미 떠 있어야 함)
#   환경변수: JAVA_URL(기본 http://localhost:8081)
# ============================================================
set -e
JAVA_URL="${JAVA_URL:-http://localhost:8081}"

echo "[batch] Java(TOBE) 배치 실행 -> ${JAVA_URL}/api/batch/run"
curl -sS -f -X POST "${JAVA_URL}/api/batch/run" -o /tmp/java_batch_result.json
echo "[batch] done. summary:"
cat /tmp/java_batch_result.json
echo
echo "[batch] 산출 파일: backend-java/data/ (MEISAI.TXT + NIPPO/ZANDAKA/TESURYO/KYUMIN/KOUZA.LST/TOKEI.RPT)"
