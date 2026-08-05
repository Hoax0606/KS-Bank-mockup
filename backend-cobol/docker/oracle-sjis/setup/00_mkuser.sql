-- ============================================================
--  minibank 앱 유저 생성 (XEPDB1)
--   oracle_sjis 컨테이너가 DB를 처음 만든 직후 1회 실행된다
--   (/opt/oracle/scripts/setup 안의 *.sql 을 runUserScripts.sh 가
--    `sqlplus / as sysdba` 로 알파벳 순 실행 → 00_ → 01_ddl → 02_seed).
--
--  ※ SERVER-SETUP.md §4-6 주석에 있던 수동 유저 생성 절차를 자동화한 것.
--  ※ 비밀번호 minibank/minibank 는 데모 더미값.
-- ============================================================
ALTER SESSION SET CONTAINER=XEPDB1;

-- 재실행 안전(이미 있으면 무시)
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM DBA_USERS WHERE USERNAME = 'MINIBANK';
  IF n = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER minibank IDENTIFIED BY minibank QUOTA UNLIMITED ON USERS';
  END IF;
END;
/
GRANT CONNECT, RESOURCE, CREATE VIEW TO minibank;
exit
