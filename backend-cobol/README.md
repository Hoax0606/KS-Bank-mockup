# ASIS(レガシー)バックエンド — KS銀行 ミニバンク・デモ

**GnuCOBOL + EXEC SQL(GixSQL プリコンパイル) + Oracle**、フロント接続は **CGI**。
`claude readme/ClaudeCode_Prompt_ASIS_COBOL_Backend.md` の指示に基づく実装です。

> 本 `backend-cobol/` は **ASIS 正本**。リポジトリ既存の `db/`(app.js を正規化した UTF-8 スキーマ, TOBE 寄り)や `backend-java/` とは別物です。`db/` は参照用として保存します。

---

## ★ 현재 구현 현황 (2026-07-29 갱신 — 아래 §0~§9보다 우선)

> 아래 본문 §0~§9는 **초기 설계 기록**입니다. 이후 인코딩이 크게 확장되어, 일부 서술
> (`TEAMENC` 스텁 인코더, CP930, 10자리 계좌번호, `ZANDAKA NUMBER(11)` 등)은 **더 이상 유효하지 않습니다.**
> 실제 현재 상태는 이 절을 정본으로 삼으세요.

**인코딩 = 전 컬럼 RAW 저장/디코드 (완료)**
- **텍스트**(명의·지점명·공지·상태·일자 등): 후지쯔 **JEF EBCDIC**. 라이브러리 `net.arnx:jef4j`
  (charset `x-Fujitsu-JEF-EBCDIC`, SO=0x28/SI=0x29). 초기 데모의 `TEAMENC.cbl`(CP930 스텁)은 **삭제됨**.
- **금액/이율/원장금액**: **COMP-3 팩10진** RAW.
- **키**(KOUZA_NO·TORIHIKI_ID·LOAN_ID 등): **존10진 EBCDIC** RAW (각 자리 `F`+숫자, 예 `1000123`→`F1F0F0F0F1F2F3`).
- **예외(비-RAW)**: 조회용 디코드 뷰 `V_*` + `KOUZA_EXT.KANJI_UTF8/KANA_UTF8` 미러 2컬럼뿐.

**변환 경로**
- 텍스트: COBOL `CALL "JEFCONV"` → `cobol/JEFCONV.c`(C 브리지, TCP) → `jef/JefServer.java`(상주 서비스
  `127.0.0.1:9099`, `jef4j.jar` 사용). 모드 `E`=인코드(UTF8→JEF hex), `D`=디코드(bytes), `H`=hex입력 디코드.
  entrypoint.sh가 컨테이너 기동 시 JefServer를 백그라운드 실행.
- 금액/키: COBOL 코덱 카피북에서 직접. `copy/WTXT.cpy`+`copy/PTXT.cpy`(텍스트 JEF hex 왕복),
  `copy/WPACK.cpy`+`copy/PPACK.cpy`(COMP-3 금액 + 존10진 키).
- CGI 패턴: 읽기 `SELECT RAWTOHEX(col)` → 디코드, 쓰기 `HEXTORAW(:hex)`. 온라인 CGI 11개 + 배치 전부 적용.

**조회용 디코드 뷰** (DBeaver 등에서 원본 RAW를 사람이 읽기 위함, 원본 테이블은 불변):
`V_KOUZA / V_TORIHIKI / V_LOAN / V_REPAY / V_NOTICE`. 함수 `FN_UNZONE(raw)`=존10진→숫자,
`FN_UNPACK(raw)`=COMP-3→숫자, `FN_EBC(raw)`=단바이트 EBCDIC→문자(`WE8EBCDIC500`).
일본어 텍스트는 SQL만으로 디코드 불가라, `V_KOUZA`의 명의는 UTF-8 미러 컬럼을 사용.

**⚠️ 최우선 미결 — DDL/시드 소스가 라이브 DB와 불일치**
`sql/01_ddl.sql`·`02_seed.sql`은 **RAW 전환 이전(NUMBER/평문)** 상태입니다. 라이브 Oracle만 ALTER로
RAW화됐고 생성 스크립트(gen/seedgen)는 남아있지 않습니다. 따라서 **새 Oracle을 이 DDL/시드로 초기화하면
코드(RAW 기대)와 어긋나 동작하지 않습니다.** 현재 실동작 환경은 서버 라이브 DB뿐이며, 프레시 재구축을 하려면
라이브 DB에서 RAW 스키마/데이터를 덤프해 `01_ddl.sql`(전 컬럼 RAW)·`02_seed.sql`(HEXTORAW 시드)을
재생성해야 합니다.

**배치**(§5)는 실거래 연동 방식(옵션1): 온라인 CGI가 이미 실시간 반영하므로, 배치는 재INSERT 없이
명세 생성 + 이자 가산만 담당(普通 종별만, `floor(잔액/365000)`). 파이프라인 4단계는 그대로.

