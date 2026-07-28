-- ============================================================
--  ASIS (レガシー) Oracle DDL  -  KS銀行 ミニバンク・デモ
--  設計書 §3 準拠。COBOL COMP-3 <-> NUMBER, EBCDIC(CP930) <-> RAW 無変換。
--
--  ★ 本スキーマは ASIS 正本(TORIHIKI/KOUZA)。
--    frontend を RDB 正規化した db/01_schema.sql(TOBE寄り/UTF-8)とは別物。
--    日本語テキスト列(名義・摘要)は RAW に CP930 バイト原本を格納(§2)。
--    RAW の中身はデコードしない(原本のまま)。
--
--  実行順: 01_ddl.sql -> 02_seed.sql
-- ============================================================

-- gvenzl は initdb.d を SYSTEM で実行するため、明示的に minibank へ接続する。
-- (手動実行時: sqlplus minibank/minibank @01_ddl.sql でも再接続され無害)
CONNECT minibank/minibank@//localhost:1521/FREEPDB1

-- ------------------------------------------------------------
--  再実行できるよう既存オブジェクトを削除
-- ------------------------------------------------------------
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
            WHERE table_name IN (
              'TORIHIKI','KOUZA',
              'KOUZA_EXT','LOAN_ASIS','LOAN_REPAY_ASIS',
              'NOTICE_ASIS','NOTICE_FILE_ASIS','BANK_ASIS','BRANCH_ASIS'))
  LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
  END LOOP;
  FOR s IN (SELECT sequence_name FROM user_sequences
            WHERE sequence_name IN (
              'SEQ_KOUZA_DYN','SEQ_TORIHIKI','SEQ_LOAN_ASIS',
              'SEQ_REPAY_ASIS','SEQ_NOTICE_ASIS','SEQ_RECEIPT_ASIS'))
  LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
  END LOOP;
END;
/

-- ============================================================
--  §3.1  口座マスタ  KOUZA
--   名義は EBCDIC(CP930) の RAW。ZANDAKA は NUMBER(11)(COMP-3対応)。
-- ============================================================
CREATE TABLE KOUZA (
  KOUZA_NO      NUMBER(7)    NOT NULL,          -- PIC 9(7)  帯域体系
  MEIGI_KANJI   RAW(20)       NOT NULL,          -- PIC X(20)  SO/SI 込 20byte
  MEIGI_KANA    RAW(20)       NOT NULL,          -- PIC X(20)  ソートキー(EBCDIC順)
  SHUBETSU      CHAR(1)       NOT NULL,          -- 1=普通 2=当座
  ZANDAKA       NUMBER(11)    DEFAULT 0 NOT NULL,-- PIC S9(11) COMP-3
  KAISETSU_BI   CHAR(8)       NOT NULL,          -- YYYYMMDD
  JOUTAI        CHAR(1)       DEFAULT '0' NOT NULL, -- 0=正常 9=凍結
  CONSTRAINT PK_KOUZA        PRIMARY KEY (KOUZA_NO),
  CONSTRAINT CK_KOUZA_SHU    CHECK (SHUBETSU IN ('1','2')),
  CONSTRAINT CK_KOUZA_JOUTAI CHECK (JOUTAI  IN ('0','9'))
);
COMMENT ON TABLE  KOUZA             IS '口座マスタ(ASIS) 名義はCP930 RAW原本';
COMMENT ON COLUMN KOUZA.MEIGI_KANJI IS 'CP930 RAW原本(SO/SI込20byte, デコードしない)';
COMMENT ON COLUMN KOUZA.ZANDAKA     IS 'COBOL S9(11)COMP-3 と往復';

