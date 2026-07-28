-- ============================================================
--  ASIS デモ・リセット (§3.3)
--   動的帯域(KOUZA_NO >= 9000000000)とその取引のみ削除。
--   시연용(1000000001~)・테스트용(1000000100~) 固定口座は保存。
--   デモ中に生成された取引(固定口座宛含む当日分)も戻したい場合は
--   本スクリプトの「取引の巻き戻し」節を有効化する。
-- ============================================================

-- 1) 動的口座と関連取引を削除
DELETE FROM TORIHIKI
 WHERE KOUZA_NO >= 9000000000
    OR AITE_KOUZA >= 9000000000;
DELETE FROM KOUZA_EXT WHERE KOUZA_NO >= 9000000000;
DELETE FROM KOUZA     WHERE KOUZA_NO >= 9000000000;

-- 2) (任意)当日デモで固定口座に付いた取引を巻き戻す
--    ※ シード時点の取引は投入していないため、ここでは
--      「オンライン/バッチで発生した全取引」を削除して初期化する。
--    固定口座の残高もシード値へ戻す場合は 02_seed.sql を再実行推奨。
-- DELETE FROM TORIHIKI WHERE KOUZA_NO BETWEEN 1000000000 AND 1999999999;

-- 3) 動的採番シーケンスを初期へ(再作成)
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE SEQ_KOUZA_DYN';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
CREATE SEQUENCE SEQ_KOUZA_DYN START WITH 9000000001 INCREMENT BY 1 NOCACHE;

COMMIT;

PROMPT === リセット後の口座一覧 ===
SELECT KOUZA_NO, SHUBETSU, ZANDAKA, JOUTAI FROM KOUZA ORDER BY KOUZA_NO;