---

## 0. 前提と決定事項(重要)

このデモの実フロントエンド(`frontend/app.js`)は **完全にクライアント完結**で、
**HTTP API 呼び出し(fetch/XHR)が一つもありません**。したがって「フロントから API 契約を
抽出」することは不可能でした。ユーザー承認のもと、以下で進めています。

| 論点 | 決定(承認済) |
|---|---|
| API 契約 | **当方が設計**(フロントのインメモリ・データ形状に一致させた CGI/JSON 契約。§2 参照) |
| DB スキーマ | **両方維持** — ASIS は本書 §3 の `KOUZA`/`TORIHIKI`(EBCDIC/COMP-3)で新規、既存 `db/` は保存 |
| 範囲 | **フロント機能まで拡張** — オンライン5種 + ログイン/開設/ローン/返済/公知 |

確定設計(プロンプト §0.1):
- オンライン CGI 応答 = **UTF-8**。DB 保存・バッチ出力は **EBCDIC(CP930)原本**維持。
- 明細レポート = **58 byte 固定**(T は実内容29 + 空白29)。
- 利息は **普通(種別1)のみ**。当座(種別2)は無利息。

---

## 1. ディレクトリ構成

```
backend-cobol/
  cobol/            # COBOL ソース
    ZANDAKA/NYUKIN/SHUKKIN/FURIKOMI/MEISAI.cbl   # オンライン5種
    LOGIN/SIGNUP/LOAN/REPAY/NOTICE/HOLDINGS.cbl  # 拡張オンライン
    YAKANBAT.cbl     # 夜間バッチ(決定打の中核)
    MKDAT.cbl        # 当日取引 TORIHIKI.DAT サンプル生成
    TEAMENC/RAWUTF8/EBCDIG/CGIUTIL.cbl           # 共通モジュール
    copy/*.cpy       # カピブック(レコード/CGI/DB/手続き)
  sql/              # 01_ddl.sql / 02_seed.sql / 99_reset.sql
  build/Makefile    # gixpp -> cobc
  docker/           # Dockerfile.asis / compose.asis.yml / entrypoint.sh
  cgi/nginx-cgi.conf
  data/             # TORIHIKI.DAT(生成) / MEISAI.RPT(バッチ出力)
```

---

## 2. API 契約(当方設計)

すべて `/api/<name>`。応答は `application/json; charset=UTF-8`。
成功は `{"ok":true,...}`、失敗は HTTP ステータス + `{"ok":false,"error":"<key>"}`。
口座番号 `kouza` は **ASIS の 10桁 KOUZA_NO**。

| # | エンドポイント | メソッド | 主な要求 | 応答(抜粋) |
|---|---|---|---|---|
| 1 | `/api/zandaka`  | GET  | `kouza` | `meigiKanji, meigiKana, shubetsu, zandaka, joutai` |
| 2 | `/api/nyukin`   | POST | `kouza, kingaku` | `receipt, dt, afterBal` |
| 3 | `/api/shukkin`  | POST | `kouza, kingaku` | `receipt, dt, afterBal`(残高不足=409) |
| 4 | `/api/furikomi` | POST | `kouza, aite, kingaku` | `receipt, fee:110, afterBal`(**原子的**) |
| 5 | `/api/meisai`   | GET  | `kouza, [kbn], [from], [to]` | `rows:[{date,kbn,kingaku,afterBal,memo}]` |
| 6 | `/api/login`    | POST | `branch, acct, pw` | 口座情報 |
| 7 | `/api/signup`   | POST | `kanji, kana, type, branch, pw, ...` | 新規 `kouza` |
| 8 | `/api/loan`     | GET/POST | GET:`kouza` / POST:`kouza,amt,method,years` | 一覧 / `loanId` |
| 9 | `/api/repay`    | POST | `loanId, principal` | `interest, fee:550, total, closed` |
| 10| `/api/notice`   | GET/POST | GET:— / POST:`title,[body],[tag]` | 一覧 / `noticeId` |
| 11| `/api/holdings` | GET  | `kouza` | `holdings:[{...}]`(1要素・最小実装) |

> フロントを実バックエンドに繋ぐ場合、この契約に合わせて `app.js` の
> インメモリ処理を `fetch('/api/...')` へ置換すれば無変更に近い形で接続可能。

---

## 3. データモデル(§3)

- `KOUZA` : `KOUZA_NO 9(10)`, `MEIGI_KANJI/KANA RAW(20)`(CP930原本), `SHUBETSU 1/2`,
  `ZANDAKA NUMBER(11)`(COMP-3 対応), `KAISETSU_BI`, `JOUTAI 0/9`。
