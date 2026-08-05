# ASIS(レガシー)バックエンド — KS銀行 ミニバンク・デモ

**GnuCOBOL + EXEC SQL(GixSQL プリコンパイル) + Oracle**、フロント接続は **CGI**。
`claude readme/ClaudeCode_Prompt_ASIS_COBOL_Backend.md` の指示に基づく実装です。

> 本 `backend-cobol/` は **ASIS 正本**。リポジトリ既存の `db/`(app.js を正規化した UTF-8 スキーマ, TOBE 寄り)や `backend-java/` とは別物です。`db/` は参照用として保存します。

---

## ★ 현재 구현 현황 (2026-07-30 갱신 — 아래 §0~§9보다 우선)

> 아래 본문 §0~§9는 **초기 설계 기록**입니다. 이후 두 차례 크게 바뀌어(① 전 컬럼 RAW 인코딩 확장 →
> ② 2026-07-30 Shift-JIS 정상 타입 마이그레이션), 일부 서술(`TEAMENC` 스텁 인코더, CP930,
> 10자리 계좌번호, `ZANDAKA NUMBER(11)`, RAW/COMP-3/존10진, `MEISAI.RPT` 58byte 등)은
> **더 이상 유효하지 않습니다.** 실제 현재 상태는 이 절을 정본으로 삼으세요.

**문자셋 = Oracle JA16SJIS + 정상 타입 컬럼 (2026-07-30 마이그레이션 완료)**
사장님 지시: **Oracle = Shift-JIS**. 이전의 "전 컬럼 RAW(JEF EBCDIC 텍스트 + COMP-3 금액 + 존10진 키) +
앱측 코덱" 설계는 **전부 제거**했습니다. 새 구조:
- **DB**: `dbca -characterSet JA16SJIS`로 재생성한 **Shift-JIS 문자셋 DB**. 컬럼은 **정상 타입** —
  키·금액 = `NUMBER`, 일본어 텍스트(명의·지점명·공지 등) = `VARCHAR2`(디스크에 Shift-JIS 바이트), 코드·일자 = `CHAR`.
  RAW/JEF/COMP-3/존10진 컬럼, 디코드 뷰(`V_*`), 디코드 함수(`FN_UNZONE/FN_UNPACK/FN_EBC`),
  `KOUZA_EXT.KANJI_UTF8/KANA_UTF8` 미러 컬럼은 **모두 없어졌습니다.**
- **앱(COBOL)**: 정상 컬럼을 그대로 읽고 씁니다(호스트변수 직접 바인딩, VARCHAR2 등가비교는 `RTRIM(:hv)`).
  GixSQL/OCI 드라이버가 NLS_LANG과 무관하게 **클라이언트 문자셋을 UTF-8로 강제**(Instant Client basiclite에
  문자셋 변환기가 없음)하므로, 일본어 컬럼은 앱에 **UTF-8**로 도착하고 HTTP 응답도 UTF-8입니다.
- **순효과**: **DB는 디스크에 Shift-JIS, 앱/HTTP는 UTF-8, 브라우저는 일본어 정상 표시.**

**삭제된 것 (구 RAW/JEF 설계)**
- 소스: `cobol/JEFCONV.c`, `cobol/RAWUTF8.cbl`, `cobol/EBCDIG.cbl`, `jef/` 디렉터리 전체
  (`JefServer.java`, `jef4j.jar`, `JefHex.java`, `ReSeed.java`, `names.txt`).
- 카피북: `copy/{WPACK,PPACK,WTXT,PTXT,WENCODE}.cpy`.
- 런타임: **127.0.0.1:9099 JEF 상주 서비스**(entrypoint가 더 이상 기동하지 않음).
- 빌드: `build/Makefile`의 `MODS`는 이제 `CGIINIT CGIPARM CGIRESP`만 포함(`EBCDIG`/`RAWUTF8` 제외).
  `Dockerfile.asis`는 `JEFCONV.so`(gcc)·`JefServer`(javac)를 더 이상 컴파일하지 않고 JDK/openjdk도 설치 안 함.

**DDL/시드 = JA16SJIS 정상 타입 정본** ✅
`sql/01_ddl.sql`·`02_seed.sql`은 JA16SJIS DB용 **정상 타입 스키마 + 일본어 리터럴 시드**입니다.
커스텀 Oracle 이미지(`docker/Dockerfile.oracle-sjis` + `oracle-sjis/build-sjis-db.sh`·`mkuser.sql`)가
공식 Oracle Free 이미지를 받아 **빌드 시점**에 `dbca -characterSet JA16SJIS`로 DB를 재생성하고 스키마+시드를
구워 넣습니다(재기동 시 SAVE STATE로 자동 오픈). `compose.asis.yml`의 `oracle` 서비스가 이 이미지를 빌드합니다.

