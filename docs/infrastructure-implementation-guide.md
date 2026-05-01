# Azure インフラ実装ガイド

## 1. 目的

このドキュメントは、Review Memory Agent の MVP を `Bicep` と `azd` で実装する際に必要な、実際の Azure リソース一覧、環境変数一覧、モデルデプロイ名の命名規約を整理したものである。

前提:

- モデル基盤は `Azure AI Foundry`
- 主力モデルは `Claude Sonnet 4.6`
- 埋め込みは `Azure OpenAI text-embedding-3-small`
- API / Worker は `Azure Functions Flex Consumption`
- Memory と履歴は `Azure Cosmos DB for NoSQL`

---

## 2. `azd` の想定構成

MVPでは `azd` で以下の単位を管理する。

- 1つの Azure リソースグループ
- 1つの SPA アプリ
- 1つの Functions アプリ
- 1つの Storage Account
- 1つの Cosmos DB アカウント
- 1つの Document Intelligence リソース
- 1つの Azure AI Foundry リソース / Project
- 1つの Azure OpenAI リソース
- 1つの Key Vault
- 1つの Application Insights

推奨ディレクトリイメージ:

```text
infra/
  main.bicep
  main.parameters.json
  modules/
    networking.bicep
    storage.bicep
    functions.bicep
    cosmos.bicep
    foundry.bicep
    openai.bicep
    docintelligence.bicep
    monitoring.bicep
azure.yaml
```

---

## 3. 実際のリソース一覧

### 3.1 リソースグループ

- 種別: `Microsoft.Resources/resourceGroups`
- 用途: MVPの全リソースを集約
- 推奨名: `rg-rma-{env}-{region}`

例:

- `rg-rma-dev-eastus2`
- `rg-rma-stg-eastus2`
- `rg-rma-prod-eastus2`

### 3.2 Static Web Apps

- 種別: `Microsoft.Web/staticSites`
- 用途: フロントエンド配信
- プラン: `Standard`
- 推奨名: `stapp-rma-{env}-{suffix}`

例:

- `stapp-rma-dev-a1`

### 3.3 Functions App

- 種別: `Microsoft.Web/sites`
- 用途: HTTP API / Queue Worker
- プラン: `Flex Consumption`
- 推奨名: `func-rma-{env}-{suffix}`

補足:

- MVPでは API と Worker を同一 Function App に置く
- 将来は `func-rma-api-*` と `func-rma-job-*` に分離可能

### 3.4 Storage Account

- 種別: `Microsoft.Storage/storageAccounts`
- 用途:
  - Blob
  - Queue
  - Functions ストレージ
- SKU: `Standard_LRS`
- 推奨名: `strma{env}{suffix}`

補足:

- Azure Storage 名は英小文字・数字のみ、24文字以内
- Blob / Queue を同一アカウントで始める

### 3.5 Cosmos DB for NoSQL

- 種別: `Microsoft.DocumentDB/databaseAccounts`
- 用途:
  - `documents`
  - `review_sets`
  - `review_jobs`
  - `reviews`
  - `review_feedback`
  - `memory_sources`
  - `memory_candidates`
  - `memory_card_drafts`
  - `memory_cards`
- モード: `Serverless`
- 推奨名: `cosmos-rma-{env}-{suffix}`

### 3.6 Document Intelligence

- 種別: `Microsoft.CognitiveServices/accounts`
- kind: `FormRecognizer`
- 用途: Layout / figures 抽出
- SKU: `S0`
- 推奨名: `docint-rma-{env}-{suffix}`

### 3.7 Azure AI Foundry

- 種別:
  - `Microsoft.CognitiveServices/accounts`
  - Foundry project 関連リソース
- 用途:
  - Claude モデルデプロイ
  - Foundry project 管理
- 推奨名:
  - リソース: `aif-rma-{env}-{suffix}`
  - プロジェクト: `aifproj-rma-{env}`

補足:

- Claude の利用可否は契約条件と Marketplace 条件を事前確認する
- MVPでは Claude の呼び出し基盤として Foundry を使う

### 3.8 Azure OpenAI

- 種別: `Microsoft.CognitiveServices/accounts`
- kind: `OpenAI`
- 用途:
  - 埋め込みモデル
- 推奨名: `aoai-rma-{env}-{suffix}`

### 3.9 Key Vault

- 種別: `Microsoft.KeyVault/vaults`
- 用途:
  - APIキー
  - 接続文字列
  - エンドポイント
- 推奨名: `kv-rma-{env}-{suffix}`

### 3.10 Application Insights

- 種別: `Microsoft.Insights/components`
- 用途:
  - API / Job / LLM 呼び出しの監視
- 推奨名: `appi-rma-{env}-{suffix}`

---

## 4. Cosmos DB コンテナ一覧

MVPで作成するコンテナは以下とする。

