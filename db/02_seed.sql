-- ============================================================
--  KS銀行 ミニバンク デモ  -  初期データ (Seed)
--  app.js の buildAccounts()/buildJournal()/dict().notices を移植
--  実行前提: 01_schema.sql 実行済み
-- ============================================================

-- ------------------------------------------------------------
-- 口座種別マスタ  (RATE_BY_TYPE, typeMap)
-- ------------------------------------------------------------
INSERT INTO ACCOUNT_TYPE (type_code, name_ja, name_ko, interest_rate) VALUES (N'普通', N'普通預金', N'보통예금', 0.20);
INSERT INTO ACCOUNT_TYPE (type_code, name_ja, name_ko, interest_rate) VALUES (N'当座', N'当座預金', N'당좌예금', 0.05);
INSERT INTO ACCOUNT_TYPE (type_code, name_ja, name_ko, interest_rate) VALUES (N'積立', N'積立定期', N'적금',     0.30);
INSERT INTO ACCOUNT_TYPE (type_code, name_ja, name_ko, interest_rate) VALUES (N'定期', N'定期預金', N'정기예금', 0.35);

-- ------------------------------------------------------------
-- 店舗(店番)マスタ  (STORES)
-- ------------------------------------------------------------
INSERT INTO BRANCH (branch_code, name_ja) VALUES ('001', N'東京営業部');
INSERT INTO BRANCH (branch_code, name_ja) VALUES ('002', N'新宿支店');
INSERT INTO BRANCH (branch_code, name_ja) VALUES ('003', N'渋谷支店');
INSERT INTO BRANCH (branch_code, name_ja) VALUES ('004', N'横浜支店');
INSERT INTO BRANCH (branch_code, name_ja) VALUES ('005', N'大阪支店');
INSERT INTO BRANCH (branch_code, name_ja) VALUES ('006', N'名古屋支店');

-- ------------------------------------------------------------
-- 金融機関マスタ  (BANKS, BANK_META)
-- ------------------------------------------------------------
INSERT INTO BANK (bank_id, name, color, text_color, mark) VALUES (1,  N'KS銀行',          '#ffcc00', '#1a3a6b', N'KS');
INSERT INTO BANK (bank_id, name, color, text_color, mark) VALUES (2,  N'みずほ銀行',      '#1a3f7a', '#fff',    N'み');
INSERT INTO BANK (bank_id, name, color, text_color, mark) VALUES (3,  N'三菱UFJ銀行',     '#d0021b', '#fff',    N'三');
INSERT INTO BANK (bank_id, name, color, text_color, mark) VALUES (4,  N'三井住友銀行',    '#00913a', '#fff',    N'SM');
INSERT INTO BANK (bank_id, name, color, text_color, mark) VALUES (5,  N'ゆうちょ銀行',    '#e60012', '#fff',    N'ゆ');
INSERT INTO BANK (bank_id, name, color, text_color, mark) VALUES (6,  N'りそな銀行',      '#f08300', '#fff',    N'り');
INSERT INTO BANK (bank_id, name, color, text_color, mark) VALUES (7,  N'楽天銀行',        '#bf0000', '#fff',    N'R');
INSERT INTO BANK (bank_id, name, color, text_color, mark) VALUES (8,  N'PayPay銀行',      '#ff0033', '#fff',    N'PP');
INSERT INTO BANK (bank_id, name, color, text_color, mark) VALUES (9,  N'住信SBIネット銀行','#0068b7', '#fff',    N'SBI');
INSERT INTO BANK (bank_id, name, color, text_color, mark) VALUES (10, N'イオン銀行',      '#e5007f', '#fff',    N'イ');

