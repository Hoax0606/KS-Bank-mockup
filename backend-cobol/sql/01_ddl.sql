-- ============================================================
--  ASIS Oracle DDL  -  KS銀行 ミニバンク・デモ  (Shift-JIS / 일반 타입)
--  ★ 변경(2026-07-30): 메인프레임 RAW(JEF/COMP-3/존10진) 폐기 →
--     텍스트=Shift-JIS VARCHAR2, 금액/키=NUMBER, 일자=CHAR(8) 로 정상화.
--     ※ DB 문자셋은 JA16SJIS 전제(컨테이너 생성 시 NLS_CHARACTERSET=JA16SJIS).
--       VARCHAR2에 일본어를 넣으면 디스크에 Shift-JIS로 저장됨.
--  실행순: 01_ddl.sql -> 02_seed.sql
-- ============================================================

-- gvenzl은 initdb.d를 SYSTEM으로 실행하므로 명시적으로 minibank에 접속.
CONNECT minibank/minibank@//localhost:1521/FREEPDB1

-- ------------------------------------------------------------
--  재실행 가능하도록 기존 오브젝트 제거 (RAW판 뷰/함수 포함)
-- ------------------------------------------------------------
BEGIN
  FOR v IN (SELECT view_name FROM user_views) LOOP
    EXECUTE IMMEDIATE 'DROP VIEW '||v.view_name;
  END LOOP;
  FOR t IN (SELECT table_name FROM user_tables) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE '||t.table_name||' CASCADE CONSTRAINTS PURGE';
  END LOOP;
  FOR s IN (SELECT sequence_name FROM user_sequences) LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE '||s.sequence_name;
  END LOOP;
  FOR f IN (SELECT object_name FROM user_objects WHERE object_type='FUNCTION') LOOP
    EXECUTE IMMEDIATE 'DROP FUNCTION '||f.object_name;
  END LOOP;
END;
/

-- ============================================================
--  口座マスタ  KOUZA
-- ============================================================
CREATE TABLE KOUZA (
  KOUZA_NO      NUMBER(7)      NOT NULL,          -- 口座番号 7桁
  MEIGI_KANJI   VARCHAR2(40)   NOT NULL,          -- 名義(漢字) Shift-JIS
  MEIGI_KANA    VARCHAR2(40)   NOT NULL,          -- 名義(カナ) Shift-JIS
  SHUBETSU      CHAR(1)        NOT NULL,          -- 1=普通 2=当座
  KAISETSU_BI   CHAR(8)        NOT NULL,          -- YYYYMMDD
  JOUTAI        CHAR(1)        DEFAULT '0' NOT NULL, -- 0=正常 9=凍結
  ZANDAKA       NUMBER(11)     DEFAULT 0 NOT NULL,
  CONSTRAINT PK_KOUZA     PRIMARY KEY (KOUZA_NO),
  CONSTRAINT CK_KOUZA_SHU CHECK (SHUBETSU IN ('1','2')),
  CONSTRAINT CK_KOUZA_JOU CHECK (JOUTAI  IN ('0','9'))
);

-- 口座付帯情報
CREATE TABLE KOUZA_EXT (
  KOUZA_NO      NUMBER(7)      NOT NULL,
  BRANCH_CODE   VARCHAR2(3)    NOT NULL,          -- 店番3桁
  ACCT_TYPE     VARCHAR2(20)   NOT NULL,          -- 普通/当座/積立/定期 (Shift-JIS)
  PASSWORD      VARCHAR2(60),                     -- 데모: 평문
  IS_PRIMARY    CHAR(1)        DEFAULT 'N' NOT NULL,
  SAVE_TERM     NUMBER(4),
  SAVE_MONTHLY  NUMBER(15),
  BIRTH         VARCHAR2(10),
  SEX           VARCHAR2(6),
  ZIP           VARCHAR2(7),
  ADDR          VARCHAR2(200),
  PHONE         VARCHAR2(13),
  EMAIL         VARCHAR2(120),
  JOB           VARCHAR2(40),
  CONSTRAINT PK_KOUZA_EXT PRIMARY KEY (KOUZA_NO),
  CONSTRAINT FK_KOUZA_EXT FOREIGN KEY (KOUZA_NO) REFERENCES KOUZA(KOUZA_NO),
  CONSTRAINT CK_KEXT_PRIM CHECK (IS_PRIMARY IN ('Y','N'))
);

-- ============================================================
--  取引ジャーナル  TORIHIKI
-- ============================================================
CREATE TABLE TORIHIKI (
  TORIHIKI_ID   NUMBER(12)     NOT NULL,
  KOUZA_NO      NUMBER(7)      NOT NULL,
  TORIHIKI_DT   CHAR(14)       NOT NULL,          -- YYYYMMDDHHMMSS
  TORIHIKI_KBN  CHAR(1)        NOT NULL,          -- 1=入金 2=出金 3=振込
  KINGAKU       NUMBER(11)     NOT NULL,
  AITE_KOUZA    NUMBER(7),                        -- 振込のみ
  TESURYO       NUMBER(5),                        -- 振込のみ
  TEKIYOU       VARCHAR2(80),                     -- 摘要 Shift-JIS
  CONSTRAINT PK_TORIHIKI     PRIMARY KEY (TORIHIKI_ID),
  CONSTRAINT FK_TORIHIKI_KZ  FOREIGN KEY (KOUZA_NO) REFERENCES KOUZA(KOUZA_NO),
  CONSTRAINT CK_TORIHIKI_KBN CHECK (TORIHIKI_KBN IN ('1','2','3'))
);
CREATE INDEX IX_TORIHIKI_KZ_DT ON TORIHIKI (KOUZA_NO, TORIHIKI_DT);

