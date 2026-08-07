# docker/vendor/ — ベンダー成果物 配置場所

`Dockerfile.asis` がビルド時に**このフォルダから**コピーする、再配布不可の
外部成果物を置きます。**Git にはコミットしません**(`.gitignore` 済み)。

## 配置するファイル

| ファイル名 | 内容 | 入手先 |
|---|---|---|
| `instantclient-basic-linux.x64-23.26.0.0.0.zip` | Oracle Instant Client(**Basic**、Lite不可) | Oracle 公式 Instant Client ダウンロード(Linux x86-64) |
| `instantclient-sdk-linux.x64.zip` | Instant Client SDK(ヘッダ/ライブラリ) | 同上(SDK Package) |
| `gixsql-1.0.20b.tar.gz` | GixSQL(EXEC SQL プリコンパイラ)ソース。**下の patch 適用済み** | GitHub `mridoni/gixsql` の Releases |
| `gixsql-oracle-nls-lang.patch` | 上記 tar.gz に当ててある NLS_LANG 修正パッチ(**Git 管理対象**、zip/tar.gz と違って再配布制限なし) | このリポジトリ内 |

```
backend-cobol/docker/vendor/
  ├─ instantclient-basic-linux.x64-23.26.0.0.0.zip   (.gitignore 対象)
  ├─ instantclient-sdk-linux.x64.zip                  (.gitignore 対象)
  ├─ gixsql-1.0.20b.tar.gz                            (.gitignore 対象、パッチ適用済み)
  └─ gixsql-oracle-nls-lang.patch                      (Git 管理)
```

## 入手メモ

- **Oracle Instant Client**（Linux x86-64。zip 版）
  - ★**「Basic Lite」は不可、必ず「Basic」＋「SDK」を使うこと。** Basic Lite には
    `libociei.so`(NLS 文字コード変換データ、JA16SJIS 含む)が丸ごと同梱されていない
    (実測: basiclite の zip 一覧にこのファイル自体が無い。basic では約204MB)。
    Lite だとクライアント文字セットが常に UTF-8 に強制され、バッチ/オンラインが
    Shift-JIS を扱えなくなる。
  - 検索: `Oracle Instant Client Downloads for Linux x86-64 (64-bit)`
  - 社内ミラーがある場合はそちらから取得。バージョンは SDK と同じ系列(23.26系)に揃える。
- **GixSQL**（§2 のハード制約: 1.0.18+、可能なら 1.0.20 系）
  - 検索: `github.com mridoni gixsql releases`
  - `gixsql-<version>.tar.gz` を取得。
  - ★★**必ず `gixsql-oracle-nls-lang.patch` を当ててから使うこと。** 素の GixSQL は
    Oracle 接続時に ODPI-C の `dpiCommonCreateParams` を `NULL` で渡す
    (`DbInterfaceOracle.cpp` の `connect()`)。ODPI-C はその場合
    `encoding`/`nencoding` を内部で **常に `"UTF-8"`** にデフォルト化するため
    (`odpi/dpiContext.c` の `dpiContext__initCommonCreateParams`)、**Instant
    Client を Basic に変えても・`NLS_LANG` を何に設定しても効かない**(実測で
    確認済み — Basic Lite→Basic 切替だけでは直らなかった原因はこれ)。パッチは
    `encoding`/`nencoding` を明示的に `NULL` に戻し、charset id 0 を
    `OCIEnvNlsCreate` に渡す(＝OCI が `NLS_LANG` から判断する)ようにする。
    今の vendor の `gixsql-1.0.20b.tar.gz` は**このパッチを適用済み**。新しい
    バージョンを取ってきた場合は `patch -p1 < gixsql-oracle-nls-lang.patch`
    (展開したソースのルートで)を再度当てること。

## ファイル名/バージョンが違うとき

Dockerfile 側の `ARG` を実ファイル名に合わせて上書きするか、ファイル名を
上表どおりにリネームしてください。

```dockerfile
# Dockerfile.asis 冒頭の該当 ARG
ARG GIXSQL_VER=1.0.20b
ARG INSTANTCLIENT_ZIP=instantclient-basic-linux.x64-23.26.0.0.0.zip
ARG INSTANTCLIENT_SDK=instantclient-sdk-linux.x64.zip
```

ビルド時に上書きする例:
```bash
docker compose -f backend-cobol/docker/compose.asis.yml build \
  --build-arg GIXSQL_VER=1.0.20 \
  --build-arg INSTANTCLIENT_ZIP=instantclient-basic-linux.x64-23.5.0.24.07.zip \
  --build-arg INSTANTCLIENT_SDK=instantclient-sdk-linux.x64-23.5.0.24.07.zip
```
（★Basic Lite の zip 名を入れると §入手メモ の理由でまた UTF-8 に戻るので注意）

## 配置後の実行

```bash
# リポジトリルートで
docker compose -f backend-cobol/docker/compose.asis.yml up -d --build
# → http://localhost:8092/
```