-- ------------------------------------------------------------
-- 顧客 + 口座  (デモ用途に合わせて 2 アカウントのみ)
--   1) 시연용(デモ表示用): 山田太郎 / 明細に 100 件の取引を投入
--   2) 테스트용(テスト用): 残高 10,000,000円 のみ・取引なし(明細は空)
-- ------------------------------------------------------------
-- 1) 시연용 계정  (店番 001 / 口座 1000123 / PW ks1234)
INSERT INTO CUSTOMER (customer_id, kanji, kana, birth, sex, zip, addr, phone, email, job)
VALUES (1, N'山田太郎', N'ヤマダタロウ', '1985/04/12', N'男性', '1000001', N'東京都千代田区丸の内1-1-1', '090-1234-5678', 'taro.yamada@example.jp', N'会社員');
INSERT INTO ACCOUNT (acct_no, customer_id, type_code, branch_code, balance, status, password, is_primary)
VALUES ('1000123', 1, N'普通', '001', 0, N'正常', 'ks1234', 'Y');   -- balance は 100 件投入後に自動再計算

-- 2) 테스트용 계정  (店番 001 / 口座 9000001 / PW test1234)
INSERT INTO CUSTOMER (customer_id, kanji, kana, email, job)
VALUES (2, N'テスト太郎', N'テストタロウ', 'test@example.jp', N'テスト');
INSERT INTO ACCOUNT (acct_no, customer_id, type_code, branch_code, balance, status, password)
VALUES ('9000001', 2, N'普通', '001', 10000000, N'正常', 'test1234');  -- 시작금액 천만엔만, 나머지 비움

-- ------------------------------------------------------------
-- 取引明細  (시연용 계정 1000123 に 100 件を自動生成)
--   ・約 6か月(2026-01-06 〜 2026-07-03)に分散
--   ・14 種類のパターンを循環させて内容を充填
--   ・投入後、残高不足にならないよう opening を算出し
--     ACCOUNT.balance と各 TXN.balance_after を再計算
-- ------------------------------------------------------------
DECLARE
  TYPE t_txt IS TABLE OF NVARCHAR2(120) INDEX BY PLS_INTEGER;
  TYPE t_num IS TABLE OF NUMBER          INDEX BY PLS_INTEGER;
  v_type  t_txt;  v_ja t_txt;  v_ko t_txt;  v_base t_num;
  P        PLS_INTEGER := 14;          -- パターン数
  p        PLS_INTEGER;
  v_date   DATE;
  v_amount NUMBER;
  v_total  NUMBER := 0;                -- Σ(sign * amount)
  v_min    NUMBER := 0;                -- 累計の最小値(マイナスなら opening で補填)
  v_open   NUMBER;                     -- 期首(先頭取引の前)残高
