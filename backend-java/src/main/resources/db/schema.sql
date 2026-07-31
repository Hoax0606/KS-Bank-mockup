-- ============================================================
--  minibank (Java 백엔드) PostgreSQL 스키마  — 일반 타입 / UTF-8
--  ★ 변경(2026-07-30): 메인프레임 RAW(JEF/COMP-3/존10진) 폐기 →
--     텍스트=UTF-8 varchar/text, 금액/키=numeric(integer/bigint), 일자=char 로 정상화.
--     backend-cobol/sql/01_ddl.sql(Oracle 정상화판)의 PostgreSQL 이식본.
--     ※ PostgreSQL DB 문자셋은 UTF-8 전제 → 일본어를 리터럴로 직접 저장.
--  Oracle→PG: NUMBER(7)->integer, NUMBER(11..15)->bigint, NUMBER(5,3)->numeric(5,3),
--             VARCHAR2->varchar, CHAR->char, DATE->date, TRUNC(SYSDATE)->current_date.
-- ============================================================

-- ------------------------------------------------------------
--  재실행 가능하도록 기존 오브젝트 제거 (RAW판 뷰/함수 포함)
-- ------------------------------------------------------------
DROP VIEW IF EXISTS V_KOUZA, V_TORIHIKI CASCADE;
DROP FUNCTION IF EXISTS fn_unzone(bytea);
DROP FUNCTION IF EXISTS fn_unpack(bytea);
DROP TABLE IF EXISTS TORIHIKI, KOUZA_EXT, LOAN_REPAY_ASIS, LOAN_ASIS,
                     NOTICE_FILE_ASIS, NOTICE_ASIS, KOUZA, BRANCH_ASIS, BANK_ASIS CASCADE;

-- ============================================================
--  口座マスタ  KOUZA
-- ============================================================
CREATE TABLE KOUZA (
  KOUZA_NO      integer      NOT NULL,             -- 口座番号 7桁
  MEIGI_KANJI   varchar(40)  NOT NULL,             -- 名義(漢字) UTF-8
  MEIGI_KANA    varchar(40)  NOT NULL,             -- 名義(カナ) UTF-8
  SHUBETSU      char(1)      NOT NULL,             -- 1=普通 2=当座
  KAISETSU_BI   char(8)      NOT NULL,             -- YYYYMMDD
  JOUTAI        char(1)      NOT NULL DEFAULT '0', -- 0=正常 9=凍結
  ZANDAKA       bigint       NOT NULL DEFAULT 0,
  CONSTRAINT PK_KOUZA     PRIMARY KEY (KOUZA_NO),
  CONSTRAINT CK_KOUZA_SHU CHECK (SHUBETSU IN ('1','2')),
  CONSTRAINT CK_KOUZA_JOU CHECK (JOUTAI  IN ('0','9'))
);

-- 口座付帯情報
CREATE TABLE KOUZA_EXT (
  KOUZA_NO      integer      NOT NULL,
  BRANCH_CODE   varchar(3)   NOT NULL,             -- 店番3桁
  ACCT_TYPE     varchar(20)  NOT NULL,             -- 普通/当座/積立/定期 (UTF-8)
  PASSWORD      varchar(60),                       -- 데모: 평문
  IS_PRIMARY    char(1)      NOT NULL DEFAULT 'N',
  SAVE_TERM     integer,
  SAVE_MONTHLY  bigint,
  BIRTH         varchar(10),
  SEX           varchar(6),
  ZIP           varchar(7),
  ADDR          varchar(200),
  PHONE         varchar(13),
  EMAIL         varchar(120),
  JOB           varchar(40),
  CONSTRAINT PK_KOUZA_EXT PRIMARY KEY (KOUZA_NO),
  CONSTRAINT FK_KOUZA_EXT FOREIGN KEY (KOUZA_NO) REFERENCES KOUZA(KOUZA_NO),
  CONSTRAINT CK_KEXT_PRIM CHECK (IS_PRIMARY IN ('Y','N'))
);

-- ============================================================
--  取引ジャーナル  TORIHIKI
-- ============================================================
CREATE TABLE TORIHIKI (
  TORIHIKI_ID   bigint       NOT NULL,
  KOUZA_NO      integer      NOT NULL,
  TORIHIKI_DT   char(14)     NOT NULL,             -- YYYYMMDDHHMMSS
  TORIHIKI_KBN  char(1)      NOT NULL,             -- 1=入金 2=出金 3=振込
  KINGAKU       bigint       NOT NULL,
  AITE_KOUZA    integer,                           -- 振込のみ
  TESURYO       integer,                           -- 振込のみ
  TEKIYOU       varchar(80),                       -- 摘要 UTF-8
  CONSTRAINT PK_TORIHIKI     PRIMARY KEY (TORIHIKI_ID),
  CONSTRAINT FK_TORIHIKI_KZ  FOREIGN KEY (KOUZA_NO) REFERENCES KOUZA(KOUZA_NO),
  CONSTRAINT CK_TORIHIKI_KBN CHECK (TORIHIKI_KBN IN ('1','2','3'))
);
CREATE INDEX IX_TORIHIKI_KZ ON TORIHIKI (KOUZA_NO);