| コンテナ | 用途 | 推奨パーティションキー |
| --- | --- | --- |
| `documents` | 主資料・添付資料メタデータ | `/reviewSetId` |
| `review_sets` | レビュー単位の親レコード | `/id` |
| `review_jobs` | レビュージョブ状態 | `/reviewSetId` |
| `reviews` | レビュー結果 | `/reviewSetId` |
| `review_feedback` | レビュー結果コメント | `/reviewSetId` |
| `memory_sources` | Memory入力元 | `/id` |
| `memory_candidates` | 抽出候補 | `/memorySourceId` |
| `memory_card_drafts` | 保存前ドラフト | `/memorySourceId` |
| `memory_cards` | 保存済みMemory | `/id` |

補足:

- `memory_cards` は専用コンテナとし、ベクトル検索ポリシーを定義する
- ベクトル検索前提のため、`memory_cards` は Shared throughput にしない

---

## 5. Storage の論理構成

Blob コンテナ:

- `documents-original`
- `documents-extracted`
- `reviews-results`
- `vision-pages`

Queue:

- `document-analysis`
- `review-jobs`

補足:

- Queue 名は Function Trigger と一致させる
- `vision-pages` は Office の PDF 化 / ページレンダリング拡張でも再利用できる

---

## 6. 環境変数一覧

### 6.1 アプリ共通

- `AZURE_ENV_NAME`
  - 例: `dev`, `stg`, `prod`
- `AZURE_LOCATION`
  - 例: `eastus2`
- `APP_BASE_URL`
  - Static Web Apps のURL

### 6.2 Storage / Queue

- `STORAGE_ACCOUNT_NAME`
- `STORAGE_BLOB_ENDPOINT`
- `STORAGE_QUEUE_ENDPOINT`
- `AZURE_STORAGE_CONNECTION_STRING`
- `BLOB_CONTAINER_DOCUMENTS_ORIGINAL`
  - 初期値: `documents-original`
- `BLOB_CONTAINER_DOCUMENTS_EXTRACTED`
  - 初期値: `documents-extracted`
- `BLOB_CONTAINER_REVIEWS_RESULTS`
  - 初期値: `reviews-results`
- `BLOB_CONTAINER_VISION_PAGES`
  - 初期値: `vision-pages`
- `QUEUE_DOCUMENT_ANALYSIS`
  - 初期値: `document-analysis`
- `QUEUE_REVIEW_JOBS`
  - 初期値: `review-jobs`

### 6.3 Cosmos DB

- `COSMOS_ENDPOINT`
- `COSMOS_DATABASE_NAME`
  - 推奨値: `review-memory-agent`
- `COSMOS_KEY`
- `COSMOS_CONTAINER_DOCUMENTS`
  - 初期値: `documents`
- `COSMOS_CONTAINER_REVIEW_SETS`
  - 初期値: `review_sets`
- `COSMOS_CONTAINER_REVIEW_JOBS`
  - 初期値: `review_jobs`
- `COSMOS_CONTAINER_REVIEWS`
  - 初期値: `reviews`
- `COSMOS_CONTAINER_REVIEW_FEEDBACK`
  - 初期値: `review_feedback`
- `COSMOS_CONTAINER_MEMORY_SOURCES`
  - 初期値: `memory_sources`
- `COSMOS_CONTAINER_MEMORY_CANDIDATES`
  - 初期値: `memory_candidates`
- `COSMOS_CONTAINER_MEMORY_CARD_DRAFTS`
  - 初期値: `memory_card_drafts`
- `COSMOS_CONTAINER_MEMORY_CARDS`
  - 初期値: `memory_cards`

### 6.4 Document Intelligence

- `DOCINT_ENDPOINT`
- `DOCINT_KEY`
- `DOCINT_API_VERSION`
  - 推奨値: 利用時点の安定版
- `DOCINT_MODEL_LAYOUT`
  - 初期値: `prebuilt-layout`
- `DOCINT_ENABLE_FIGURES`
  - 初期値: `true`

### 6.5 Azure AI Foundry / Claude

- `FOUNDRY_ENDPOINT`
- `FOUNDRY_PROJECT_NAME`
- `FOUNDRY_API_KEY`
- `FOUNDRY_CLAUDE_MAIN_DEPLOYMENT`
- `FOUNDRY_CLAUDE_FAST_DEPLOYMENT`
- `FOUNDRY_CLAUDE_REASONING_DEPLOYMENT`
- `FOUNDRY_API_VERSION`

### 6.6 Azure OpenAI Embeddings

- `AZURE_OPENAI_ENDPOINT`
- `AZURE_OPENAI_API_KEY`
- `AZURE_OPENAI_API_VERSION`
- `AZURE_OPENAI_EMBEDDING_DEPLOYMENT`

### 6.7 Monitoring

- `APPLICATIONINSIGHTS_CONNECTION_STRING`
- `LOG_LEVEL`
  - 推奨初期値: `Information`

### 6.8 Feature Flags

