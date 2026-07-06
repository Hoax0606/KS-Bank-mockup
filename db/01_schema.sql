-- ============================================================
--  KS銀行 ミニバンク デモ  -  Oracle スキーマ定義 (DDL)
--  KS은행 미니뱅크 데모  -  오라클 스키마 정의
--
--  app.js のインメモリ・データモデルを RDB へ正規化したもの。
--  文字コード: 日本語/韓国語を扱うため DB は AL32UTF8 を推奨。
--  実行順: 本ファイル → 02_seed.sql
-- ============================================================

-- ------------------------------------------------------------
-- 依存を考慮して既存オブジェクトを削除(再実行できるように)
-- ------------------------------------------------------------
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
            WHERE table_name IN (
              'NOTICE_FILE','NOTICE','LOAN_REPAYMENT','LOAN',
              'TXN','ACCOUNT','CUSTOMER','BANK','BRANCH','ACCOUNT_TYPE'))
  LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
  END LOOP;
  FOR s IN (SELECT sequence_name FROM user_sequences
            WHERE sequence_name IN (
              'SEQ_CUSTOMER','SEQ_TXN','SEQ_LOAN','SEQ_REPAY',
              'SEQ_NOTICE','SEQ_NOTICE_FILE','SEQ_RECEIPT'))
  LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
  END LOOP;
END;
/

-- ============================================================
--  参照(マスタ)テーブル
-- ============================================================

-- 口座種別マスタ (普通/当座/積立/定期) と デモ用の適用金利
--  app.js: RATE_BY_TYPE, typeMap
CREATE TABLE ACCOUNT_TYPE (
  type_code     VARCHAR2(10)   NOT NULL,          -- '普通' '当座' '積立' '定期'
  name_ja       NVARCHAR2(30)  NOT NULL,          -- 普通預金 など
  name_ko       NVARCHAR2(30)  NOT NULL,          -- 보통예금 など
  interest_rate NUMBER(5,2)    DEFAULT 0 NOT NULL,-- 年利(%) デモ固定値
  CONSTRAINT pk_account_type PRIMARY KEY (type_code)
);
COMMENT ON TABLE  ACCOUNT_TYPE               IS '口座種別マスタ / 계좌종별 마스터';
COMMENT ON COLUMN ACCOUNT_TYPE.interest_rate IS '適用金利(年,%) デモ固定値';

-- 自行の取扱店舗(店番)マスタ  app.js: STORES / BRANCHES2
CREATE TABLE BRANCH (
  branch_code   VARCHAR2(3)    NOT NULL,          -- '001' 等 店番3桁
  name_ja       NVARCHAR2(40)  NOT NULL,
  CONSTRAINT pk_branch PRIMARY KEY (branch_code)
);
COMMENT ON TABLE BRANCH IS '自行の店舗(店番)マスタ / 자행 점포 마스터';

-- 振込先となる金融機関マスタ  app.js: BANKS, BANK_META
CREATE TABLE BANK (
  bank_id       NUMBER(4)      NOT NULL,
  name          NVARCHAR2(40)  NOT NULL,          -- 'KS銀行' 等
  color         VARCHAR2(9),                      -- BANK_META.c ロゴ背景色
  text_color    VARCHAR2(9),                      -- BANK_META.t ロゴ文字色
  mark          NVARCHAR2(4),                     -- BANK_META.m 略号
  CONSTRAINT pk_bank      PRIMARY KEY (bank_id),
  CONSTRAINT uq_bank_name UNIQUE (name)
);
COMMENT ON TABLE BANK IS '振込先金融機関マスタ / 이체 대상 금융기관 마스터';

-- ============================================================
--  顧客 / 口座
-- ============================================================

-- 顧客(名義人)  app.js: account.kanji/kana + account.prof
CREATE TABLE CUSTOMER (
  customer_id   NUMBER(12)     NOT NULL,
  kanji         NVARCHAR2(60)  NOT NULL,          -- お名前(漢字)
  kana          NVARCHAR2(60),                    -- お名前(カナ)
  birth         VARCHAR2(10),                     -- 'YYYY/MM/DD'
  sex           NVARCHAR2(6),                     -- 男性/女性/その他
  zip           VARCHAR2(7),                      -- 郵便番号(数字のみ)
  addr          NVARCHAR2(200),                   -- 住所
  phone         VARCHAR2(13),                     -- 電話番号
  email         VARCHAR2(120),                    -- メールアドレス
  job           NVARCHAR2(40),                    -- ご職業
  created_at    TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_customer PRIMARY KEY (customer_id),
  CONSTRAINT ck_customer_sex CHECK (sex IN (N'男性', N'女性', N'その他') OR sex IS NULL)
);
COMMENT ON TABLE CUSTOMER IS '顧客(名義人) / 고객(명의인)';