-- ============================================================
--  ローン
-- ============================================================
CREATE TABLE LOAN_ASIS (
  LOAN_ID       bigint       NOT NULL,
  KOUZA_NO      integer      NOT NULL,
  PRINCIPAL     bigint       NOT NULL,
  BALANCE       bigint       NOT NULL,
  METHOD        char(1)      NOT NULL,             -- A/B/C
  TERM_YEARS    integer      NOT NULL,
  RATE          numeric(5,3) NOT NULL DEFAULT 2.5,
  OPENED_DATE   date         NOT NULL DEFAULT current_date,
  CLOSED_DATE   date,
  STATUS        varchar(10)  NOT NULL DEFAULT 'ACTIVE',
  CONSTRAINT PK_LOAN_ASIS   PRIMARY KEY (LOAN_ID),
  CONSTRAINT FK_LOAN_ASIS   FOREIGN KEY (KOUZA_NO) REFERENCES KOUZA(KOUZA_NO),
  CONSTRAINT CK_LOAN_METHOD CHECK (METHOD IN ('A','B','C')),
  CONSTRAINT CK_LOAN_STATUS CHECK (STATUS IN ('ACTIVE','CLOSED'))
);
CREATE INDEX IX_LOAN_ASIS_KZ ON LOAN_ASIS (KOUZA_NO);

CREATE TABLE LOAN_REPAY_ASIS (
  REPAY_ID      bigint       NOT NULL,
  LOAN_ID       bigint       NOT NULL,
  PRINCIPAL     bigint       NOT NULL,
  INTEREST      bigint       NOT NULL DEFAULT 0,
  FEE           bigint       NOT NULL DEFAULT 0,
  TOTAL         bigint       NOT NULL,
  REPAY_DATE    date         NOT NULL DEFAULT current_date,
  RECEIPT_NO    varchar(30),
  CONSTRAINT PK_REPAY_ASIS PRIMARY KEY (REPAY_ID),
  CONSTRAINT FK_REPAY_ASIS FOREIGN KEY (LOAN_ID) REFERENCES LOAN_ASIS(LOAN_ID)
);
CREATE INDEX IX_REPAY_ASIS_LN ON LOAN_REPAY_ASIS (LOAN_ID);

-- ============================================================
--  お知らせ
-- ============================================================
CREATE TABLE NOTICE_ASIS (
  NOTICE_ID     bigint       NOT NULL,
  NOTICE_DATE   char(8)      NOT NULL,             -- YYYYMMDD
  TAG           varchar(30),                       -- UTF-8
  TITLE         varchar(600) NOT NULL,             -- UTF-8
  BODY          varchar(2000),                     -- UTF-8
  IS_ACTIVE     char(1)      NOT NULL DEFAULT 'Y',
  CONSTRAINT PK_NOTICE_ASIS PRIMARY KEY (NOTICE_ID),
  CONSTRAINT CK_NOTICE_ACT  CHECK (IS_ACTIVE IN ('Y','N'))
);

CREATE TABLE NOTICE_FILE_ASIS (
  FILE_ID       bigint       NOT NULL,
  NOTICE_ID     bigint       NOT NULL,
  FILE_NAME     varchar(300) NOT NULL,
  CONSTRAINT PK_NOTICE_FILE_ASIS PRIMARY KEY (FILE_ID),
  CONSTRAINT FK_NOTICE_FILE_ASIS FOREIGN KEY (NOTICE_ID)
      REFERENCES NOTICE_ASIS(NOTICE_ID) ON DELETE CASCADE
);

-- 自行店舗マスタ
CREATE TABLE BRANCH_ASIS (
  BRANCH_CODE   varchar(3)   NOT NULL,
  NAME_JA       varchar(40)  NOT NULL,             -- UTF-8
  CONSTRAINT PK_BRANCH_ASIS PRIMARY KEY (BRANCH_CODE)
);

-- 振込先金融機関マスタ
CREATE TABLE BANK_ASIS (
  BANK_ID       integer      NOT NULL,
  NAME          varchar(40)  NOT NULL,             -- UTF-8
  COLOR         varchar(9),
  TEXT_COLOR    varchar(9),
  MARK          varchar(8),                        -- UTF-8
  CONSTRAINT PK_BANK_ASIS PRIMARY KEY (BANK_ID),
  CONSTRAINT UQ_BANK_ASIS UNIQUE (NAME)
);

-- ============================================================
--  시퀀스 (RAW판/Oracle 채번값과 동일)
-- ============================================================
CREATE SEQUENCE SEQ_KOUZA_DYN    START 9000001;
CREATE SEQUENCE SEQ_TORIHIKI     START 100000000001;
CREATE SEQUENCE SEQ_LOAN_ASIS    START 1;
CREATE SEQUENCE SEQ_REPAY_ASIS   START 1;
CREATE SEQUENCE SEQ_NOTICE_ASIS  START 4;
CREATE SEQUENCE SEQ_RECEIPT_ASIS START 10251;
