-- ============================================================
--  ASIS シード投入  -  KS銀行 ミニバンク・デモ
--  実行順: 01_ddl.sql -> 02_seed.sql
--
--  gvenzl は initdb.d を SYSTEM で実行するため、明示的に minibank へ接続。
CONNECT minibank/minibank@//localhost:1521/FREEPDB1
--
--  ★ 名義(漢字/カナ)の CP930 RAW について ★
--    実運用の CP930(cp300 DBCS / IBM-290 SBCS)バイトは §8.5/§8.6 の
--    「チーム・エンコーダ」で確定する。本シードは未確定のため:
--      - KOUZA.MEIGI_KANJI : SO(0E)+プレースホルダDBCS+SI(0F) を
--        20byte 境界で切り詰め(結定打3を構造として再現)。
--      - KOUZA.MEIGI_KANA  : gojuon 昇順が EBCDIC バイト昇順になる
--        デモ用 SBCS バイト(結定打2 の SORT を確定的に再現)。
--      - 実際の日本語表記は KOUZA_EXT.KANJI_UTF8 / KANA_UTF8(UTF-8)
--        に保持し、オンライン表示はこのミラーを権威フォールバックとする。
--    → RAW原本(バッチ/現新比較)と 変換機構 を保ちつつ、デモは常に
--      正しく描画。エンコーダ確定後に KANA2EBC/KANJI2EBC を差替える。
-- ============================================================

-- ------------------------------------------------------------
--  デモ用エンコード関数(エンコーダ確定までの暫定)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION KANA2EBC(p IN NVARCHAR2) RETURN RAW IS
  v_ref NVARCHAR2(100) :=
    N'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン';
  v_src NVARCHAR2(60);
  v_out RAW(20);
  v_ch  NVARCHAR2(1);
  v_idx PLS_INTEGER;
  v_b   PLS_INTEGER;
BEGIN
  -- 濁音・半濁音は清音へ寄せる(デモ用)
  v_src := TRANSLATE(p,
    N'ガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポ',
    N'カキクケコサシスセソタチツテトハヒフヘホハヒフヘホ');
  v_out := UTL_RAW.CAST_TO_RAW('');
  FOR i IN 1 .. LEAST(NVL(LENGTH(v_src),0), 20) LOOP
    v_ch  := SUBSTR(v_src, i, 1);
    v_idx := INSTR(v_ref, v_ch);
    IF v_idx = 0 THEN v_b := 64; ELSE v_b := 65 + v_idx; END IF;  -- 0x41+idx
    v_out := UTL_RAW.CONCAT(v_out, UTL_RAW.SUBSTR(UTL_RAW.CAST_TO_RAW(CHR(v_b)), 1, 1));
  END LOOP;
  -- 20byte まで EBCDIC 空白(0x40)でパディング
  WHILE UTL_RAW.LENGTH(v_out) < 20 LOOP
    v_out := UTL_RAW.CONCAT(v_out, HEXTORAW('40'));
  END LOOP;
  RETURN UTL_RAW.SUBSTR(v_out, 1, 20);
END;
/

CREATE OR REPLACE FUNCTION KANJI2EBC(p IN NVARCHAR2) RETURN RAW IS
  v_out RAW(30);
  v_n   PLS_INTEGER;
  v_hi  PLS_INTEGER;
  v_lo  PLS_INTEGER;
BEGIN
  -- SO(0x0E) で DBCS 開始
  v_out := HEXTORAW('0E');
  v_n := NVL(LENGTH(p), 0);
  FOR i IN 1 .. v_n LOOP
    -- プレースホルダ DBCS 2byte(実バイトはエンコーダ確定後に差替)
    v_hi := 66 + MOD(i, 20);          -- 0x42..
    v_lo := 66 + MOD(i * 3, 20);
    v_out := UTL_RAW.CONCAT(v_out,
               UTL_RAW.CONCAT(UTL_RAW.SUBSTR(UTL_RAW.CAST_TO_RAW(CHR(v_hi)),1,1),
                              UTL_RAW.SUBSTR(UTL_RAW.CAST_TO_RAW(CHR(v_lo)),1,1)));
  END LOOP;
  -- SI(0x0F) で SBCS へ戻す
  v_out := UTL_RAW.CONCAT(v_out, HEXTORAW('0F'));
  -- 空白(0x40)パディング
  WHILE UTL_RAW.LENGTH(v_out) < 20 LOOP
    v_out := UTL_RAW.CONCAT(v_out, HEXTORAW('40'));
  END LOOP;
  -- ★結定打3★ X(20) の 20byte 境界で切り詰め(SO/SI 含む)
  RETURN UTL_RAW.SUBSTR(v_out, 1, 20);
