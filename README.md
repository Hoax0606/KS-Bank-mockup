# KS銀行 ミニバンク・デモ (KS-Bank mockup)

메인프레임 레거시(COBOL + EBCDIC + Oracle)를 재현한 **인터넷뱅킹 데모**입니다.
일본어 명의를 후지쯔 JEF/EBCDIC **원본 바이트로 저장·디코드**하는 것이 이 데모의 핵심 기술 포인트입니다.

> **인수인계 문서입니다.** 처음 받는 분은 이 파일부터 읽고, 세부는 각 폴더의 README/문서를 참고하세요.

---

## 1. 전체 구조

```
브라우저 (frontend/)  ──/api/...──▶  CGI (nginx + fcgiwrap)
                                        │
                                   COBOL (GnuCOBOL + GixSQL EXEC SQL)
                                        │
                                     Oracle (KOUZA / TORIHIKI …, 명의=RAW/EBCDIC 저장)
```

- 프론트엔드는 SPA(바닐라 JS)이며 `/api/...` 상대경로로 백엔드를 호출합니다.
- 백엔드는 **ASIS(레거시) COBOL**이 정본. nginx가 프론트 정적파일과 `/api`를 **같은 오리진**으로 서빙합니다.
- 명의(漢字/カナ)·금액(COMP-3)·키(존10진 EBCDIC)를 전부 메인프레임 바이트로 저장/디코드합니다.

---

## 2. 디렉터리 구성 (최상위)

| 경로 | 내용 | 상태 |
|------|------|------|
| `frontend/` | SPA (index.html / app.js / styles.css). `/api/...` 호출 | 사용 중 |
| `backend-cobol/` | **ASIS 정본 백엔드** — COBOL 소스·카피북·SQL·Docker | 사용 중 (배포됨) |
| `db/` | app.js 인메모리 모델을 정규화한 UTF-8 Oracle 스키마 | **참조용** (ASIS와 별개) |
| `backend-java/` | Java 전환용 자리(빈 폴더) | 예정 (§7) |
| `claude readme/` | ASIS 백엔드 설계 프롬프트 원문 | 참고 문서 |

> `db/`와 `backend-cobol/sql/`은 **서로 다른 스키마**입니다. 실제 구동 정본은 `backend-cobol/sql/`(EBCDIC/COMP-3), `db/`는 UTF-8 정규화 참조본으로 보존만 합니다.

---

## 3. 실행 방법 (Docker, 권장)

```bash
# 리포지토리 루트에서
docker compose -f backend-cobol/docker/compose.asis.yml up -d --build
# → http://localhost:8080/  (프론트 + API 동일 오리진)
```

- `oracle` (gvenzl/oracle-free 23, :1521): 최초 기동 시 `sql/01_ddl.sql` → `02_seed.sql` 자동 적용
- `asis-backend` (nginx + fcgiwrap + CGI, 8080→80): 프론트 `/`, API `/api/...`

### ⚠️ 사전 준비물 (필수 — 깃에 없음)

`backend-cobol/docker/vendor/`에 **재배포 불가 서드파티 3개**를 직접 내려받아 넣어야 빌드됩니다:

| 파일 | 입수처 |
|------|--------|
| `instantclient-basiclite-linux.x64.zip` | Oracle Instant Client (Linux x86-64) |
| `instantclient-sdk-linux.x64.zip` | 같은 페이지 SDK Package |
| `gixsql-1.0.20b.tar.gz` | GitHub `mridoni/gixsql` Releases (1.0.18+) |

자세한 입수·버전 대응은 **`backend-cobol/docker/vendor/README.md`** 참조.

---

## 4. 배포된 데모 서버

COBOL 백엔드가 리눅스 서버에 빌드·구동 중입니다 (Oracle 연결·거래기록 E2E 확인 완료).

- 접속: **사내 Tailscale 망**을 통해 접속합니다 (서버 주소·포트·접속 권한은 담당자에게 문의).

> 서버 주소 및 Tailscale 접속 권한은 seoyeong 님(seoyeong.jeong@ks-infosys.com)에게 요청하세요.

---

## 5. 데모 / 테스트 계정

| 구분 | 점번 | 계좌번호 | PW | 비고 |
|------|------|----------|-----|------|
| 시연용 | 001 | 1000123 | `ks1234` | 山田太郎, 프로필·거래 있음(대표 계좌) |
| 테스트용 | 001 | 9000001 | `test1234` | 잔액 1,000만엔, 거래 비움 |

> ASIS 계약의 계좌번호는 **10자리 `KOUZA_NO`**입니다. 프론트(7자리)와 자릿수 정합에 유의(§ backend-cobol README 8-3).

---

## 6. 더 깊은 문서

| 문서 | 내용 |
|------|------|
| `backend-cobol/README.md` | **백엔드 정본 문서** — API 계약, 데이터모델, 빌드/야간배치, 검증 체크리스트, 알려진 한계 |
| `backend-cobol/docker/vendor/README.md` | vendor 서드파티 입수 방법 |
| `db/README.md` | 참조용 UTF-8 스키마·시드·ER 개요 |
| `claude readme/ClaudeCode_Prompt_ASIS_COBOL_Backend.md` | ASIS 설계 지시서 원문 |

---

## 7. 알려진 한계 · 다음 작업

`backend-cobol/README.md` §8에 상세. 요약:

1. **문자 인코더 미확정** — `TEAMENC`는 데모용. DBCS(한자) cp300 전체 매핑 미구현이라
   실표시는 `KOUZA_EXT.KANJI_UTF8`(UTF-8 미러)를 폴백으로 사용. 원본 RAW/변환 기구는 보존.
   → 팀 인코더 확정 후 `TEAMENC`/`KANA2EBC`/`KANJI2EBC` 교체 예정.
2. **계좌번호 자릿수** — 프론트 7자리 ↔ ASIS 10자리 정합 필요.
3. **Java 전환 예정** — `backend-java/`는 자리만 잡힌 상태. 방침: `JEFCONV.c`/CGI 배관을 버리고
   jef4j 직접 사용 + 웹프레임워크 + JDBC 구성. (실사용 백엔드 = .cbl 18개 + .cpy 14개)

---

## 8. 기타

- DB 비밀번호(`compose.asis.yml`의 `oracle`/`minibank`)는 **데모 더미값**입니다. 실운영 시 반드시 교체·해시 저장.
- `.gitignore`로 vendor 대용량 다운로드·빌드 로그는 추적 제외됩니다.