-- ============================================================
--  §3.2  取引ジャーナル  TORIHIKI
--   相手口座/手数料は振込(区分3)のときのみ充填(NULL可)。
--   摘要は EBCDIC(CP930) RAW(40)。
-- ============================================================
CREATE TABLE TORIHIKI (
  TORIHIKI_ID   NUMBER(12)    NOT NULL,          -- PIC 9(12) PK
  KOUZA_NO      NUMBER(7)    NOT NULL,          -- FK KOUZA
  TORIHIKI_DT   CHAR(14)      NOT NULL,          -- YYYYMMDDHHMMSS
  TORIHIKI_KBN  CHAR(1)       NOT NULL,          -- 1=入金 2=出金 3=振込
  KINGAKU       NUMBER(11)    NOT NULL,          -- PIC S9(11) COMP-3
  AITE_KOUZA    NUMBER(7),                      -- 振込のみ
  TESURYO       NUMBER(5),                       -- 振込のみ PIC S9(05) COMP-3
  TEKIYOU       RAW(40),                         -- CP930 RAW 漢字・カナ混在
  CONSTRAINT PK_TORIHIKI     PRIMARY KEY (TORIHIKI_ID),
  CONSTRAINT FK_TORIHIKI_KZ  FOREIGN KEY (KOUZA_NO) REFERENCES KOUZA(KOUZA_NO),
  CONSTRAINT CK_TORIHIKI_KBN CHECK (TORIHIKI_KBN IN ('1','2','3'))
);
COMMENT ON TABLE TORIHIKI IS '取引ジャーナル(ASIS) 摘要はCP930 RAW原本';
CREATE INDEX IX_TORIHIKI_KZ_DT ON TORIHIKI (KOUZA_NO, TORIHIKI_DT);

-- ============================================================
--  拡張機能用の補助テーブル(フロント全機能カバー)
--   ※ ここは 決定打(EBCDIC/COMP-3)対象外。可読性優先で通常型(UTF-8)。
--     名義参照は KOUZA.KOUZA_NO を辿る(名義原本は KOUZA 側 RAW が正)。
-- ============================================================

-- 口座の付帯情報(ログインPW/店番/種別表示名/代表フラグ/積立情報/プロフィール)
CREATE TABLE KOUZA_EXT (
  KOUZA_NO      NUMBER(7)    NOT NULL,          -- FK KOUZA (1:1)
  BRANCH_CODE   VARCHAR2(3)   NOT NULL,          -- 店番3桁(ログイン)
  ACCT_TYPE     VARCHAR2(6)   NOT NULL,          -- 普通/当座/積立/定期(表示種別)
  PASSWORD      VARCHAR2(60),                    -- デモ:平文。実運用はハッシュ
  IS_PRIMARY    CHAR(1)       DEFAULT 'N' NOT NULL,
  SAVE_TERM     NUMBER(4),                       -- 積立/定期の期間(ヶ月)
  SAVE_MONTHLY  NUMBER(15),                      -- 積立の月々額
  KANJI_UTF8    NVARCHAR2(60),                   -- 名義(漢字)UTF-8 表示用ミラー
  KANA_UTF8     NVARCHAR2(60),                   -- 名義(カナ)UTF-8 表示用ミラー
  BIRTH         VARCHAR2(10),
  SEX           NVARCHAR2(6),
  ZIP           VARCHAR2(7),
  ADDR          NVARCHAR2(200),
  PHONE         VARCHAR2(13),
  EMAIL         VARCHAR2(120),
  JOB           NVARCHAR2(40),
  CONSTRAINT PK_KOUZA_EXT PRIMARY KEY (KOUZA_NO),
  CONSTRAINT FK_KOUZA_EXT FOREIGN KEY (KOUZA_NO) REFERENCES KOUZA(KOUZA_NO),
  CONSTRAINT CK_KEXT_PRIM CHECK (IS_PRIMARY IN ('Y','N'))
);
COMMENT ON TABLE KOUZA_EXT IS '口座付帯情報(拡張機能)。名義UTF8はKOUZA RAWのミラー';

-- ローン契約  (frontend: loans[])
CREATE TABLE LOAN_ASIS (
  LOAN_ID       NUMBER(12)    NOT NULL,
  KOUZA_NO      NUMBER(7)    NOT NULL,          -- 入金/返済元口座
  PRINCIPAL     NUMBER(15)    NOT NULL,          -- 借入総額
  BALANCE       NUMBER(15)    NOT NULL,          -- 借入残高
  METHOD        CHAR(1)       NOT NULL,          -- A/B/C
  TERM_YEARS    NUMBER(3)     NOT NULL,
  RATE          NUMBER(5,3)   DEFAULT 2.5 NOT NULL,
  OPENED_DATE   DATE          DEFAULT TRUNC(SYSDATE) NOT NULL,
  CLOSED_DATE   DATE,
  STATUS        VARCHAR2(10)  DEFAULT 'ACTIVE' NOT NULL,
  CONSTRAINT PK_LOAN_ASIS   PRIMARY KEY (LOAN_ID),
  CONSTRAINT FK_LOAN_ASIS   FOREIGN KEY (KOUZA_NO) REFERENCES KOUZA(KOUZA_NO),
  CONSTRAINT CK_LOAN_METHOD CHECK (METHOD IN ('A','B','C')),
  CONSTRAINT CK_LOAN_STATUS CHECK (STATUS IN ('ACTIVE','CLOSED'))
);
CREATE INDEX IX_LOAN_ASIS_KZ ON LOAN_ASIS (KOUZA_NO);

