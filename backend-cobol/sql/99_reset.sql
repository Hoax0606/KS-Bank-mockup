-- ============================================================
--  ASIS デモ・リセット (전 컬럼 RAW 대응)
--   動的帯域(KOUZA_NO 9000001~, 존10진 RAW 선두바이트 0xF9)와 그 取引만 削除。
--   시연/테스트용 고정계좌(선두 F1~F6)는 보존.
--   ※ 키는 존10진 EBCDIC RAW이므로 숫자비교 대신 RAWTOHEX ... LIKE 'F9%' 로 판별.
-- ============================================================

CONNECT minibank/minibank@//localhost:1521/FREEPDB1

-- 1) 動的口座と関連取引を削除 (FK 순서: TORIHIKI -> KOUZA_EXT -> KOUZA)
DELETE FROM TORIHIKI
 WHERE RAWTOHEX(KOUZA_NO)  LIKE 'F9%'
    OR RAWTOHEX(AITE_KOUZA) LIKE 'F9%';
DELETE FROM KOUZA_EXT WHERE RAWTOHEX(KOUZA_NO) LIKE 'F9%';
DELETE FROM KOUZA     WHERE RAWTOHEX(KOUZA_NO) LIKE 'F9%';

-- 2) (任意)固定口座に付いた取引まで初期化したい場合は 02_seed.sql 재실행 권장.

-- 3) 動的採番シーケンスを初期(9000001)へ 재작성
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE SEQ_KOUZA_DYN';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
CREATE SEQUENCE SEQ_KOUZA_DYN START WITH 9000001 INCREMENT BY 1 NOCACHE;

COMMIT;

PROMPT === リセット後の口座一覧(디코드 뷰) ===
SELECT KOUZA_NO, MEIGI_KANJI, SHUBETSU, ZANDAKA, JOUTAI FROM V_KOUZA ORDER BY KOUZA_NO;
