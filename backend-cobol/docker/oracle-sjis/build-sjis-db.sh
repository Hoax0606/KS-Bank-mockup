#!/bin/bash
# 빌드 타임: 프리빌드 FREE(AL32UTF8) 삭제 → JA16SJIS로 FREE 재생성 → 앱유저+스키마+시드 적재.
# oradata 가 VOLUME 이 아니므로 결과가 이미지 레이어에 그대로 남는다.
set -euo pipefail
export ORACLE_SID=FREE

echo "[sjis-build] 리스너 기동"
"$ORACLE_HOME/bin/lsnrctl" start || true

echo "[sjis-build] 프리빌드 FREE 기동(삭제를 위해)"
sqlplus -s / as sysdba <<'EOF' || true
startup;
exit
EOF

echo "[sjis-build] 기존 FREE(AL32UTF8) 삭제"
dbca -silent -deleteDatabase -sourceDB FREE -sysPassword oracle

echo "[sjis-build] JA16SJIS 로 FREE 재생성"
dbca -silent -createDatabase \
  -templateName FREE_Database.dbc \
  -gdbName FREE -sid FREE \
  -createAsContainerDatabase true -numberOfPDBs 1 -pdbName FREEPDB1 \
  -characterSet JA16SJIS -nationalCharacterSet AL16UTF16 \
  -sysPassword oracle -systemPassword oracle -pdbAdminPassword oracle \
  -totalMemory 1800 -emConfiguration NONE \
  -datafileDestination /opt/oracle/oradata \
  -recoveryAreaDestination /opt/oracle/oradata

echo "[sjis-build] 앱유저 생성 + 스키마/시드 적재 (UTF-8 파일 → JA16SJIS 변환)"
sqlplus -s / as sysdba @/tmp/sjis/mkuser.sql
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
sqlplus -s /nolog @/tmp/sjis/01_ddl.sql
sqlplus -s /nolog @/tmp/sjis/02_seed.sql

echo "[sjis-build] FREEPDB1 자동오픈 상태 저장(SAVE STATE)"
sqlplus -s / as sysdba <<'EOF'
ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;
ALTER PLUGGABLE DATABASE FREEPDB1 SAVE STATE;
exit
EOF

echo "[sjis-build] 정상 종료(shutdown)"
sqlplus -s / as sysdba <<'EOF'
shutdown immediate;
exit
EOF
"$ORACLE_HOME/bin/lsnrctl" stop || true
echo "[sjis-build] 완료"