- `TORIHIKI` : `TORIHIKI_ID 9(12)`, `KOUZA_NO`, `TORIHIKI_DT`, `TORIHIKI_KBN 1/2/3`,
  `KINGAKU`, `AITE_KOUZA`/`TESURYO`(振込のみ), `TEKIYOU RAW(40)`。
- 拡張機能用: `KOUZA_EXT`(PW/店番/表示種別/**UTF-8ミラー**/プロフィール), `LOAN_ASIS`,
  `LOAN_REPAY_ASIS`, `NOTICE_ASIS`, `BRANCH_ASIS`, `BANK_ASIS`。

### レコード・レイアウト(固定長)
- `TORIHIKI.DAT` = **97 byte**(§4.1, `TR-EXT` の REDEFINES で種別分岐)。
- `MEISAI.RPT` = **58 byte 固定**(D=明細 / T=口座合計 空白パディング, §4.2)。
- COMP-3 byte = `floor(桁/2)+1` → `S9(11)=6byte`, `S9(05)=3byte`。カピブックで厳守。

---

## 4. ビルド & 実行(Docker)

```bash
# リポジトリルート(minibank-demo/)で
docker compose -f backend-cobol/docker/compose.asis.yml up -d --build
```

- `oracle`(gvenzl/oracle-free 23, 1521): init で `01_ddl.sql`→`02_seed.sql` 自動適用。
- `asis-backend`(nginx + fcgiwrap + CGI, 8080→80): フロントを `/` 配信、API は `/api/...`。
- ブラウザ: `http://localhost:8080/`

> **前提物**: `backend-cobol/docker/vendor/` に Oracle Instant Client(basiclite+sdk) と
> GixSQL ソース `gixsql-1.0.20b.tar.gz` を配置してください(再配布条件のため同梱せず)。
> 入手方法は `backend-cobol/docker/vendor/README.md` 参照。

> **動作確認済み**(GnuCOBOL 3.1.2 + GixSQL 1.0.20b + Oracle Free 23 / Docker):
> オンライン全 API・夜間バッチ・自動初期化(fresh `up` で DDL+シード自動適用)を
> エンドツーエンドで確認。`http://localhost:8080/` でフロントも配信。
>
> **ビルド内実装メモ**(GixSQL/GnuCOBOL の癖への対応):
> - `build/expand_copy.sh` で COPY を先に平坦化してから `gixpp`(gixpp は COPY 非展開、
>   cobc は `EXEC SQL INCLUDE` を誤処理するため)。`END PROGRAM` 行も gixpp 前に除去。
> - `gixpp -e -S -z c`: `-S`=静的呼出(GIXSQL ランタイムをリンク時解決)、
>   `-z c`=コロン(`:1`)パラメータ(Oracle/ODPI 必須。既定 `$1` は 0 件返却)。
> - DB 接続文字列は `oracle://host:port/service`(スキーム必須)。
> - SORT は YAKANBAT と別プロセス(§5)。gixpp は SD/一部の空白リテラル・
>   関数内バインドを壊すため、該当箇所は SQL を単純化して回避済み。

### ローカル(コンテナ外)ビルド
```bash
cd backend-cobol/build
make GIXHOME=/opt/gixsql          # gixpp -> cobc。bin/*.cgi, bin/YAKANBAT, lib/*.so 生成
```

---

## 5. 夜間バッチ(§7)

バッチは **4 ステップの独立プロセス**で実行する(`run_batch.sh` が順に起動):
`MKDAT`(当日取引生成)→ `SORTDAT`(口座番号順)→ `YAKANBAT`(反映+KOUZA更新+REPORT.WORK)
→ `SORTRPT`(名義カナEBCDIC順で MEISAI.RPT 出力)。
※ GnuCOBOL の SORT 動詞は Oracle 使用プロセス内で呼ぶとクラッシュするため、
  SORT は YAKANBAT と別プロセス(SORTDAT/SORTRPT)に分離している。

```bash
# コンテナ内で(ORA_CONN 等はイメージ ENV で設定済み)
docker exec -w /app/build mb-asis-backend \
  sh -c 'DAT_IN=/app/data/TORIHIKI.DAT RPT_OUT=/app/data/MEISAI.RPT sh run_batch.sh'
# => [batch] done. records: 12 x 58byte
```

- 出力 `MEISAI.RPT` は **名義カナ EBCDIC 昇順**(決定打2)、全レコード 58byte、**UTF-8変換なし**
  (現新比較ツールの入力=EBCDIC原本)。
- 検証実測(シード直後に1回実行):
  - 普通 `1000000002` = **1319003**(1319000 + 利息3、`floor(残高/365000)` 切り捨て = 決定打1)
  - 当座 `1000000003` = **55000**(入金のみ・**無利息** = 決定打)
  - 普通 `1000000001` = **443291**(振込80000+手数料110 引落後 + 利息1)