- `FEATURE_ENABLE_MULTIMODAL_DIAGRAM`
  - 初期値: `true`
- `FEATURE_ENABLE_REVIEW_RERUN`
  - 初期値: `true`
- `FEATURE_ENABLE_MEMORY_SEARCH`
  - 初期値: `true`

---

## 7. Key Vault に入れる値

Key Vault 管理対象:

- `AZURE-STORAGE-CONNECTION-STRING`
- `COSMOS-KEY`
- `DOCINT-KEY`
- `FOUNDRY-API-KEY`
- `AZURE-OPENAI-API-KEY`
- `APPLICATIONINSIGHTS-CONNECTION-STRING`

原則:

- `endpoint` やコンテナ名は環境変数
- `key` や接続文字列は Key Vault

---

## 8. モデルデプロイ名の命名規約

### 8.1 方針

モデルデプロイ名は、用途が分かるように **モデル名そのものではなく役割名** に寄せる。

理由:

- モデルの実体を差し替えてもアプリ側コードを変えにくくできる
- Sonnet / Haiku / Opus の入れ替えをしやすい

### 8.2 Claude デプロイ名

推奨:

- `claude-main`
- `claude-fast`
- `claude-reasoning`

対応:

- `claude-main` -> `claude-sonnet-4-6`
- `claude-fast` -> `claude-haiku-4-5`
- `claude-reasoning` -> `claude-opus-4-6`

### 8.3 Embeddings デプロイ名

推奨:

- `text-embedding-main`

対応:

- `text-embedding-main` -> `text-embedding-3-small`

### 8.4 参照ルール

コード上は以下の環境変数だけを見る。

- `FOUNDRY_CLAUDE_MAIN_DEPLOYMENT`
- `FOUNDRY_CLAUDE_FAST_DEPLOYMENT`
- `FOUNDRY_CLAUDE_REASONING_DEPLOYMENT`
- `AZURE_OPENAI_EMBEDDING_DEPLOYMENT`

ハードコードしない。

---

## 9. リソース命名規約

### 9.1 共通

フォーマット:

```text
{type}-rma-{env}-{suffix}
```

例:

- `func-rma-dev-a1`
- `docint-rma-stg-a1`
- `cosmos-rma-prod-a1`

`type` の推奨値:

- `rg`
- `stapp`
- `func`
- `docint`
- `aif`
- `aoai`
- `kv`
- `appi`
- `cosmos`

### 9.2 文字数制約が厳しいもの

Storage Account は以下ルールにする。

```text
strma{env}{suffix}
```

例:

- `strmadeva1`
- `strmastga1`

---

## 10. `azd` パラメータの最小セット

推奨 `azd env` 変数:

- `AZURE_LOCATION=eastus2`
- `AZURE_ENV_NAME=dev`
- `RESOURCE_SUFFIX=a1`
- `COSMOS_DATABASE_NAME=review-memory-agent`
- `FUNC_MEMORY_MB=2048`
- `FUNC_ALWAYS_READY=0`
- `SWA_SKU=Standard`
- `DOCINT_SKU=S0`

モデル関連:

- `FOUNDRY_CLAUDE_MAIN_DEPLOYMENT=claude-main`
- `FOUNDRY_CLAUDE_FAST_DEPLOYMENT=claude-fast`
- `FOUNDRY_CLAUDE_REASONING_DEPLOYMENT=claude-reasoning`
- `AZURE_OPENAI_EMBEDDING_DEPLOYMENT=text-embedding-main`

---

## 11. Bicep 実装ルール

### 11.1 分割方針

`main.bicep` から以下の module を呼ぶ。

- `storage.bicep`
- `functions.bicep`
- `cosmos.bicep`
- `docintelligence.bicep`
- `foundry.bicep`
- `openai.bicep`
- `monitoring.bicep`
- `keyvault.bicep`
- `staticwebapp.bicep`

### 11.2 出力するべき値

各 module は少なくとも以下を `output` する。

- リソース名
- エンドポイント
- 接続先 URI
- アプリ設定に必要な名前

### 11.3 アプリ設定反映

Functions App の app settings には、Bicep から以下を直接流し込む。

- エンドポイント
- コンテナ名
- キュー名
- デプロイ名

秘密値は Key Vault reference を優先する。

---

## 12. 受け入れ条件

- `azd up` で MVPに必要な Azure リソース一式を作成できる
- Functions App に必要な app settings が揃う
- Claude 用 Foundry デプロイ名と埋め込みデプロイ名が規約に沿って定義される
- Cosmos DB の必要コンテナが作成される
- `memory_cards` コンテナにベクトル検索ポリシーを設定できる
- Blob / Queue 名がアプリ設定と一致する

---

## 13. 今後の拡張候補

- API App と Worker App の分離
- dev / stg / prod の Foundry project 分離
- Key Vault reference の完全自動配線
- Private Endpoint 追加
- Managed Identity 前提への移行
