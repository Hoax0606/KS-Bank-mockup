-- ============================================================
--  minibank (Java) 스타터 시드 — PostgreSQL, RAW(bytea)
--  ※ 스캐폴딩용 최소 시드(2계좌 + 지점 1)입니다.
--    전체 시드(계좌8·지점10·은행5·공지3)는 backend-cobol/sql/02_seed.sql 의
--    HEXTORAW('..') -> decode('..','hex') 기계 치환으로 생성하면 됩니다(후속 단계).
--  값은 라이브 Oracle 실측 바이트와 동일.
-- ============================================================

-- 지점 001 (東京営業部)
INSERT INTO BRANCH_ASIS (BRANCH_CODE, NAME_JA) VALUES
  (decode('F0F0F1','hex'), decode('28C5ECB5FEB1C4B6C8C9F429','hex'));

-- 山田太郎 (1000123 / ks1234 / 523400)
INSERT INTO KOUZA (KOUZA_NO, MEIGI_KANJI, MEIGI_KANA, SHUBETSU, KAISETSU_BI, JOUTAI, ZANDAKA) VALUES
  (decode('F1F0F0F0F1F2F3','hex'),
   decode('28BBB3C5C4C2C0CFBA2940404040404040404040','hex'),
   decode('28A5E4A5DEA5C0A5BFA5EDA5A629404040404040','hex'),
   decode('F1','hex'), decode('F2F0F1F8F0F4F1F5','hex'), decode('F0','hex'),
   decode('00000523400C','hex'));
INSERT INTO KOUZA_EXT (KOUZA_NO, BRANCH_CODE, ACCT_TYPE, PASSWORD, IS_PRIMARY, KANJI_UTF8, KANA_UTF8) VALUES
  (decode('F1F0F0F0F1F2F3','hex'), decode('F0F0F1','hex'), decode('28C9E1C4CC29','hex'),
   decode('92A2F1F2F3F4','hex'), decode('E8','hex'), '山田太郎', 'ヤマダタロウ');

-- 佐藤花子 (2000456 / 1111 / 88250)
INSERT INTO KOUZA (KOUZA_NO, MEIGI_KANJI, MEIGI_KANA, SHUBETSU, KAISETSU_BI, JOUTAI, ZANDAKA) VALUES
  (decode('F2F0F0F0F4F5F6','hex'),
   decode('28BAB4C6A3B2D6BBD22940404040404040404040','hex'),
   decode('28A5B5A5C8A5A6A5CFA5CAA5B329404040404040','hex'),
   decode('F1','hex'), decode('F2F0F2F0F0F5F0F1','hex'), decode('F0','hex'),
   decode('00000088250C','hex'));
INSERT INTO KOUZA_EXT (KOUZA_NO, BRANCH_CODE, ACCT_TYPE, PASSWORD, IS_PRIMARY, KANJI_UTF8, KANA_UTF8) VALUES
  (decode('F2F0F0F0F4F5F6','hex'), decode('F2F0F0','hex'), decode('28C9E1C4CC29','hex'),
   decode('F1F1F1F1','hex'), decode('D5','hex'), '佐藤花子', 'サトウハナコ');