END;
/

-- ------------------------------------------------------------
--  マスタ: 店舗 / 振込先金融機関 / お知らせ
-- ------------------------------------------------------------
-- ★ frontend の実際の支店リスト(BRANCHES2)に一致させた店番マスタ。
--   同じ支店でも旧 STORES(001-006)とは別コード(例: 新宿=200)。
INSERT INTO BRANCH_ASIS VALUES ('001', N'東京営業部');
INSERT INTO BRANCH_ASIS VALUES ('100', N'丸の内支店');
INSERT INTO BRANCH_ASIS VALUES ('200', N'新宿支店');
INSERT INTO BRANCH_ASIS VALUES ('305', N'渋谷支店');
INSERT INTO BRANCH_ASIS VALUES ('040', N'横浜支店');
INSERT INTO BRANCH_ASIS VALUES ('210', N'大阪支店');
INSERT INTO BRANCH_ASIS VALUES ('500', N'名古屋支店');
INSERT INTO BRANCH_ASIS VALUES ('088', N'札幌支店');
INSERT INTO BRANCH_ASIS VALUES ('060', N'福岡支店');
INSERT INTO BRANCH_ASIS VALUES ('700', N'仙台支店');

INSERT INTO BANK_ASIS VALUES (1, N'KS銀行',       '#ffcc00','#1a3a6b', N'KS');
INSERT INTO BANK_ASIS VALUES (2, N'みずほ銀行',   '#1a3f7a','#fff',    N'み');
INSERT INTO BANK_ASIS VALUES (3, N'三菱UFJ銀行',  '#d0021b','#fff',    N'三');
INSERT INTO BANK_ASIS VALUES (4, N'三井住友銀行', '#00913a','#fff',    N'SM');
INSERT INTO BANK_ASIS VALUES (5, N'ゆうちょ銀行', '#e60012','#fff',    N'ゆ');

INSERT INTO NOTICE_ASIS (NOTICE_ID, NOTICE_DATE, TAG, TITLE, IS_ACTIVE)
  VALUES (SEQ_NOTICE_ASIS.NEXTVAL, DATE '2026-07-01', N'メンテナンス',
          N'システムメンテナンスのお知らせ（7/15 2:00〜5:00 は一時ご利用いただけません）', 'Y');
INSERT INTO NOTICE_ASIS (NOTICE_ID, NOTICE_DATE, TAG, TITLE, IS_ACTIVE)
  VALUES (SEQ_NOTICE_ASIS.NEXTVAL, DATE '2026-06-28', N'重要',
          N'振込手数料改定に関するご案内（2026年8月1日〜）', 'Y');
INSERT INTO NOTICE_ASIS (NOTICE_ID, NOTICE_DATE, TAG, TITLE, IS_ACTIVE)
  VALUES (SEQ_NOTICE_ASIS.NEXTVAL, DATE '2026-06-20', N'セキュリティ',
          N'フィッシング詐欺にご注意ください。', 'Y');

-- ------------------------------------------------------------
--  KOUZA(口座マスタ)  口座番号=7桁 / 店番=BRANCH_CODE 3桁(別カラム)
--  ★ frontend(app.js buildAccounts)の実データ8口座に一致させる。
--    口座番号7桁 + 店番3桁 + PW でログイン(店番/口座番号/PW)。
--    ログイン例: 店番 001 / 口座 1000123 / ks1234
--  KOUZA_EXT に UTF-8 ミラー/PW/店番/表示種別 を投入
-- ------------------------------------------------------------
-- 共通投入プロシージャ(RAW は KANJI2EBC/KANA2EBC で生成)
DECLARE
  PROCEDURE ADD_ACCT(
      p_no NUMBER, p_kanji NVARCHAR2, p_kana NVARCHAR2,
      p_shu CHAR, p_zan NUMBER, p_kaisetsu CHAR, p_joutai CHAR,
      p_branch VARCHAR2, p_type VARCHAR2, p_pw VARCHAR2, p_primary CHAR) IS
  BEGIN
    INSERT INTO KOUZA (KOUZA_NO, MEIGI_KANJI, MEIGI_KANA, SHUBETSU,
                       ZANDAKA, KAISETSU_BI, JOUTAI)
      VALUES (p_no, KANJI2EBC(p_kanji), KANA2EBC(p_kana), p_shu,
              p_zan, p_kaisetsu, p_joutai);
    INSERT INTO KOUZA_EXT (KOUZA_NO, BRANCH_CODE, ACCT_TYPE, PASSWORD,
                           IS_PRIMARY, KANJI_UTF8, KANA_UTF8)
      VALUES (p_no, p_branch, p_type, p_pw, p_primary, p_kanji, p_kana);
  END;
