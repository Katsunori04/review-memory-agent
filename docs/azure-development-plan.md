# Azure 設計計画・開発手順書

## 1. 目的

このドキュメントは、Review Memory Agent を Azure 上に **最低限の費用で段階的に載せる** ための設計計画と開発手順を整理したものである。

以下を対象にする。

- 今のコードベースで何を先に作るか
- どの Azure リソースをいつ有効化するか
- ローカル開発から Azure デプロイまでの手順
- MVP 時点のスケール方針

関連ドキュメント:

- `docs/azure-architecture.md`: フル構成寄りの Azure 構成案
- `docs/infrastructure-implementation-guide.md`: リソース一覧と命名規約
- `docs/implementation-guide.md`: API / Worker の実装方針
- `azure.yaml`: `azd` のサービス定義
- `infra/main.bicep`: 現在の IaC エントリーポイント

---

## 2. 現在の前提

現在のリポジトリでは、まず Azure に最小構成でデプロイできることを優先している。

既定リージョンは `eastus2` とする。

理由:

- US 系リージョンの中で比較的コストを抑えやすい
- `Azure Functions Flex Consumption` の採用候補として扱いやすい
- 後から `Document Intelligence` や `Azure OpenAI` を追加する際の移行リスクを下げやすい
- 最安値だけを優先して対応サービスが不足するリージョンを選ぶより、安全に始めやすい

そのため IaC の既定値は以下になっている。

- フロントエンド: `Azure Static Web Apps Free`
- API / Worker: `Azure Functions Flex Consumption`
- Functions メモリ: `512MB`
- Always Ready: `0`
- Storage: 有効
- Cosmos DB: 無効
- Document Intelligence: 無効
- Azure AI Foundry: 無効
- Azure OpenAI: 無効
- Key Vault: 無効
- Application Insights / Log Analytics: 無効
- Static Web Apps と Functions の linked backend: 無効

つまり、**最初の到達点は「画面と最小 API を Azure に安く置けること」** である。

---

## 3. 段階導入の設計計画

### 3.1 Phase 0: 最小 Azure 配置

目的:

- Azure にデプロイ導線を作る
- 定常的な固定費を極力発生させない
- デプロイと疎通の失敗箇所を早く潰す

作成対象:

- `Static Web Apps Free`
- `Functions Flex Consumption`
- `Storage Account`

この段階で確認すること:

- `azd provision` が成功する
- `azd deploy` で `prototype/` と `api/` が載る
- `GET /api/health` が返る

### 3.2 Phase 1: 永続化の追加

目的:

- 文書メタデータやジョブ状態を保存できるようにする
- 非同期処理の実装を進められるようにする

追加対象:

- `Cosmos DB for NoSQL`
- 必要に応じて `Application Insights`

この段階で実装すること:

- `documents`
- `review_jobs`
- `reviews`
- `memory_*` 系コンテナ
- Queue を使ったジョブ投入

### 3.3 Phase 2: 文書解析の追加

目的:

- PDF / Office ファイルから本文抽出できるようにする

追加対象:

- `Azure AI Document Intelligence`

この段階で実装すること:

- アップロード API
- Blob 保存
- `document-analysis` Queue
- 抽出結果の保存

### 3.4 Phase 3: レビュー AI の追加

目的:

- Agentic Review を段階的に有効化する

追加対象:

- `Azure AI Foundry`
- `Azure OpenAI`
- 必要であれば `Key Vault`

この段階で実装すること:

- 分類
- Memory 検索
- 指摘生成
- レビュー統合

### 3.5 Phase 4: 統合と運用調整

目的:

- MVP として業務試行できる状態にする

調整対象:

- SWA と Functions の接続方式見直し
- 監視
- リトライ
- タイムアウト
- 実行コストの観測

---

## 4. 現時点の目標アーキテクチャ

### 4.1 最小構成

```text
Browser
  -> Static Web Apps Free
  -> Azure Functions Flex Consumption
  -> Storage Account
```

役割:

- `Static Web Apps`: プロトタイプ画面の配信
- `Functions`: API と最小バックエンド
- `Storage`: Functions 実行基盤、将来の Blob / Queue の兼用先

### 4.2 拡張後の構成

```text
Browser
  -> Static Web Apps
  -> Azure Functions
     -> Blob Storage
     -> Queue Storage
     -> Cosmos DB
     -> Document Intelligence
     -> Azure AI Foundry
     -> Azure OpenAI
```

方針:

- まず最小構成で動かす
- 必要になるまで AI 系リソースは作らない
- 先に API 契約とジョブ導線を固める

---

## 5. 開発ワークストリーム

### 5.1 インフラ

担当範囲:

- `azure.yaml`
- `infra/main.bicep`
- `infra/modules/*.bicep`

作業項目:

- 低コスト既定値の維持
- 機能フラグ型の resource enable/disable
- 命名規約の統一
- Azure 依存の設定値整理

### 5.2 API / Functions

担当範囲:

- `api/function_app.py`
- `api/host.json`
- 今後の `api/blueprints/*`

作業項目:

- `health` API
- `files` API
- `reviews` API
- Queue 起動
- エラーハンドリング

### 5.3 データモデル

担当範囲:

- `api/models/*`
- Cosmos のコンテナ設計

作業項目:

- 文書レコード
- レビュージョブ
- レビュー結果
- Memory カード

### 5.4 AI / 非同期処理

担当範囲:

- `api/agents/*`
- `api/infra/*`
- Queue worker

作業項目:

- 文書解析 worker
- レビュー worker
- AI 呼び出しラッパー
- リトライと step 更新