CREATE TABLE LOAN_REPAY_ASIS (
  REPAY_ID      NUMBER(15)    NOT NULL,
  LOAN_ID       NUMBER(12)    NOT NULL,
  REPAY_DATE    DATE          DEFAULT TRUNC(SYSDATE) NOT NULL,
  PRINCIPAL     NUMBER(15)    NOT NULL,
  INTEREST      NUMBER(15)    DEFAULT 0 NOT NULL,
  FEE           NUMBER(15)    DEFAULT 0 NOT NULL, -- REPAY_FEE=550
  TOTAL         NUMBER(15)    NOT NULL,
  RECEIPT_NO    VARCHAR2(30),
  CONSTRAINT PK_REPAY_ASIS PRIMARY KEY (REPAY_ID),
  CONSTRAINT FK_REPAY_ASIS FOREIGN KEY (LOAN_ID) REFERENCES LOAN_ASIS(LOAN_ID)
);
CREATE INDEX IX_REPAY_ASIS_LN ON LOAN_REPAY_ASIS (LOAN_ID);

-- お知らせ
CREATE TABLE NOTICE_ASIS (
  NOTICE_ID     NUMBER(12)    NOT NULL,
  NOTICE_DATE   DATE          NOT NULL,
  TAG           NVARCHAR2(20),
  TITLE         NVARCHAR2(200) NOT NULL,
  BODY          NVARCHAR2(1000),
  IS_ACTIVE     CHAR(1)       DEFAULT 'Y' NOT NULL,
  CONSTRAINT PK_NOTICE_ASIS PRIMARY KEY (NOTICE_ID),
  CONSTRAINT CK_NOTICE_ACT  CHECK (IS_ACTIVE IN ('Y','N'))
);

CREATE TABLE NOTICE_FILE_ASIS (
  FILE_ID       NUMBER(15)    NOT NULL,
  NOTICE_ID     NUMBER(12)    NOT NULL,
  FILE_NAME     NVARCHAR2(260) NOT NULL,
  CONSTRAINT PK_NOTICE_FILE_ASIS PRIMARY KEY (FILE_ID),
  CONSTRAINT FK_NOTICE_FILE_ASIS FOREIGN KEY (NOTICE_ID)
      REFERENCES NOTICE_ASIS(NOTICE_ID) ON DELETE CASCADE
);

-- 自行店舗(店番)マスタ  frontend: STORES
CREATE TABLE BRANCH_ASIS (
  BRANCH_CODE   VARCHAR2(3)   NOT NULL,
  NAME_JA       NVARCHAR2(40) NOT NULL,
  CONSTRAINT PK_BRANCH_ASIS PRIMARY KEY (BRANCH_CODE)
);

-- 振込先金融機関マスタ  frontend: BANKS/BANK_META
CREATE TABLE BANK_ASIS (
  BANK_ID       NUMBER(4)     NOT NULL,
  NAME          NVARCHAR2(40) NOT NULL,
  COLOR         VARCHAR2(9),
  TEXT_COLOR    VARCHAR2(9),
  MARK          NVARCHAR2(4),
  CONSTRAINT PK_BANK_ASIS PRIMARY KEY (BANK_ID),
  CONSTRAINT UQ_BANK_ASIS UNIQUE (NAME)
);

-- ============================================================
--  シーケンス
--   ※ 行末インラインコメント(; の後ろ)は SQL*Plus の文バッファリングを
--     壊し ORA-03405 で後続 CREATE を巻き込むため、コメントは行上に置く。
-- ============================================================
-- 動的口座帯域(§3.3) 7桁: 9000001~(新規開設。既存の店番先頭1-6と衝突しない9帯)
CREATE SEQUENCE SEQ_KOUZA_DYN    START WITH 9000001       INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_TORIHIKI     START WITH 100000000001  INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_LOAN_ASIS    START WITH 1             INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_REPAY_ASIS   START WITH 1             INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_NOTICE_ASIS  START WITH 1             INCREMENT BY 1 NOCACHE;
-- 受付番号 rSeq(初期 10247)
CREATE SEQUENCE SEQ_RECEIPT_ASIS START WITH 10247         INCREMENT BY 1 NOCACHE;

COMMIT;