**배치**(§5)는 실거래 연동 방식(옵션1): 온라인 CGI가 이미 실시간 반영하므로, 배치는 재INSERT 없이
명세 생성 + 이자 가산만 담당(普通 종별만, `floor(잔액/365000)`). 플랫파일은 이제 **네이티브**
(ASCII display 숫자 + 네이티브 COMP-3 + UTF-8 텍스트)이며, 모든 리포트 배치는 정상 컬럼을 읽습니다.
`MEISAI.RPT` 레코드는 명의 필드가 UTF-8 수용을 위해 넓어져(`MD-MEIGI-KANJI X(60)`) **98 byte**입니다(기존 58).
`SORTDAT`는 그대로(키가 ASCII 숫자라 바이트 정렬이 곧 숫자순).

---

## 0. 前提と決定事項(重要)

このデモの実フロントエンド(`frontend/app.js`)は **完全にクライアント完結**で、
**HTTP API 呼び出し(fetch/XHR)が一つもありません**。したがって「フロントから API 契約を
抽出」することは不可能でした。ユーザー承認のもと、以下で進めています。

| 論点 | 決定(承認済) |
|---|---|
| API 契約 | **当方が設計**(フロントのインメモリ・データ形状に一致させた CGI/JSON 契約。§2 参照) |
| DB スキーマ | **両方維持** — ASIS は本書 §3 の `KOUZA`/`TORIHIKI`(現在は JA16SJIS + 正常型)で新規、既存 `db/` は保存 |
| 範囲 | **フロント機能まで拡張** — オンライン5種 + ログイン/開設/ローン/返済/公知 |

確定設計(現在の状態 — 2026-07-30 マイグレーション後):
- オンライン CGI 応答 = **UTF-8**。DB は **JA16SJIS(Shift-JIS)**、アプリ/HTTP は **UTF-8**(ドライバが変換)。
  バッチ出力(フラットファイル)は **ネイティブ**(ASCII display 数字 + ネイティブ COMP-3 + UTF-8 テキスト)。
- 明細レポート `MEISAI.RPT` = **98 byte 固定**(旧 58 byte。名義欄が UTF-8 収容のため拡幅)。
- 利息は **普通(種別1)のみ**。当座(種別2)は無利息。

---

## 1. ディレクトリ構成

```
backend-cobol/
  cobol/            # COBOL ソース
    ZANDAKA/NYUKIN/SHUKKIN/FURIKOMI/MEISAI.cbl   # オンライン5種
    LOGIN/SIGNUP/LOAN/REPAY/NOTICE/HOLDINGS.cbl  # 拡張オンライン
    YAKANBAT.cbl     # 夜間バッチ(反映 + 利息)
    MKDAT.cbl        # 当日取引 TORIHIKI.DAT サンプル生成
    CGIUTIL.cbl      # 共通モジュール(CGIINIT/CGIPARM/CGIRESP)
    copy/*.cpy       # カピブック(レコード/CGI/DB/手続き)
  sql/              # 01_ddl.sql / 02_seed.sql / 99_reset.sql (JA16SJIS・正常型)
  build/Makefile    # gixpp -> cobc
  docker/           # Dockerfile.asis / Dockerfile.oracle-sjis / oracle-sjis/ / compose.asis.yml / entrypoint.sh
  cgi/nginx-cgi.conf
  data/             # TORIHIKI.DAT(生成) / MEISAI.RPT(バッチ出力)
```

> 旧 RAW/JEF 設計のファイル(`JEFCONV.c`, `RAWUTF8.cbl`, `EBCDIG.cbl`, `TEAMENC.cbl`, `jef/` 一式,
> コーデック・カピブック `WPACK/PPACK/WTXT/PTXT/WENCODE.cpy`)は 2026-07-30 に **削除済み**。

---

## 2. API 契約(当方設計)

すべて `/api/<name>`。応答は `application/json; charset=UTF-8`。
成功は `{"ok":true,...}`、失敗は HTTP ステータス + `{"ok":false,"error":"<key>"}`。
口座番号 `kouza` は **7桁 `KOUZA_NO`**(`NUMBER`、フロント表示と一致)。

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

