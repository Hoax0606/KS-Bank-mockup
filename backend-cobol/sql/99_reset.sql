-- ============================================================
--  ASIS デモ・リセット (Shift-JIS / 일반 타입)
--   動的帯域(KOUZA_NO >= 9000000, 신규개설 9000001~)와 그 取引만 削除。
--   시연/테스트용 고정계좌(1000000~6999999)는 보존.
-- ============================================================

CONNECT minibank/minibank@//localhost:1521/XEPDB1

-- 1) 動的口座と関連取引を削除 (FK 순서: TORIHIKI -> KOUZA_EXT -> KOUZA)
DELETE FROM TORIHIKI
 WHERE KOUZA_NO >= 9000000 OR AITE_KOUZA >= 9000000;
DELETE FROM KOUZA_EXT WHERE KOUZA_NO >= 9000000;
DELETE FROM KOUZA     WHERE KOUZA_NO >= 9000000;

-- 2) (任意)固定口座に付いた取引まで초기화하려면 02_seed.sql 재실행 권장.

-- 3) 動的採番シーケンスを初期(9000001)へ 재작성
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE SEQ_KOUZA_DYN';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
CREATE SEQUENCE SEQ_KOUZA_DYN START WITH 9000001 INCREMENT BY 1 NOCACHE;

COMMIT;

PROMPT === リセット後の口座一覧 ===
SELECT KOUZA_NO, MEIGI_KANJI, SHUBETSU, ZANDAKA, JOUTAI FROM KOUZA ORDER BY KOUZA_NO;