BEGIN
  -- 取引パターン定義 (種別 / 摘要日 / 摘要韓 / 基準額)
  v_type(1):=N'入金';  v_ja(1):=N'給与振込';       v_ko(1):=N'급여이체';        v_base(1):=250000;
  v_type(2):=N'出金';  v_ja(2):=N'ATM出金';        v_ko(2):=N'ATM 출금';        v_base(2):=30000;
  v_type(3):=N'出金';  v_ja(3):=N'公共料金';       v_ko(3):=N'공과금';          v_base(3):=12000;
  v_type(4):=N'振込';  v_ja(4):=N'佐藤花子へ振込'; v_ko(4):=N'佐藤花子에게 이체'; v_base(4):=40000;
  v_type(5):=N'手数料';v_ja(5):=N'振込手数料';     v_ko(5):=N'이체 수수료';     v_base(5):=110;
  v_type(6):=N'入金';  v_ja(6):=N'利息';           v_ko(6):=N'이자';            v_base(6):=1500;
  v_type(7):=N'出金';  v_ja(7):=N'クレジット引落'; v_ko(7):=N'카드 대금';       v_base(7):=45000;
  v_type(8):=N'出金';  v_ja(8):=N'家賃';           v_ko(8):=N'집세';            v_base(8):=95000;
  v_type(9):=N'入金';  v_ja(9):=N'現金入金';       v_ko(9):=N'현금 입금';       v_base(9):=50000;
  v_type(10):=N'出金'; v_ja(10):=N'携帯料金';      v_ko(10):=N'휴대폰 요금';    v_base(10):=8800;
  v_type(11):=N'入金'; v_ja(11):=N'ボーナス';      v_ko(11):=N'보너스';         v_base(11):=300000;
  v_type(12):=N'出金'; v_ja(12):=N'保険料';        v_ko(12):=N'보험료';         v_base(12):=15000;
  v_type(13):=N'出金'; v_ja(13):=N'光熱費';        v_ko(13):=N'광열비';         v_base(13):=18000;
  v_type(14):=N'入金'; v_ja(14):=N'配当金';        v_ko(14):=N'배당금';         v_base(14):=22000;

  FOR i IN 1 .. 100 LOOP
    p := MOD(i - 1, P) + 1;
    -- 手数料は固定額、それ以外は決定論的に少額変動 (100円単位)
    IF p = 5 THEN v_amount := v_base(5);
    ELSE          v_amount := v_base(p) + MOD(i, 6) * 500;
    END IF;
    -- 2026-01-06 〜 2026-07-03 に均等分散
    v_date := DATE '2026-01-06' + FLOOR((i - 1) * 178 / 99);

    INSERT INTO TXN (txn_id, acct_no, txn_date, txn_type, amount, memo_ja, memo_ko)
    VALUES (SEQ_TXN.NEXTVAL, '1000123', v_date, v_type(p), v_amount, v_ja(p), v_ko(p));
  END LOOP;

  -- 合計デルタと累計最小値を算出
  SELECT NVL(SUM(signed), 0),
         NVL(MIN(SUM(signed) OVER (ORDER BY txn_date, txn_id)), 0)
    INTO v_total, v_min
    FROM ( SELECT txn_id, txn_date,
                  CASE WHEN txn_type IN (N'入金', N'融資実行') THEN amount ELSE -amount END AS signed
             FROM TXN WHERE acct_no = '1000123' );

  -- 全期間で残高が 0 未満にならない期首残高(余裕 10万円)
  v_open := GREATEST(100000, CASE WHEN v_min < 0 THEN -v_min ELSE 0 END + 100000);

  -- 現在残高 = 期首 + Σデルタ
  UPDATE ACCOUNT SET balance = v_open + v_total WHERE acct_no = '1000123';

  -- 各明細の取引後残高を確定
  MERGE INTO TXN t
  USING ( SELECT txn_id,
                 v_open + SUM(signed) OVER (ORDER BY txn_date, txn_id) AS ba
            FROM ( SELECT txn_id, txn_date,
                          CASE WHEN txn_type IN (N'入金', N'融資実行') THEN amount ELSE -amount END AS signed
                     FROM TXN WHERE acct_no = '1000123' ) ) s
     ON (t.txn_id = s.txn_id)
   WHEN MATCHED THEN UPDATE SET t.balance_after = s.ba;
END;
/

-- ------------------------------------------------------------
-- お知らせ  (dict().ja.notices  日本語を掲載データとして採用)
-- ------------------------------------------------------------
INSERT INTO NOTICE (notice_id, notice_date, tag, title) VALUES (SEQ_NOTICE.NEXTVAL, DATE '2026-07-01', N'メンテナンス', N'システムメンテナンスのお知らせ（7/15 2:00〜5:00 は一時ご利用いただけません）');
INSERT INTO NOTICE (notice_id, notice_date, tag, title) VALUES (SEQ_NOTICE.NEXTVAL, DATE '2026-06-28', N'重要',         N'振込手数料改定に関するご案内（2026年8月1日〜）');
INSERT INTO NOTICE (notice_id, notice_date, tag, title) VALUES (SEQ_NOTICE.NEXTVAL, DATE '2026-06-20', N'セキュリティ', N'フィッシング詐欺にご注意ください。当行が暗証番号をメールでお尋ねすることはありません。');

COMMIT;