> ※ 以下は **現在の正常型スキーマ**(JA16SJIS)。旧 RAW/COMP-3/存10進 表現は 2026-07-30 に廃止。
- `KOUZA` : `KOUZA_NO NUMBER`(7桁), `MEIGI_KANJI/KANA VARCHAR2`(Shift-JIS 日本語テキスト), `SHUBETSU CHAR 1/2`,
  `ZANDAKA NUMBER`, `KAISETSU_BI CHAR`, `JOUTAI CHAR 0/9`。
- `TORIHIKI` : `TORIHIKI_ID NUMBER`, `KOUZA_NO`, `TORIHIKI_DT`, `TORIHIKI_KBN 1/2/3`,
  `KINGAKU NUMBER`, `AITE_KOUZA`/`TESURYO`(振込のみ), `TEKIYOU VARCHAR2`。
- 拡張機能用: `KOUZA_EXT`(PW/店番/表示種別/プロフィール — UTF-8ミラー列は廃止), `LOAN_ASIS`,
  `LOAN_REPAY_ASIS`, `NOTICE_ASIS`, `BRANCH_ASIS`, `BANK_ASIS`。

### レコード・レイアウト(固定長, フラットファイルはネイティブ形式)
- `TORIHIKI.DAT`(§4.1, `TR-EXT` の REDEFINES で種別分岐)。固定長 97 byte、ASCII display 数字 + ネイティブ COMP-3 + UTF-8 テキスト。
- `MEISAI.RPT` = **98 byte 固定**(旧 58 byte。名義欄 `MD-MEIGI-KANJI X(60)` が UTF-8 収容のため拡幅。§4.2)。

---

## 4. ビルド & 実行(Docker)

```bash
# リポジトリルート(minibank-demo/)で
docker compose -f backend-cobol/docker/compose.asis.yml up -d --build
```

- `oracle`(**JA16SJIS カスタムイメージ**, 1521): `docker/Dockerfile.oracle-sjis`(+`oracle-sjis/build-sjis-db.sh`・`mkuser.sql`)が公式 Oracle Free イメージを `dbca -characterSet JA16SJIS` で再生成し、スキーマ+シード(`01_ddl.sql`→`02_seed.sql`)をビルド時に焼き込む(再起動時 SAVE STATE で自動オープン)。
- `asis-backend`(nginx + fcgiwrap + CGI, 8080→80): フロントを `/` 配信、API は `/api/...`。JEF 常駐サービス(旧 9099)は起動しない。
- ブラウザ: `http://localhost:8080/`

> **前提物**: `backend-cobol/docker/vendor/` に Oracle Instant Client(basiclite+sdk) と
> GixSQL ソース `gixsql-1.0.20b.tar.gz` を配置してください(再配布条件のため同梱せず)。
> 入手方法は `backend-cobol/docker/vendor/README.md` 参照。

> **動作確認済み**(GnuCOBOL 3.1.2 + GixSQL 1.0.20b + Oracle Free 23 JA16SJIS / Docker):
> オンライン全 API・夜間バッチをエンドツーエンドで確認。`http://localhost:8080/` でフロントも配信。
> DB は Shift-JIS 保存、アプリ/HTTP は UTF-8(ドライバがクライアント文字セットを UTF-8 に強制)。
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

## 5. 夜間バッチ(§7) — 10 ステップ

バッチは **10 ステップの独立プロセス**で実行する(`run_batch.sh` が順に起動)。
前半 4 = コア反映(DB 更新あり)、後半 6 = 日次帳票(読取専用, 正常型カラムを直接読む)。

| # | プログラム | 役割 | 出力 |
|---|-----------|------|------|
| 1 | `MKDAT`    | 当日取引抽出(DB TORIHIKI→flat) | TORIHIKI.DAT (ネイティブ) |
| 2 | `SORTDAT`  | 口座番号順 + 取引ID順ソート | TORIHIKI.SORTED |
| 3 | `YAKANBAT` | 反映 + 利息 + KOUZA 更新 | (DB更新) REPORT.WORK |
| 4 | `SORTRPT`  | 名義カナ順ソート | MEISAI.RPT (98byte固定) |
| 5 | `NIPPOBAT` | 取引日報(区分別 件数・金額) | NIPPO.RPT |
| 6 | `ZANDABAT` | 日次残高一覧(全口座) | ZANDAKA.RPT |
| 7 | `TESUBAT`  | 振込手数料 集計 | TESURYO.RPT |
| 8 | `KYUMBAT`  | 休眠口座(無取引)抽出 | KYUMIN.RPT |
| 9 | `MASTBAT`  | 口座マスタ一覧表 | KOUZA.LST |
| 10| `TOKEBAT`  | 統計サマリ(口座数・種別・残高) | TOKEI.RPT |

