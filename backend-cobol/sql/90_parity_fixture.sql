-- ============================================================
--  パリティ固定データ (Oracle / JA16SJISTILDE)  —  COBOL↔Java 1:1 対照専用
--
--  ☠☠☠ 本番/デモサーバの Oracle では絶対に実行しないこと ☠☠☠
--    冒頭で DELETE FROM TORIHIKI(全件削除)を行い、残高もシード値へ戻す。
--    ライブのデモデータ(取引履歴・残高)が消える。
--    実行してよいのは「1:1 対照用のローカル/検証環境」だけ。
--    → ライブのリセットが目的なら sql/99_reset.sql(動的口座のみ削除)を使う。
--
--  ★なぜ必要か
--    オンライン(/api/furikomi)で取引を発生させると TORIHIKI_DT が
--    挿入時刻(wall-clock)になる。TORIHIKI_DT は明細 D レコード
--    (MD-TORIHIKI-DT PIC X(14))にそのまま入るため、両スタックに同じ
--    HTTP 呼び出しを投げても dt が食い違い、明細の全行が diff する。
--    さらに COBOL コンテナのみ TZ=Asia/Tokyo。
--    → TORIHIKI_ID と TORIHIKI_DT を「リテラル」で固定する。
--
--  ★冪等性
--    夜間バッチは newBal = 現残高 + 利息 で、再実行するたびに利息が
--    積み増される(処理済フラグが無い)。対照実行の前に必ず本スクリプトを
--    再適用して初期状態へ戻すこと。
--
--  対応する PostgreSQL 版:
--    backend-java/src/main/resources/db/90_parity_fixture.sql
--  (両者は論理的に同一。方言のみ異なる)
--
--  実行: sqlplus -s /nolog @90_parity_fixture.sql
-- ============================================================

CONNECT minibank/minibank@//localhost:1521/XEPDB1

SET FEEDBACK OFF

-- ------------------------------------------------------------
-- 1) 取引ジャーナル 全削除
-- ------------------------------------------------------------
DELETE FROM TORIHIKI;

-- ------------------------------------------------------------
-- 2) 動的口座帯(9000000以上)を削除 — FK 順: KOUZA_EXT -> KOUZA
-- ------------------------------------------------------------
DELETE FROM KOUZA_EXT WHERE KOUZA_NO >= 9000000;
DELETE FROM KOUZA     WHERE KOUZA_NO >= 9000000;

-- ------------------------------------------------------------
-- 3) 固定8口座の 残高・状態 をシード値へ復元
--    (99_reset.sql は残高を戻さないため対照には使えない)
-- ------------------------------------------------------------
UPDATE KOUZA SET ZANDAKA =  523400, JOUTAI = '0' WHERE KOUZA_NO = 1000123;
UPDATE KOUZA SET ZANDAKA =   88250, JOUTAI = '0' WHERE KOUZA_NO = 2000456;
UPDATE KOUZA SET ZANDAKA = 1204000, JOUTAI = '0' WHERE KOUZA_NO = 3000789;
UPDATE KOUZA SET ZANDAKA =   45000, JOUTAI = '0' WHERE KOUZA_NO = 1001011;
UPDATE KOUZA SET ZANDAKA =    3000, JOUTAI = '0' WHERE KOUZA_NO = 4001213;
UPDATE KOUZA SET ZANDAKA =  670000, JOUTAI = '9' WHERE KOUZA_NO = 5001415;
UPDATE KOUZA SET ZANDAKA =  158900, JOUTAI = '0' WHERE KOUZA_NO = 6001617;
UPDATE KOUZA SET ZANDAKA =  920500, JOUTAI = '0' WHERE KOUZA_NO = 1001819;

