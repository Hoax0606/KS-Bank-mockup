# docker/vendor/ — ベンダー成果物 配置場所

`Dockerfile.asis` がビルド時に**このフォルダから**コピーする、再配布不可の
外部成果物を置きます。**Git にはコミットしません**(`.gitignore` 済み)。

## 配置する 3 ファイル

| ファイル名 | 内容 | 入手先 |
|---|---|---|
| `instantclient-basiclite-linux.x64.zip` | Oracle Instant Client(Basic Lite) | Oracle 公式 Instant Client ダウンロード(Linux x86-64) |
| `instantclient-sdk-linux.x64.zip` | Instant Client SDK(ヘッダ/ライブラリ) | 同上(SDK Package) |
| `gixsql-1.0.20b.tar.gz` | GixSQL(EXEC SQL プリコンパイラ)ソース | GitHub `mridoni/gixsql` の Releases |

```
backend-cobol/docker/vendor/
  ├─ instantclient-basiclite-linux.x64.zip
  ├─ instantclient-sdk-linux.x64.zip
  └─ gixsql-1.0.20b.tar.gz
```

## 入手メモ

- **Oracle Instant Client**（Linux x86-64。zip 版）
  - 「Basic」または「Basic Lite」＋「SDK」の 2 つが必要。
  - 検索: `Oracle Instant Client Downloads for Linux x86-64 (64-bit)`
  - 社内ミラーがある場合はそちらから取得。
- **GixSQL**（§2 のハード制約: 1.0.18+、可能なら 1.0.20 系）
  - 検索: `github.com mridoni gixsql releases`
  - `gixsql-<version>.tar.gz` を取得。

## ファイル名/バージョンが違うとき

Dockerfile 側の `ARG` を実ファイル名に合わせて上書きするか、ファイル名を
上表どおりにリネームしてください。

```dockerfile
# Dockerfile.asis 冒頭の該当 ARG
ARG GIXSQL_VER=1.0.20
ARG INSTANTCLIENT_ZIP=instantclient-basiclite-linux.x64.zip
ARG INSTANTCLIENT_SDK=instantclient-sdk-linux.x64.zip
```

ビルド時に上書きする例:
```bash
docker compose -f backend-cobol/docker/compose.asis.yml build \
  --build-arg GIXSQL_VER=1.0.20 \
  --build-arg INSTANTCLIENT_ZIP=instantclient-basiclite-linux.x64-23.5.0.24.07.zip \
  --build-arg INSTANTCLIENT_SDK=instantclient-sdk-linux.x64-23.5.0.24.07.zip
```

## 配置後の実行

```bash
# リポジトリルートで
docker compose -f backend-cobol/docker/compose.asis.yml up -d --build
# → http://localhost:8080/
```