-- 口座  app.js: buildAccounts()
CREATE TABLE ACCOUNT (
  acct_no       VARCHAR2(7)    NOT NULL,          -- 口座番号7桁
  customer_id   NUMBER(12)     NOT NULL,
  type_code     VARCHAR2(10)   NOT NULL,          -- FK ACCOUNT_TYPE
  branch_code   VARCHAR2(3)    NOT NULL,          -- FK BRANCH (bcode)
  balance       NUMBER(15)     DEFAULT 0  NOT NULL,-- 残高(円,整数)
  status        NVARCHAR2(6)   DEFAULT N'正常' NOT NULL, -- 正常/凍結
  password      VARCHAR2(60),                     -- ログインPW(デモ: 平文。実運用はハッシュ)
  is_primary    CHAR(1)        DEFAULT 'N' NOT NULL, -- 代表口座か  app.js: repAcct
  save_term     NUMBER(4),                        -- 積立/定期の期間(ヶ月)  app.js: saveTerm
  save_monthly  NUMBER(15),                       -- 積立の月々額         app.js: saveMonthly
  opened_at     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_account          PRIMARY KEY (acct_no),
  CONSTRAINT fk_account_customer FOREIGN KEY (customer_id) REFERENCES CUSTOMER(customer_id),
  CONSTRAINT fk_account_type     FOREIGN KEY (type_code)   REFERENCES ACCOUNT_TYPE(type_code),
  CONSTRAINT fk_account_branch   FOREIGN KEY (branch_code) REFERENCES BRANCH(branch_code),
  CONSTRAINT ck_account_status   CHECK (status IN (N'正常', N'凍結')),
  CONSTRAINT ck_account_primary  CHECK (is_primary IN ('Y','N'))
);
COMMENT ON TABLE  ACCOUNT            IS '口座 / 계좌';
COMMENT ON COLUMN ACCOUNT.is_primary IS '代表口座フラグ Y/N';
CREATE INDEX ix_account_customer ON ACCOUNT (customer_id);
CREATE INDEX ix_account_branch   ON ACCOUNT (branch_code);

-- ============================================================
--  取引 (journal)
-- ============================================================

-- 取引明細  app.js: buildJournal()
CREATE TABLE TXN (
  txn_id        NUMBER(15)     NOT NULL,
  acct_no       VARCHAR2(7)    NOT NULL,          -- FK ACCOUNT
  txn_date      DATE           NOT NULL,          -- お取引日
  txn_type      VARCHAR2(10)   NOT NULL,          -- 入金/出金/振込/手数料/融資実行/融資返済
  amount        NUMBER(15)     NOT NULL,          -- 金額(円,正の数)
  memo_ja       NVARCHAR2(120),                   -- 摘要(日本語)
  memo_ko       NVARCHAR2(120),                   -- 摘要(韓国語)
  balance_after NUMBER(15),                       -- 取引後残高(任意で保持)
  receipt_no    VARCHAR2(30),                     -- 受付番号(WEB.../DEP.../LOAN...)
  created_at    TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_txn      PRIMARY KEY (txn_id),
  CONSTRAINT fk_txn_acct FOREIGN KEY (acct_no) REFERENCES ACCOUNT(acct_no),
  CONSTRAINT ck_txn_type CHECK (txn_type IN (N'入金', N'出金', N'振込', N'手数料', N'融資実行', N'融資返済')),
  CONSTRAINT ck_txn_amt  CHECK (amount >= 0)
);
COMMENT ON TABLE TXN IS '取引明細(元帳) / 거래명세';
CREATE INDEX ix_txn_acct_date ON TXN (acct_no, txn_date);

-- ============================================================
--  ローン
-- ============================================================