※ GnuCOBOL の SORT 動詞は Oracle 使用プロセス内で呼ぶとクラッシュするため、
  SORT は YAKANBAT と別プロセス(SORTDAT/SORTRPT)に分離している。
※ `SORTDAT` はバイトソートのままで数値順になる(キーが ASCII 数字のため)。
※ **`SORTDAT` は第2キー `SW1-ID`(取引ID, 1-12byte)を持つ**。第1キー(口座番号)だけだと同一口座に
  2件以上の取引があるとキーが重複し、重複キーの出力順は規格上未定義になる。`YAKANBAT` は本ファイルの
  順序どおりに残高を積み上げて `取引後残高` を書くため、順序が揺れると **明細の値そのものが変わる**
  (最終残高・T レコードは不変)。`MKDAT` が既に `ORDER BY KOUZA_NO, TORIHIKI_ID` で抽出しているので、
  この2キー整列は恒等変換=**保証された no-op** になる(兄弟の `SORTRPT` も `SW2-SEQ` で同じ安定化を行う)。
※ 5-10 は正常型カラム(NUMBER の残高・金額・キー)をそのまま読む。出力は読みやすい LINE SEQUENTIAL。

```bash
# コンテナ内で(exec シェルには entrypoint の ORA_* が無いので注入)
docker exec -w /app/build \
  -e ORA_CONN=oracle://oracle:1521/FREEPDB1 -e ORA_USER=minibank -e ORA_PASS=minibank \
  mb-asis-backend sh -c 'mkdir -p data; sh run_batch.sh'
# => [batch] all 10 steps done.
```

- 出力 `MEISAI.RPT` は **名義カナ昇順**、全レコード 98byte(名義欄 `X(60)` を UTF-8 で収容)、テキストは UTF-8。
- 当日取引のある口座について 明細D + 合計T を出力し、確定残高に日次利息を加算(posting):
  - **普通口座**(種別1, 例 `1000123`)= `floor(確定残高 / 365000)` を利息として加算。
  - **当座口座**(種別2, 例 `1001011`)= **無利息**(利息=0)。
  - ※ シードは TORIHIKI が空なので、先にオンライン取引(`/api/furikomi` 等)を発生させてから実行すると明細が出力される(取引ゼロなら `MEISAI.RPT` も空)。

### Java 版との 1:1 値対照

```bash
sh tools/parity/compare.sh      # => PARITY OK  もしくは 最初の不一致箇所の diff
```

- 固定データは `sql/90_parity_fixture.sql`(Oracle)と `backend-java/.../db/90_parity_fixture.sql`(PostgreSQL)。
  **オンライン取引で対照データを作ってはいけない** — `TORIHIKI_DT` が挿入時刻(wall-clock)で、その値が
  明細 D レコード(`MD-TORIHIKI-DT`)に入るため両系で食い違い全行が diff する(しかも当コンテナのみ
  `TZ=Asia/Tokyo`)。固定データは `TORIHIKI_ID`/`TORIHIKI_DT` をリテラルで固定する。
- `MEISAI.RPT` は COMP-3 を含むので `tools/parity/meisai_dump.py` でテキスト化して比較する。
- ⚠️ **バッチは冪等でない**(`ACC-NEW = ACC-BAL + ACC-INT`、処理済フラグ無し)。対照の前に必ず
  固定データを再適用する。対照中はオンライン操作をしないこと(5-10 は別プロセスなので途中の取引を見る)。

---

## 6. リセット(§3.3)

```bash
sqlplus minibank/minibank@//localhost:1521/FREEPDB1 @backend-cobol/sql/99_reset.sql
```
動的帯域(`KOUZA_NO >= 9000001`, 開設で採番)とその取引のみ削除。固定口座は保存。

---

## 7. 検証チェックリスト(§10)

- [x] レコード長: `MEISAI.RPT`(D/T)=98 をバイト単位で確認 — `compare.sh` が毎回自動検証する
      (固定データで 1372 bytes = 98 × 14 レコード)。