BEGIN
  -- === frontend buildAccounts と一致(口座7桁 / 店番3桁 / PW) ===
  --   ※ 元の決定打のうち「COMP-3最大値(99999999999)」「20byte名義切り詰め」は
  --     frontend の口座集合に無いため未投入。バッチ/エッジ検証が要るなら別途追加。
  -- 山田太郎: 代表口座・プロフィール有(ログイン例 001/1000123/ks1234)
  ADD_ACCT(1000123, N'山田太郎',   N'ヤマダタロウ',
           '1', 523400,  '20180415', '0', '001', N'普通', 'ks1234', 'Y');
  -- 佐藤花子
  ADD_ACCT(2000456, N'佐藤花子',   N'サトウハナコ',
           '1', 88250,   '20200501', '0', '200', N'普通', '1111',   'N');  -- 新宿支店
  -- 髙橋圭子: 普通・利息対象(決定打1) 1204000/365000=3円(切り捨て)
  ADD_ACCT(3000789, N'髙橋圭子',   N'タカハシケイコ',
           '1', 1204000, '20190610', '0', '305', N'普通', '1234',   'N');  -- 渋谷支店
  -- 鈴木一郎: 当座・無利息(決定打)
  ADD_ACCT(1001011, N'鈴木一郎',   N'スズキイチロウ',
           '2', 45000,   '20210101', '0', '001', N'当座', '1234',   'N');
  -- 田中美咲
  ADD_ACCT(4001213, N'田中美咲',   N'タナカミサキ',
           '1', 3000,    '20220301', '0', '040', N'普通', '1234',   'N');  -- 横浜支店
  -- 渡辺健: 凍結(JOUTAI=9, §8.4) ログイン拒否確認用
  ADD_ACCT(5001415, N'渡辺健',     N'ワタナベケン',
           '1', 670000,  '20200801', '9', '210', N'普通', '1234',   'N');  -- 大阪支店(凍結)
  -- 中村愛
  ADD_ACCT(6001617, N'中村愛',     N'ナカムラアイ',
           '1', 158900,  '20230501', '0', '500', N'普通', '1234',   'N');  -- 名古屋支店
  -- 小林大輔: 当座・無利息
  ADD_ACCT(1001819, N'小林大輔',   N'コバヤシダイスケ',
           '2', 920500,  '20210901', '0', '001', N'当座', '1234',   'N');
END;
/

-- 山田太郎(1000123)のプロフィール(frontend prof に一致)
UPDATE KOUZA_EXT
   SET BIRTH = '1985/04/12', SEX = N'男性', ZIP = '1000001',
       ADDR  = N'東京都千代田区丸の内1-1-1', PHONE = '090-1234-5678',
       EMAIL = 'taro.yamada@example.jp', JOB = N'会社員'
 WHERE KOUZA_NO = 1000123;

COMMIT;

-- ------------------------------------------------------------
--  確認クエリ(EBCDIC順の並びと RAW バイトを目視確認)
-- ------------------------------------------------------------
PROMPT === KANA EBCDIC 昇順(決定打2 の SORT 順) ===
SELECT KOUZA_NO,
       RAWTOHEX(MEIGI_KANA) AS KANA_HEX,
       (SELECT KANA_UTF8 FROM KOUZA_EXT X WHERE X.KOUZA_NO = K.KOUZA_NO) AS KANA
  FROM KOUZA K
 ORDER BY MEIGI_KANA;    -- RAW の昇順 = EBCDIC バイト昇順

PROMPT === KANJI RAW(SO/SI + 20byte 境界; 決定打3) ===
SELECT KOUZA_NO, LENGTHB(MEIGI_KANJI) AS BYTES,
       RAWTOHEX(MEIGI_KANJI) AS KANJI_HEX
  FROM KOUZA ORDER BY KOUZA_NO;
