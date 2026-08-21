# 1:1 이식 방법론 — 발견된 일반 규칙

NOTICE를 COBOL 문장 단위로 100% 1:1 트랜스리터레이션한 뒤(2026-08), 그 결과물을 실제로
읽고 기능 에러 지점을 찾아 원인을 분석하는 
4단계 검증(① 문장 단위 1:1 매핑 
→ ② 기능에러 지점 파악 
→ ③ 원인·일반 규칙 확인 
→ ④ 규칙 기록)을 거쳤다. 
이 문서는 그 ④단계의 산출물이다 — 앞으로 다른 8개 프로그램에도 같은 4단계를 적용할 때 재사용할 규칙이다.

## 문제를 두 부류로 나눠서 판단한다

COBOL을 문장 단위로 충실히 옮긴 뒤 실제로 실행해서 기능 에러를 찾으면, 그 원인은 항상
둘 중 하나다. 이 분류 자체가 "고칠지 말지"를 정하는 기준이다.


- **A부류 — 진짜 이식 격차**: COBOL 원본을 실제로 돌렸을 때는 발생하지 않지만(예: 프로세스
  경계, 언어의 실행 모델 차이 때문에), 그 문장을 Java로 그대로 옮기면서 새로 생기는 문제.
  
  → **고쳐야 한다.** 단, 임기응변 패치가 아니라 아래처럼 일반화된 규칙 하나를 일관되게
  적용한다.


- **B부류 — COBOL 원본의 약점을 충실히 재현한 것**: COBOL을 실제로 돌려도 소스와 똑같이
  발생하는 문제(SQLCODE 미체크, 초기값 그대로 진행 등). 

  → **고치지 않는다.** 고치면 더이상 COBOL과 1:1이 아니게 된다. 
  "운영상 고칠지"는 1:1 매핑과는 별개의 결정이므로 이 문서에 현상만 기록해두고 별도로 판단한다.


## A부류 판별 기준: "COBOL이 공짜로 받는 보장이 Java에는 없는가?"


COBOL CGI 프로그램은 **요청 하나당 OS 프로세스 하나**를 새로 띄우는 모델이다. 그래서
`STOP RUN`(프로세스 종료)이 일어나면 OS가 그 프로세스가 물고 있던 자원(DB 소켓 등)을
전부 자동으로 정리해준다 
— COBOL 소스에 명시적 해제 문장(`PERFORM DB-DISCONNECT` 등)이 없는 경로가 있어도, 실제로는 안전하다.


Java(Spring)는 요청마다 프로세스를 새로 띄우지 않고 
**하나의 서버가 계속 떠서** 여러 요청을 처리한다. 
그래서 COBOL이 프로세스 경계로부터 공짜로 받던 그 보장이 Java에는 없다. COBOL 문장을 그대로(순차 호출로) 옮기면, 이 보장이 빠진 채로 아무 안전장치도
없는 상태가 되어버린다 — 이게 A부류다.


### 적용 규칙


> **자원을 확보한 지점에서 곧바로 Java의 언어 차원 해제 보장 장치로 묶는다 — COBOL
> 원문에 그 해제 문장이 순차문으로 있는지 없는지와 무관하게.**

자원 종류에 따라 문법만 다르고 원칙은 하나다:

| 자원 종류 | 적용 문법 |
|---|---|
| `Db.DB_CONNECT()`/`DB_DISCONNECT()` 페어(커스텀 유틸, `Closeable` 아님) | `try { ... } finally { Db.DB_DISCONNECT(conn); }` |
| MyBatis `Cursor<T>`(`java.io.Closeable` 구현) | `try (Cursor<T> C = dao.select_NN(dto)) { ... }` |

기존에 이미 있던 `SqlSession`(`try (SqlSession session = ...)`)도 같은 원칙을 처음부터
따르고 있었다 — 새로 발견한 게 아니라 이미 지켜지던 패턴이 확인된 것.

## NOTICE에 적용한 사례 (2026-08)

`NoticeServiceImpl.java`에서 실제로 발견·수정한 A부류 2건:

1. **DB 커넥션 누수**: `MAIN()`에서 `DO-CREATE`가 `missing_title`/`invalid_text_encoding`
   (400) 등으로 예외를 던지면 `Db.DB_DISCONNECT(conn)`(COBOL 52행 대응)까지 도달하지
   못했다. 커넥션 풀이 없는 구조(의도적 설계)라 요청마다 실제로 커넥션이 쌓였다 
   — title 없이 POST를 반복하면 DB `max_connections` 소진으로 **다른 모든 엔드포인트까지 장애**.

   → `Db.DB_CONNECT()`~`Db.DB_DISCONNECT()` 구간 전체를 `try/finally`로 재구성해 해결.

   (`DO-CREATE`의 INSERT 실패 분기에 있는, COBOL 149행 대응 명시적 `Db.DB_DISCONNECT(conn)`
   호출은 1:1 대응 유지를 위해 그대로 둠 — `Db.DB_DISCONNECT`가 이미 `!conn.isClosed()`로
   멱등하므로 finally와 중복 호출돼도 안전.)


2. **커서 미해제**: `DO-LIST`의 FETCH 루프 중(`EMIT-NOTICE`에서 `C-DATE` 참조수정 등)
   예외가 나면 `C_NOTICE.close()`(COBOL 68행 대응, 루프 다음 줄에 위치)까지 도달하지
   못했다. COBOL의 `STRING`문은 예외로 제어를 빠져나가는 개념 자체가 없어 항상 CLOSE에
   도달하지만, Java의 `String` 연산은 예외를 던져 그 자리에서 제어를 빠져나간다
   — 위치만옮겨서는 같은 "항상 도달" 보장이 안 됨. 

   → `Cursor<CNoticeDto>`를 `try-with-resources`로재구성해 해결. 
   
   select_01이 `Cursor`를 쓰는 다른 프로그램(MEISAI, LOAN)도 나중에 이
   4단계를 진행하면 동일 규칙 적용 대상이다.


## 이번에 B부류로 분류하고 그대로 둔 것 (참고용, 미수정)


- **DO-LIST의 SQLCODE 미체크**: `EXEC SQL OPEN C-NOTICE`(COBOL 60행) 실패 시 COBOL도
  SQLCODE를 확인하지 않아 "DB 장애"와 "공지 0건"을 구분하지 못한다 — Java도 동일.


- **채번 실패 시 초기값 진행**: `HV-NID`(COBOL `PIC 9(12)`, VALUE절 없음)가 NEXTVAL
  조회 실패 시 초기값 0에 머문 채로 다음 INSERT에 쓰인다 — Java `long HV_NID`(기본값 0)도
  같은 성질이라 우연히 1:1이 된다. (INSERT의 PK 제약 덕에 데이터 훼손 없이 결국
  `notice_failed` 500으로는 끝나지만, 클라이언트가 받는 에러 메시지가 진짜 원인과
  다르다는 관찰 사항만 기록.)