---

## 6. 開発手順

### 6.1 ローカル初期セットアップ

前提:

- Python `3.12`
- `uv`
- Azure CLI
- Azure Developer CLI (`azd`)
- Azure Functions Core Tools

推奨手順:

```bash
cd /Users/katsunori/Workspace/Apps/review-memory-agent
uv sync --project api
```

ローカル Functions 用の設定例:

`api/local.settings.json.example` を追加する運用にして、機密値はコミットしない。

最小例:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "python"
  }
}
```

### 6.2 ローカル実行

Functions:

```bash
cd api
func start
```

確認:

- `GET http://localhost:7071/api/health`

フロント:

- 当面は `prototype/index.html` を直接開いて確認

### 6.3 Azure 最小デプロイ

```bash
azd auth login
azd env new dev
azd env set AZURE_LOCATION eastus2
azd env set AZURE_ENV_NAME dev
azd env set RESOURCE_SUFFIX a1
azd provision
azd deploy
```

確認項目:

- Static Web Apps が開ける
- Functions の `health` が返る
- デプロイエラー時に Storage / Functions の設定不整合がない

リージョン方針:

- 既定は `eastus2`
- 代替候補は `centralus`
- 特別な理由がない限り、まずは `eastus2` を使う

### 6.4 機能を後から有効化する手順

必要になった時だけ、Bicep のパラメータ既定値を切り替えるか、`main.parameters.json` に環境変数マッピングを追加する。

有効化候補:

- `enableMonitoring`
- `enableCosmos`
- `enableDocumentIntelligence`
- `enableFoundry`
- `enableOpenAI`
- `enableKeyVault`
- `linkFunctionToStaticWebApp`

運用ルール:

- 新機能を有効化する前に、その機能を使うコードを先に入れる
- 使わない期間は無効のままにする
- 検証後にコスト確認を行う

---

## 7. スケール方針

### 7.1 基本方針

MVP のスケール方針は、**性能最適化よりもコスト抑制と失敗箇所の単純化を優先する**。

そのため初期値は以下とする。

- Functions プラン: `Flex Consumption`
- メモリサイズ: `512MB`
- Always Ready: `0`
- API と Worker は同一 Function App
- Queue ベースで重い処理を非同期化

### 7.2 同期処理の方針

同期 HTTP API では以下だけを行う。

- バリデーション
- ID 発行
- 永続化の初期登録
- Queue 投入
- 即時レスポンス

避けること:

- 長い LLM 呼び出し
- 文書全文解析
- 重いファイル変換
- 多段リトライ

### 7.3 非同期処理の方針

Queue Trigger に寄せる対象:

- 文書解析
- レビュー実行
- Memory 抽出

理由:

- HTTP タイムアウトを避ける
- 再実行しやすい
- ピーク時の負荷吸収がしやすい

### 7.4 スケールアップ / スケールアウト方針

初期:

- `512MB`
- `always ready 0`

症状が出たら次を順に検討する。

1. HTTP 処理をさらに短くする
2. Queue 化できる処理を同期 API から外す
3. Functions メモリを `2048MB` に上げる
4. API App と Worker App を分離する
5. 必要なら監視を有効化してボトルネックを計測する

いきなりやらないこと:

- Always Ready の有効化
- Premium 相当の常時課金寄り構成
- 複数 App への早期分割

### 7.5 データストアのスケール方針

Cosmos DB を使う段階では、まず `Serverless` 前提で始める。

判断基準:

- 少量トラフィックで断続的なら `Serverless` 継続
- 継続的な高負荷や高頻度検索が出たら provisioned throughput を再評価

Memory 検索について:

- 最初は `memory_cards` のみをベクトル検索対象にする
- `documents` など他コンテナには検索最適化を広げない

### 7.6 監視のスケール方針

初期は Monitor 無効で始めるが、以下の条件で有効化する。

- デプロイ後の失敗原因が見えない
- Queue worker の失敗追跡が必要
- AI 呼び出し時間の観測が必要

有効化後も注意すること:

- 不要ログを増やしすぎない
- 詳細本文ログを保存しない
- まず job id と status 遷移だけを追う

---

## 8. 実装順序

推奨順:

1. `health` API を維持したまま Azure 最小デプロイを安定化
2. `POST /api/files` の受け口と Blob 保存を実装
3. Queue 投入と worker の骨組みを実装
4. Cosmos を有効化し、job 状態管理を追加
5. Document Intelligence を有効化し、抽出処理を追加
6. Foundry / OpenAI を有効化し、レビュー処理を追加
7. 必要に応じて監視と Key Vault を追加

---

## 9. 受け入れ条件

### 9.1 Phase 0

- `azd provision` が成功する
- `azd deploy` が成功する
- SWA と Functions の最低限の疎通が確認できる

### 9.2 Phase 1

- ジョブ状態が永続化される
- Queue 起動が確認できる

### 9.3 Phase 2

- 1 ファイル以上の本文抽出が成功する
- 抽出結果の再取得ができる

### 9.4 Phase 3

- レビュー実行から結果保存までが通る
- 失敗時に job status が追える

---

## 10. 今後の見直しポイント

- `Static Web Apps Free` のままでよいか
- BYO backend 連携のために `Standard` へ上げるか
- API App と Worker App を分離するか
- Monitor を常時有効化するか
- Key Vault を導入するほど秘密情報が増えたか
- Cosmos DB の `Serverless` で十分か

現時点では、**先に安く動かし、必要が確認されたものだけを足す** 方針を維持する。