-- ------------------------------------------------------------
-- 4) 取引 8件 — ID/DT はリテラル固定。DT は ID と単調増加。
--
--    ★DT を ID と単調にする理由
--      MKDAT は ORDER BY KOUZA_NO, TORIHIKI_ID、オンライン明細
--      (TransactionRepository.findByKouza)は ORDER BY torihiki_dt,
--      torihiki_id。単調ならこの2つが同じ順序になり、バッチの
--      取引後残高とオンライン /api/meisai の afterBal が一致する
--      (無料の相互検証になる)。
--
--    網羅ケース:
--      1000123 普通  3件(区分1/2/3, 手数料あり) 利息>0 / 同一口座複数=SORTDAT第2キー検証
--      2000456 普通  1件(区分1)                 利息0(残高 < 365000)
--      3000789 普通  1件(区分2)                 利息>0(3円)
--      1001011 当座  1件(区分1)                 利息0 だが T レコードは存在
--      4001213 普通  1件(区分3)                 利息0 + 手数料合計は 110(0ではない)
--      5001415 普通  1件(区分1) JOUTAI='9'凍結   凍結でも利息が付く(両系の共通仕様を固定)
--      6001617 普通  0件                        休眠 + 明細なし
--      1001819 当座  0件                        休眠(当座・無取引)
-- ------------------------------------------------------------
INSERT INTO TORIHIKI (TORIHIKI_ID,KOUZA_NO,TORIHIKI_DT,TORIHIKI_KBN,KINGAKU,AITE_KOUZA,TESURYO,TEKIYOU)
  VALUES (100000000001,1000123,'20260801090000','1',30000,NULL,NULL,NULL);
INSERT INTO TORIHIKI (TORIHIKI_ID,KOUZA_NO,TORIHIKI_DT,TORIHIKI_KBN,KINGAKU,AITE_KOUZA,TESURYO,TEKIYOU)
  VALUES (100000000002,1000123,'20260801100000','2',12000,NULL,NULL,NULL);
INSERT INTO TORIHIKI (TORIHIKI_ID,KOUZA_NO,TORIHIKI_DT,TORIHIKI_KBN,KINGAKU,AITE_KOUZA,TESURYO,TEKIYOU)
  VALUES (100000000003,1000123,'20260801110000','3',10000,2000456,110,NULL);
INSERT INTO TORIHIKI (TORIHIKI_ID,KOUZA_NO,TORIHIKI_DT,TORIHIKI_KBN,KINGAKU,AITE_KOUZA,TESURYO,TEKIYOU)
  VALUES (100000000004,2000456,'20260801110000','1',10000,NULL,NULL,NULL);
INSERT INTO TORIHIKI (TORIHIKI_ID,KOUZA_NO,TORIHIKI_DT,TORIHIKI_KBN,KINGAKU,AITE_KOUZA,TESURYO,TEKIYOU)
  VALUES (100000000005,3000789,'20260801120000','2',4000,NULL,NULL,NULL);
INSERT INTO TORIHIKI (TORIHIKI_ID,KOUZA_NO,TORIHIKI_DT,TORIHIKI_KBN,KINGAKU,AITE_KOUZA,TESURYO,TEKIYOU)
  VALUES (100000000006,1001011,'20260801130000','1',20000,NULL,NULL,NULL);
INSERT INTO TORIHIKI (TORIHIKI_ID,KOUZA_NO,TORIHIKI_DT,TORIHIKI_KBN,KINGAKU,AITE_KOUZA,TESURYO,TEKIYOU)
  VALUES (100000000007,4001213,'20260801140000','3',1000,3000789,110,NULL);
INSERT INTO TORIHIKI (TORIHIKI_ID,KOUZA_NO,TORIHIKI_DT,TORIHIKI_KBN,KINGAKU,AITE_KOUZA,TESURYO,TEKIYOU)
  VALUES (100000000008,5001415,'20260801150000','1',20000,NULL,NULL,NULL);

-- ------------------------------------------------------------
-- 5) 採番シーケンスを固定値の次へ戻す(繰り返し実行で同一結果にする)
-- ------------------------------------------------------------
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE SEQ_TORIHIKI';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
CREATE SEQUENCE SEQ_TORIHIKI START WITH 100000000009 INCREMENT BY 1 NOCACHE;

BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE SEQ_RECEIPT_ASIS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
CREATE SEQUENCE SEQ_RECEIPT_ASIS START WITH 10251 INCREMENT BY 1 NOCACHE;

BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE SEQ_KOUZA_DYN';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
CREATE SEQUENCE SEQ_KOUZA_DYN START WITH 9000001 INCREMENT BY 1 NOCACHE;

COMMIT;

SET FEEDBACK ON

PROMPT === fixture applied (KOUZA=8 / TORIHIKI=8) ===
SELECT KOUZA_NO, SHUBETSU, JOUTAI, ZANDAKA FROM KOUZA ORDER BY KOUZA_NO;
SELECT COUNT(*) AS TORIHIKI_CNT FROM TORIHIKI;