-- ============================================================
--  ローン
-- ============================================================
CREATE TABLE LOAN_ASIS (
  LOAN_ID       NUMBER(12)     NOT NULL,
  KOUZA_NO      NUMBER(7)      NOT NULL,
  PRINCIPAL     NUMBER(15)     NOT NULL,
  BALANCE       NUMBER(15)     NOT NULL,
  METHOD        CHAR(1)        NOT NULL,          -- A/B/C
  TERM_YEARS    NUMBER(3)      NOT NULL,
  RATE          NUMBER(5,3)    DEFAULT 2.5 NOT NULL,
  OPENED_DATE   DATE           DEFAULT TRUNC(SYSDATE) NOT NULL,
  CLOSED_DATE   DATE,
  STATUS        VARCHAR2(10)   DEFAULT 'ACTIVE' NOT NULL,
  CONSTRAINT PK_LOAN_ASIS   PRIMARY KEY (LOAN_ID),
  CONSTRAINT FK_LOAN_ASIS   FOREIGN KEY (KOUZA_NO) REFERENCES KOUZA(KOUZA_NO),
  CONSTRAINT CK_LOAN_METHOD CHECK (METHOD IN ('A','B','C')),
  CONSTRAINT CK_LOAN_STATUS CHECK (STATUS IN ('ACTIVE','CLOSED'))
);
CREATE INDEX IX_LOAN_ASIS_KZ ON LOAN_ASIS (KOUZA_NO);

CREATE TABLE LOAN_REPAY_ASIS (
  REPAY_ID      NUMBER(15)     NOT NULL,
  LOAN_ID       NUMBER(12)     NOT NULL,
  PRINCIPAL     NUMBER(15)     NOT NULL,
  INTEREST      NUMBER(15)     DEFAULT 0 NOT NULL,
  FEE           NUMBER(15)     DEFAULT 0 NOT NULL,
  TOTAL         NUMBER(15)     NOT NULL,
  REPAY_DATE    DATE           DEFAULT TRUNC(SYSDATE) NOT NULL,
  RECEIPT_NO    VARCHAR2(30),
  CONSTRAINT PK_REPAY_ASIS PRIMARY KEY (REPAY_ID),
  CONSTRAINT FK_REPAY_ASIS FOREIGN KEY (LOAN_ID) REFERENCES LOAN_ASIS(LOAN_ID)
);
CREATE INDEX IX_REPAY_ASIS_LN ON LOAN_REPAY_ASIS (LOAN_ID);

-- ============================================================
--  お知らせ
-- ============================================================
CREATE TABLE NOTICE_ASIS (
  NOTICE_ID     NUMBER(12)     NOT NULL,
  NOTICE_DATE   CHAR(8)        NOT NULL,          -- YYYYMMDD
  TAG           VARCHAR2(30),                     -- Shift-JIS
  TITLE         VARCHAR2(600)  NOT NULL,          -- Shift-JIS
  BODY          VARCHAR2(2000),                   -- Shift-JIS
  IS_ACTIVE     CHAR(1)        DEFAULT 'Y' NOT NULL,
  CONSTRAINT PK_NOTICE_ASIS PRIMARY KEY (NOTICE_ID),
  CONSTRAINT CK_NOTICE_ACT  CHECK (IS_ACTIVE IN ('Y','N'))
);

CREATE TABLE NOTICE_FILE_ASIS (
  FILE_ID       NUMBER(15)     NOT NULL,
  NOTICE_ID     NUMBER(12)     NOT NULL,
  FILE_NAME     VARCHAR2(300)  NOT NULL,
  CONSTRAINT PK_NOTICE_FILE_ASIS PRIMARY KEY (FILE_ID),
  CONSTRAINT FK_NOTICE_FILE_ASIS FOREIGN KEY (NOTICE_ID)
      REFERENCES NOTICE_ASIS(NOTICE_ID) ON DELETE CASCADE
);

-- 自行店舗マスタ
CREATE TABLE BRANCH_ASIS (
  BRANCH_CODE   VARCHAR2(3)    NOT NULL,
  NAME_JA       VARCHAR2(40)   NOT NULL,          -- Shift-JIS
  CONSTRAINT PK_BRANCH_ASIS PRIMARY KEY (BRANCH_CODE)
);

-- 振込先金融機関マスタ
CREATE TABLE BANK_ASIS (
  BANK_ID       NUMBER(4)      NOT NULL,
  NAME          VARCHAR2(40)   NOT NULL,          -- Shift-JIS
  COLOR         VARCHAR2(9),
  TEXT_COLOR    VARCHAR2(9),
  MARK          VARCHAR2(8),                      -- Shift-JIS
  CONSTRAINT PK_BANK_ASIS PRIMARY KEY (BANK_ID),
  CONSTRAINT UQ_BANK_ASIS UNIQUE (NAME)
);

-- ============================================================
--  シーケンス (RAW판과 동일 채번값)
-- ============================================================
CREATE SEQUENCE SEQ_KOUZA_DYN    START WITH 9000001      INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_TORIHIKI     START WITH 100000000001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_LOAN_ASIS    START WITH 1            INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_REPAY_ASIS   START WITH 1            INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_NOTICE_ASIS  START WITH 4            INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_RECEIPT_ASIS START WITH 10251        INCREMENT BY 1 NOCACHE;

COMMIT;
