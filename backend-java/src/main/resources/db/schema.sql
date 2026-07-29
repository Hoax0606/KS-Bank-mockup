-- ============================================================
--  minibank (Java 백엔드) PostgreSQL 스키마  — 전 컬럼 RAW(bytea)
--  backend-cobol/sql/01_ddl.sql(Oracle, 전 컬럼 RAW)의 PG 이식본.
--    RAW(n)     -> bytea
--    NVARCHAR2  -> text (KOUZA_EXT 의 UTF-8 미러 2컬럼만)
--    HEXTORAW   -> decode(..,'hex') (seed.sql)
--  텍스트=JEF EBCDIC, 금액=COMP-3, 키=존10진 을 바이트 그대로 저장(앱 코덱이 왕복).
-- ============================================================

DROP VIEW IF EXISTS V_KOUZA;
DROP TABLE IF EXISTS TORIHIKI, KOUZA_EXT, LOAN_REPAY_ASIS, LOAN_ASIS,
                     NOTICE_FILE_ASIS, NOTICE_ASIS, KOUZA, BRANCH_ASIS, BANK_ASIS CASCADE;

CREATE TABLE KOUZA (
  KOUZA_NO     bytea NOT NULL,   -- 존10진 7byte
  MEIGI_KANJI  bytea NOT NULL,   -- JEF 20byte
  MEIGI_KANA   bytea NOT NULL,   -- JEF 20byte
  SHUBETSU     bytea NOT NULL,   -- 1byte (F1/F2)
  KAISETSU_BI  bytea NOT NULL,   -- 8byte YYYYMMDD
  JOUTAI       bytea NOT NULL,   -- 1byte (F0/F9)
  ZANDAKA      bytea,            -- COMP-3 6byte
  CONSTRAINT PK_KOUZA PRIMARY KEY (KOUZA_NO)
);

CREATE TABLE KOUZA_EXT (
  KOUZA_NO     bytea NOT NULL,
  BRANCH_CODE  bytea NOT NULL,   -- 존10진 3byte
  ACCT_TYPE    bytea NOT NULL,
  PASSWORD     bytea,
  IS_PRIMARY   bytea NOT NULL,
  SAVE_TERM    bytea,
  SAVE_MONTHLY bytea,
  KANJI_UTF8   text,             -- 조회/폴백용 UTF-8 미러
  KANA_UTF8    text,
  BIRTH        bytea, SEX bytea, ZIP bytea, ADDR bytea,
  PHONE        bytea, EMAIL bytea, JOB bytea,
  CONSTRAINT PK_KOUZA_EXT PRIMARY KEY (KOUZA_NO),
  CONSTRAINT FK_KOUZA_EXT FOREIGN KEY (KOUZA_NO) REFERENCES KOUZA(KOUZA_NO)
);

CREATE TABLE TORIHIKI (
  TORIHIKI_ID  bytea NOT NULL,   -- 존10진 12byte
  KOUZA_NO     bytea,
  TORIHIKI_DT  bytea NOT NULL,   -- JEF 14byte YYYYMMDDHHMMSS
  TORIHIKI_KBN bytea NOT NULL,   -- 1byte
  KINGAKU      bytea,            -- COMP-3 6byte
  AITE_KOUZA   bytea,            -- 존10진 7byte
  TESURYO      bytea,            -- COMP-3 3byte
  TEKIYOU      bytea,
  CONSTRAINT PK_TORIHIKI PRIMARY KEY (TORIHIKI_ID),
  CONSTRAINT FK_TORIHIKI_KZ FOREIGN KEY (KOUZA_NO) REFERENCES KOUZA(KOUZA_NO)
);
CREATE INDEX IX_TORIHIKI_KZ ON TORIHIKI (KOUZA_NO);

CREATE TABLE LOAN_ASIS (
  LOAN_ID     bytea NOT NULL, KOUZA_NO bytea, PRINCIPAL bytea, BALANCE bytea,
  METHOD      bytea NOT NULL, TERM_YEARS bytea, RATE bytea, STATUS bytea NOT NULL,
  OPENED_DATE bytea, CLOSED_DATE bytea,
  CONSTRAINT PK_LOAN_ASIS PRIMARY KEY (LOAN_ID),
  CONSTRAINT FK_LOAN_ASIS FOREIGN KEY (KOUZA_NO) REFERENCES KOUZA(KOUZA_NO)
);