- [ ] 文字セット: `KOUZA.MEIGI_KANJI` が DB では Shift-JIS で格納されること(`SELECT DUMP(MEIGI_KANJI) FROM KOUZA;`)。
- [x] オンライン応答が UTF-8(`/api/zandaka` を curl で確認、フロント無変更描画)。日本語が文字化けしない。
- [x] バッチ `MEISAI.RPT` が名義カナ順、利息切り捨て整数一致(`floor(残高/365000)`)、当座口座の利息=0。
- [x] **同一口座内の取引順が `TORIHIKI_ID` 順で決定的**(`SORTDAT` 第2キー `SW1-ID`)。
      `cmp data/TORIHIKI.DAT TORIHIKI.SORTED` が一致 = 恒等順列(保証された no-op)であることを実測確認済み。
- [x] **Java 版との 1:1 値対照**: `sh tools/parity/compare.sh` が `PARITY OK` — 帳票7種 diff なし(2026-08-04 実測)。
- [ ] 振込原子性: `/api/furikomi` の途中失敗で ROLLBACK(残高不整合なし)。

> ⚠️ `MEISAI.RPT` の名義欄は **UTF-8** で格納される(DB はディスク上 Shift-JIS だが GixSQL/OCI が
> クライアント文字セットを UTF-8 に強制するため)。実測バイト例: 佐藤花子 =
> `e4 bd 90 e8 97 a4 e8 8a b1 e5 ad 90`。
> Windows で `MEISAI.RPT` をテキスト化するツールは **出力を UTF-8 に固定**すること
> (`tools/parity/meisai_dump.py` 参照)。ロケール既定(cp932/cp949 等)で書くと値が同じでも
> バイトが変わり diff が壊れる。

確認用 SQL:
```sql
SELECT KOUZA_NO, MEIGI_KANJI, ZANDAKA FROM KOUZA ORDER BY MEIGI_KANA;  -- 読める値がそのまま
SELECT KOUZA_NO, DUMP(MEIGI_KANJI) FROM KOUZA;                          -- 格納バイト(Shift-JIS)確認
```

> 旧「決定打」スパイク(JEF/COMP-3/存10진 の RAW バイト同一性)は 2026-07-30 マイグレーションで対象外。
> 現在は「DB=Shift-JIS 格納 / アプリ・HTTP=UTF-8 / 日本語が正しく往復」が検証観点。

---

## 8. 既知の限界(§8)

> 旧「文字エンコーダ未確定 / EBCDIC 数字往復 / RAW原本」系の残件は 2026-07-30 マイグレーションで解消(該当コード削除)。
> 以下は現行構成の限界です。

1. **文字セット**: Oracle は JA16SJIS(Shift-JIS)格納、アプリ/HTTP は UTF-8(GixSQL/OCI ドライバが
   クライアント文字セットを UTF-8 に強制)。JEF EBCDIC / 独自エンコーダは使わない。
2. **口座番号桁**: フロント・DB とも **7桁 `KOUZA_NO`**(`NUMBER`)で整合済み。
3. **凍結(状態9)規則**: 一貫方針として「凍結=入出金・振込すべて拒否(409)」を採用。
4. **拡張機能のスキーマ**: ローン/公知/プロフィールも通常型。
   `HOLDINGS` は 1口座=1要素の最小実装(顧客IDでの複数口座束ねは未実装)。
5. **CGI 実行基盤**: nginx 単体は CGI 不可のため fcgiwrap 経由。POST body 読取は
   単一行前提(urlencoded/JSON)。

---

## 9. 主要ファイル早見

| 目的 | ファイル |
|---|---|
| レコード定義 | `cobol/copy/KKOUZA.cpy` `KTORIHK.cpy` `WTRDAT.cpy` `WMEISAI.cpy` |
| 残高/入金/出金/振込/明細 | `cobol/ZANDAKA.cbl` `NYUKIN.cbl` `SHUKKIN.cbl` `FURIKOMI.cbl` `MEISAI.cbl` |
| バッチ(反映 + 利息) | `cobol/YAKANBAT.cbl` |
| CGI 共通 | `cobol/CGIUTIL.cbl`(CGIINIT/CGIPARM/CGIRESP) |
| DDL/シード/リセット | `sql/01_ddl.sql` `02_seed.sql` `99_reset.sql` |
| Oracle JA16SJIS イメージ | `docker/Dockerfile.oracle-sjis` `docker/oracle-sjis/build-sjis-db.sh` `docker/oracle-sjis/mkuser.sql` |
