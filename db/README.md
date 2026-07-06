# DB 레이아웃 (Oracle) — KS은행 미니뱅크 데모

`app.js`의 인메모리 데이터 모델을 Oracle RDB로 정규화한 스키마입니다.

## 파일

| 파일 | 내용 |
|------|------|
| `01_schema.sql` | 테이블·제약·인덱스·시퀀스 (DDL). 재실행 가능(기존 오브젝트 DROP 후 생성) |
| `02_seed.sql` | 초기 데이터 (마스터 + **시연용/테스트용 2계정** + 시연용 거래 100건 + 공지) |

## 시드 계정

| 구분 | 점번 | 계좌번호 | PW | 잔액 | 명세 |
|------|------|----------|-----|------|------|
| 시연용 | 001 | 1000123 | `ks1234` | 거래 100건 반영 후 자동계산 | 6개월치 100건 |
| 테스트용 | 001 | 9000001 | `test1234` | 10,000,000엔 | 없음(비움) |

> 시연용 거래 100건은 `02_seed.sql`의 PL/SQL 블록에서 14종 패턴을 순환하며 2026-01-06~07-03에 분산 생성.
> 투입 후 잔액이 음수가 되지 않도록 期首 잔액을 계산해 `ACCOUNT.balance`와 각 `TXN.balance_after`를 자동 확정.

## 실행

```sql
-- SQL*Plus / SQLcl
@01_schema.sql
@02_seed.sql
```

> DB 캐릭터셋은 일본어/한국어를 담기 위해 **AL32UTF8** 권장.
> (그렇지 않으면 `NVARCHAR2` 컬럼 사용 — 이미 다국어 컬럼은 `NVARCHAR2`로 정의함)

## ER 개요

```
CUSTOMER 1 ──< ACCOUNT >── ACCOUNT_TYPE
                  │  └── BRANCH
                  ├──< TXN
                  └──< LOAN ──< LOAN_REPAYMENT
BANK (이체 대상 마스터, 독립)
NOTICE 1 ──< NOTICE_FILE
```

## 테이블

| 테이블 | 대응 (app.js) | 설명 |
|--------|--------------|------|
| `ACCOUNT_TYPE` | `RATE_BY_TYPE`, `typeMap` | 계좌종별(普通/当座/積立/定期) + 금리 |
| `BRANCH` | `STORES` | 자행 점포(점번) |
| `BANK` | `BANKS`, `BANK_META` | 이체 대상 금융기관 + 로고 메타 |
| `CUSTOMER` | `account.kanji/kana` + `account.prof` | 명의인/프로필 |
| `ACCOUNT` | `buildAccounts()` | 계좌(잔액/상태/PW/대표여부/적금정보) |
| `TXN` | `buildJournal()` | 거래명세(元帳) |
| `LOAN` | `loans[]`, `loanHistory[]` | 대출계약(잔액/방식/기간) |
| `LOAN_REPAYMENT` | `loanRepayExecute()` | 대출 상환 이력 |
| `NOTICE` | `dict().notices`, `extraNotices` | 공지사항 |
| `NOTICE_FILE` | `notice.files[]` | 공지 첨부파일 |

## 앱 상수 (참고)

DDL의 기본값/체크에 반영된 `app.js` 상수:

| 상수 | 값 | 위치 |
|------|-----|------|
| `LOAN_RATE` | 2.5% | `LOAN.rate` 기본값 |
| `LOAN_AVAIL` | 3,000,000엔 | 대출 한도(앱 로직) |
| `REPAY_FEE` | 550엔 | `LOAN_REPAYMENT.fee` |
| `TRANSFER_FEE` | 110엔 | 이체 수수료(`TXN` 手数料 행) |

## 코드값

- **거래유형 `TXN.txn_type`**: `入金` `出金` `振込` `手数料` `融資実行` `融資返済`
- **계좌상태 `ACCOUNT.status`**: `正常` `凍結`
- **대출방식 `LOAN.method`**: `A`(元利均等) `B`(元金均等) `C`(満期一括)
- **대출상태 `LOAN.status`**: `ACTIVE` `CLOSED`

## 설계 메모

- 데모라 `ACCOUNT.password`는 평문 시드값(`ks1234` 등). **실운영은 해시 저장** 필요.
- `TXN.balance_after`는 조회 편의를 위한 선택 컬럼. 원장 무결성은 거래 누적으로 산출 가능(app.js `_meisaiRaw` 로직 참고).
- 공지 삭제는 물리삭제 대신 `NOTICE.is_active = 'N'`(논리삭제). app.js의 `hiddenBase`와 대응.
- 수령번호(`receipt_no`)는 `SEQ_RECEIPT`(초기 10247 = app.js `rSeq`)로 채번 후 `WEB/DEP/LOAN/REPAY` 접두사 부여.