-- ローン契約  app.js: loans[] / loanHistory[]
CREATE TABLE LOAN (
  loan_id       NUMBER(12)     NOT NULL,
  acct_no       VARCHAR2(7)    NOT NULL,          -- 入金/返済元 口座 FK  app.js: loan.acct
  principal     NUMBER(15)     NOT NULL,          -- 借入総額         app.js: loan.amt
  balance       NUMBER(15)     NOT NULL,          -- 借入残高         app.js: loan.bal
  method        CHAR(1)        NOT NULL,          -- A:元利均等 B:元金均等 C:満期一括
  term_years    NUMBER(3)      NOT NULL,          -- 返済期間(年)     app.js: loan.years
  rate          NUMBER(5,3)    DEFAULT 2.5 NOT NULL, -- 年利(%) app.js: LOAN_RATE
  opened_date   DATE           DEFAULT TRUNC(SYSDATE) NOT NULL, -- 実行日 app.js: loan.date
  closed_date   DATE,                             -- 完済日  app.js: loanHistory.closedDate
  status        VARCHAR2(10)   DEFAULT 'ACTIVE' NOT NULL, -- ACTIVE / CLOSED
  CONSTRAINT pk_loan       PRIMARY KEY (loan_id),
  CONSTRAINT fk_loan_acct  FOREIGN KEY (acct_no) REFERENCES ACCOUNT(acct_no),
  CONSTRAINT ck_loan_method CHECK (method IN ('A','B','C')),
  CONSTRAINT ck_loan_status CHECK (status IN ('ACTIVE','CLOSED'))
);
COMMENT ON TABLE  LOAN        IS 'ローン契約 / 대출계약';
COMMENT ON COLUMN LOAN.method IS 'A=元利均等 B=元金均等 C=満期一括';
CREATE INDEX ix_loan_acct ON LOAN (acct_no);

-- ローン返済履歴  app.js: loanRepayExecute()
CREATE TABLE LOAN_REPAYMENT (
  repay_id      NUMBER(15)     NOT NULL,
  loan_id       NUMBER(12)     NOT NULL,          -- FK LOAN
  repay_date    DATE           DEFAULT TRUNC(SYSDATE) NOT NULL,
  principal     NUMBER(15)     NOT NULL,          -- 返済元金
  interest      NUMBER(15)     DEFAULT 0 NOT NULL,-- 経過利息
  fee           NUMBER(15)     DEFAULT 0 NOT NULL,-- 中途返済手数料(REPAY_FEE=550)
  total         NUMBER(15)     NOT NULL,          -- お引落し合計
  receipt_no    VARCHAR2(30),                     -- 受付番号(REPAY...)
  created_at    TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_repay      PRIMARY KEY (repay_id),
  CONSTRAINT fk_repay_loan FOREIGN KEY (loan_id) REFERENCES LOAN(loan_id)
);
COMMENT ON TABLE LOAN_REPAYMENT IS 'ローン返済履歴 / 대출 상환 이력';
CREATE INDEX ix_repay_loan ON LOAN_REPAYMENT (loan_id);

-- ============================================================
--  お知らせ (notices)
-- ============================================================

CREATE TABLE NOTICE (
  notice_id     NUMBER(12)     NOT NULL,
  notice_date   DATE           NOT NULL,          -- 掲載日
  tag           NVARCHAR2(20),                    -- メンテナンス/重要/セキュリティ/新着 等
  title         NVARCHAR2(200) NOT NULL,
  body          NCLOB,                            -- 本文(任意)
  is_active     CHAR(1)        DEFAULT 'Y' NOT NULL, -- 表示中か(論理削除 app.js: hiddenBase)
  created_at    TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_notice        PRIMARY KEY (notice_id),
  CONSTRAINT ck_notice_active CHECK (is_active IN ('Y','N'))
);
COMMENT ON TABLE NOTICE IS 'お知らせ / 공지사항';

-- お知らせ添付ファイル  app.js: notice.files[]
CREATE TABLE NOTICE_FILE (
  file_id       NUMBER(15)     NOT NULL,
  notice_id     NUMBER(12)     NOT NULL,          -- FK NOTICE
  file_name     NVARCHAR2(260) NOT NULL,
  CONSTRAINT pk_notice_file      PRIMARY KEY (file_id),
  CONSTRAINT fk_notice_file_note FOREIGN KEY (notice_id) REFERENCES NOTICE(notice_id) ON DELETE CASCADE
);
COMMENT ON TABLE NOTICE_FILE IS 'お知らせ添付ファイル / 공지 첨부파일';
CREATE INDEX ix_notice_file ON NOTICE_FILE (notice_id);

-- ============================================================
--  シーケンス (採番)
-- ============================================================
CREATE SEQUENCE SEQ_CUSTOMER    START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_TXN         START WITH 1    INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_LOAN        START WITH 1    INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_REPAY       START WITH 1    INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_NOTICE      START WITH 1    INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_NOTICE_FILE START WITH 1    INCREMENT BY 1 NOCACHE;
-- 受付番号の連番  app.js: rSeq(初期値 10247)
CREATE SEQUENCE SEQ_RECEIPT     START WITH 10247 INCREMENT BY 1 NOCACHE;

COMMIT;
