-- ============================================================
--  파리티 고정 데이터 (PostgreSQL / UTF-8)  —  COBOL↔Java 1:1 대조 전용
--
--  ☠☠☠ 운영/데모 서버 DB 에서는 절대 실행하지 말 것 ☠☠☠
--    맨 처음 DELETE FROM TORIHIKI(전건 삭제)를 하고 잔액도 시드값으로 되돌린다.
--    라이브 데모 데이터(거래이력·잔액)가 사라진다.
--    실행해도 되는 곳은 "1:1 대조용 로컬/검증 환경"뿐이다.
--
--  ★왜 필요한가
--    온라인(/api/furikomi)으로 거래를 만들면 TORIHIKI_DT 가 삽입 시각
--    (wall-clock)이 된다. TORIHIKI_DT 는 明細 D레코드
--    (MD-TORIHIKI-DT PIC X(14))에 그대로 들어가므로, 양쪽에 같은 HTTP
--    호출을 넣어도 dt 가 어긋나 明細의 모든 줄이 diff 된다.
--    게다가 COBOL 컨테이너만 TZ=Asia/Tokyo 다.
--    → TORIHIKI_ID 와 TORIHIKI_DT 를 "리터럴"로 고정한다.
--
--  ★멱등성
--    야간배치는 newBal = 현재잔액 + 이자 라서 재실행마다 이자가 누적된다
--    (처리済 플래그 없음). 대조 실행 전에 반드시 본 스크립트를 재적용해
--    초기 상태로 되돌릴 것.
--
--  대응하는 Oracle 판: backend-cobol/sql/90_parity_fixture.sql
--  (둘은 논리적으로 동일. 방언만 다름)
--
--  실행: docker exec -i mbj-postgres psql -U minibank -d minibank < 이 파일
-- ============================================================

-- ------------------------------------------------------------
-- 1) 거래 저널 전삭제
-- ------------------------------------------------------------
DELETE FROM TORIHIKI;

-- ------------------------------------------------------------
-- 2) 동적 계좌대역(9000000 이상) 삭제 — FK 순: KOUZA_EXT -> KOUZA
-- ------------------------------------------------------------
DELETE FROM KOUZA_EXT WHERE KOUZA_NO >= 9000000;
DELETE FROM KOUZA     WHERE KOUZA_NO >= 9000000;

-- ------------------------------------------------------------
-- 3) 고정 8계좌의 잔액·상태를 시드값으로 복원
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
-- 4) 거래 8건 — ID/DT 리터럴 고정. DT 는 ID 와 단조 증가.
--
--    ★DT 를 ID 와 단조로 두는 이유
--      MKDAT 은 ORDER BY KOUZA_NO, TORIHIKI_ID, 온라인 明細
--      (TransactionRepository.findByKouza)은 ORDER BY torihiki_dt,
--      torihiki_id. 단조면 두 순서가 같아져 배치의 取引後残高와
--      온라인 /api/meisai 의 afterBal 이 일치한다(공짜 교차검증).
--
--    커버 케이스:
--      1000123 普通  3건(구분1/2/3, 수수료 有) 이자>0 / 동일계좌 다건=SORTDAT 제2키 검증
--      2000456 普通  1건(구분1)                이자0 (잔액 < 365000)
--      3000789 普通  1건(구분2)                이자>0 (3円)
--      1001011 当座  1건(구분1)                이자0 이지만 T레코드는 존재
--      4001213 普通  1건(구분3)                이자0 + 手数料合計은 110 (0 아님)
--      5001415 普通  1건(구분1) JOUTAI='9' 凍結  凍結이어도 이자가 붙음(양쪽 공통 사양 고정)
--      6001617 普通  0건                       휴면 + 明細 없음
--      1001819 当座  0건                       휴면(当座·무거래)
-- ------------------------------------------------------------
INSERT INTO TORIHIKI (TORIHIKI_ID,KOUZA_NO,TORIHIKI_DT,TORIHIKI_KBN,KINGAKU,AITE_KOUZA,TESURYO,TEKIYOU) VALUES
  (100000000001,1000123,'20260801090000','1',30000,NULL,NULL,NULL),
  (100000000002,1000123,'20260801100000','2',12000,NULL,NULL,NULL),
  (100000000003,1000123,'20260801110000','3',10000,2000456,110,NULL),
  (100000000004,2000456,'20260801110000','1',10000,NULL,NULL,NULL),
  (100000000005,3000789,'20260801120000','2', 4000,NULL,NULL,NULL),
  (100000000006,1001011,'20260801130000','1',20000,NULL,NULL,NULL),
  (100000000007,4001213,'20260801140000','3', 1000,3000789,110,NULL),
  (100000000008,5001415,'20260801150000','1',20000,NULL,NULL,NULL);

-- ------------------------------------------------------------
-- 5) 채번 시퀀스를 고정값 다음으로 되돌림(반복 실행 시 동일 결과)
-- ------------------------------------------------------------
ALTER SEQUENCE SEQ_TORIHIKI     RESTART WITH 100000000009;
ALTER SEQUENCE SEQ_RECEIPT_ASIS RESTART WITH 10251;
ALTER SEQUENCE SEQ_KOUZA_DYN    RESTART WITH 9000001;

-- ------------------------------------------------------------
--  확인
-- ------------------------------------------------------------
SELECT KOUZA_NO, SHUBETSU, JOUTAI, ZANDAKA FROM KOUZA ORDER BY KOUZA_NO;
SELECT COUNT(*) AS torihiki_cnt FROM TORIHIKI;