CREATE TABLE LOAN_REPAY_ASIS (
  REPAY_ID bytea NOT NULL, LOAN_ID bytea, PRINCIPAL bytea, INTEREST bytea,
  FEE bytea, TOTAL bytea, REPAY_DATE bytea, RECEIPT_NO bytea,
  CONSTRAINT PK_REPAY_ASIS PRIMARY KEY (REPAY_ID),
  CONSTRAINT FK_REPAY_ASIS FOREIGN KEY (LOAN_ID) REFERENCES LOAN_ASIS(LOAN_ID)
);

CREATE TABLE NOTICE_ASIS (
  NOTICE_ID bytea NOT NULL, NOTICE_DATE bytea NOT NULL, TAG bytea,
  TITLE bytea NOT NULL, BODY bytea, IS_ACTIVE bytea NOT NULL,
  CONSTRAINT PK_NOTICE_ASIS PRIMARY KEY (NOTICE_ID)
);
CREATE TABLE NOTICE_FILE_ASIS (
  FILE_ID bytea NOT NULL, NOTICE_ID bytea, FILE_NAME bytea NOT NULL,
  CONSTRAINT PK_NOTICE_FILE_ASIS PRIMARY KEY (FILE_ID),
  CONSTRAINT FK_NOTICE_FILE_ASIS FOREIGN KEY (NOTICE_ID)
      REFERENCES NOTICE_ASIS(NOTICE_ID) ON DELETE CASCADE
);

CREATE TABLE BRANCH_ASIS (
  BRANCH_CODE bytea NOT NULL, NAME_JA bytea NOT NULL,
  CONSTRAINT PK_BRANCH_ASIS PRIMARY KEY (BRANCH_CODE)
);
CREATE TABLE BANK_ASIS (
  BANK_ID bytea NOT NULL, NAME bytea NOT NULL, COLOR bytea,
  TEXT_COLOR bytea, MARK bytea,
  CONSTRAINT PK_BANK_ASIS PRIMARY KEY (BANK_ID),
  CONSTRAINT UQ_BANK_ASIS UNIQUE (NAME)
);

-- 시퀀스 (Oracle 채번값과 맞춤)
CREATE SEQUENCE SEQ_KOUZA_DYN    START 9000001;
CREATE SEQUENCE SEQ_TORIHIKI     START 100000000001;
CREATE SEQUENCE SEQ_LOAN_ASIS    START 1;
CREATE SEQUENCE SEQ_REPAY_ASIS   START 1;
CREATE SEQUENCE SEQ_NOTICE_ASIS  START 4;
CREATE SEQUENCE SEQ_RECEIPT_ASIS START 10251;

-- ------------------------------------------------------------
--  조회용 디코드 함수/뷰 (DBeaver 등에서 사람이 읽기용)
--    fn_unzone : 존10진 bytea -> 숫자 (각 바이트 하위 니블)
--    fn_unpack : COMP-3 bytea -> 숫자 (마지막 니블 부호)
--  ※ 단바이트 EBCDIC(fn_ebc) / JEF(일본어) 디코드는 PG 기본 함수로 불가.
--    일본어 명의는 KANJI_UTF8 미러 사용. (TODO: fn_ebc PL/pgSQL 룩업 or 앱단 디코드)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_unzone(r bytea) RETURNS numeric AS $$
  SELECT CASE WHEN r IS NULL THEN NULL ELSE
    (SELECT string_agg((get_byte(r, g) & 15)::text, '')::numeric
       FROM generate_series(0, length(r)-1) g) END;
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE FUNCTION fn_unpack(r bytea) RETURNS numeric AS $$
DECLARE h text; digits text; sign int;
BEGIN
  IF r IS NULL THEN RETURN NULL; END IF;
  h := encode(r, 'hex');
  digits := substr(h, 1, length(h)-1);
  sign := CASE WHEN upper(substr(h, length(h), 1)) = 'D' THEN -1 ELSE 1 END;
  RETURN sign * digits::numeric;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE VIEW V_KOUZA AS
  SELECT fn_unzone(k.KOUZA_NO) AS KOUZA_NO,
         e.KANJI_UTF8          AS MEIGI_KANJI,   -- JEF는 DB디코드 불가 → 미러
         fn_unpack(k.ZANDAKA)  AS ZANDAKA
    FROM KOUZA k LEFT JOIN KOUZA_EXT e ON e.KOUZA_NO = k.KOUZA_NO;