---

## 6. リセット(§3.3)

```bash
sqlplus minibank/minibank@//localhost:1521/FREEPDB1 @backend-cobol/sql/99_reset.sql
```
`KOUZA_NO >= 9000000000`(動的帯域)とその取引のみ削除。固定計座(1000000001~/1000000100~)は保存。

---

## 7. 検証チェックリスト(§10)

- [ ] レコード長: `TORIHIKI.DAT`=97, `MEISAI.RPT`(D/T)=58 をバイト単位で確認
      (`wc -c`, `hexdump -C ./data/MEISAI.RPT | ...`)。
- [ ] COMP-3 往復: 最大値 `99999999999`(口座 1000000004)、負値 `-50000`
      (MKDAT の 6件目)を投入し符号ニブルまで一致(**決定打4**)。
- [ ] RAW 無変換往復: `KOUZA.MEIGI_KANJI` の SO/SI 込みバイトが EXEC SQL ホスト変数で
      無損失(NLS_LANG=AL32UTF8, RAW 通過)—**最優先スパイク**。
- [ ] オンライン応答が UTF-8(`/api/zandaka` を curl で確認、フロント無変更描画)。
- [ ] `1000000001`(長い名義)の `MEIGI_KANJI` が **20byte 境界で切り詰め**(**決定打3**)。
- [ ] バッチ `MEISAI.RPT` が名義カナ EBCDIC 順(**決定打2**)、利息切り捨て整数一致(**決定打1**)、
      当座(`1000000003`)の利息=0。
- [ ] 振込原子性: `/api/furikomi` の途中失敗で ROLLBACK(残高不整合なし)。

確認用 SQL(seed 末尾にも同梱):
```sql
SELECT KOUZA_NO, RAWTOHEX(MEIGI_KANA) FROM KOUZA ORDER BY MEIGI_KANA; -- 決定打2 の並び
SELECT KOUZA_NO, LENGTHB(MEIGI_KANJI), RAWTOHEX(MEIGI_KANJI) FROM KOUZA; -- 決定打3
```

---

## 8. 既知の限界 / STOP&ASK の残件(§8)

正直に明記します。以下は **チーム・エンコーダ確定(§8.5/§8.6)** など外部依存で、
デモは動くが本番同等ではありません。

1. **文字エンコーダ(最重要)**: `TEAMENC` は**デモ用**。SO/SI シフト処理・SBCS(ASCII/一部)
   は実装済みだが、**DBCS(漢字)の cp300 全マッピングは未実装**。名義の実表示は
   `KOUZA_EXT.KANJI_UTF8`(UTF-8 ミラー)を権威フォールバックに使用。
   → RAW原本(バッチ/現新比較)と変換機構は保持。エンコーダ確定後に `TEAMENC` /
   `KANA2EBC` / `KANJI2EBC` を差し替える。
2. **EBCDIC 数字の扱い**: パック10進(COMP-3)は EBCDIC/ASCII 同一バイトで完全再現。
   DISPLAY 数字/日時は `EBCDIG` で EBCDIC↔ASCII 変換して往復(GnuCOBOL は ASCII ネイティブのため)。
3. **口座番号桁**: フロントは 7桁だが ASIS 契約は §3 の **10桁 KOUZA_NO**。フロント接続時は
   ゼロ埋め等の整合が必要。
4. **凍結(状態9)規則(§8.4)**: 一貫方針として「凍結=入出金・振込すべて拒否(409)」を採用。
5. **拡張機能のスキーマ**: ローン/公知/プロフィールは決定打対象外のため通常型(UTF-8)。
   `HOLDINGS` は 1口座=1要素の最小実装(顧客IDでの複数口座束ねは未実装)。
6. **CGI 実行基盤**: nginx 単体は CGI 不可のため fcgiwrap 経由。POST body 読取は
   単一行前提(urlencoded/JSON)。

---

## 9. 主要ファイル早見

| 目的 | ファイル |
|---|---|
| レコード定義 | `cobol/copy/KKOUZA.cpy` `KTORIHK.cpy` `WTRDAT.cpy` `WMEISAI.cpy` |
| 残高/入金/出金/振込/明細 | `cobol/ZANDAKA.cbl` `NYUKIN.cbl` `SHUKKIN.cbl` `FURIKOMI.cbl` `MEISAI.cbl` |
| バッチ(決定打の中核) | `cobol/YAKANBAT.cbl` |
| エンコーダ / 変換 | `cobol/TEAMENC.cbl` `RAWUTF8.cbl` `EBCDIG.cbl` |
| CGI 共通 | `cobol/CGIUTIL.cbl`(CGIINIT/CGIPARM/CGIRESP) |
| DDL/シード/リセット | `sql/01_ddl.sql` `02_seed.sql` `99_reset.sql` |
