# Review Memory Agent

正式レビュー前の資料チェックを支援し、上司や会議で受けた指摘を次回のチェック観点として活用するプロトタイプです。

## Prototype

ブラウザで以下を開くと画面プロトタイプを確認できます。

```text
prototype/index.html
```

## Documents

- `docs/concept.md`: コンセプト
- `docs/mvp.md`: MVPの機能とユーザー動線
- `docs/*-detailed-design.md`: 詳細設計
- `docs/azure-architecture.md`: Azure構成
- `docs/infrastructure-implementation-guide.md`: Azure インフラ実装ガイド
- `docs/azure-development-plan.md`: Azure 設計計画・開発手順書

## Azure Deployment

`azd` と `Bicep` で Azure リソースをプロビジョニングできるようにしてあります。

主なファイル:

- `azure.yaml`
- `infra/main.bicep`
- `infra/main.parameters.json`
- `infra/modules/*.bicep`

最小手順:

```bash
azd auth login
azd env new dev
azd env set AZURE_LOCATION eastus2
azd env set AZURE_ENV_NAME dev
azd env set RESOURCE_SUFFIX a1
azd provision
```

補足:

- 既定リージョンは `eastus2` です。安さと将来の Azure AI 系拡張の両立を優先しています。
- デフォルトは費用最小化寄りです。`Static Web Apps Free`、`Functions Flex Consumption 512MB`、`always ready 0`、`Cosmos / Document Intelligence / Foundry / OpenAI / Key Vault / Monitor` は未作成です。
- この構成で常時作成されるのは、基本的に `Static Web Apps`、`Functions`、`Storage Account` です。
- `Static Web Apps Free` では Functions の linked backend を使わない前提です。必要になった時だけ `Standard` と `link backend` を有効化してください。

追加機能を使う時だけ `azd env set` で切り替えます。

```bash
azd env set SWA_SKU Standard
azd env set FUNC_MEMORY_MB 2048
azd env set ENABLE_MONITORING true
azd env set ENABLE_COSMOS true
azd env set ENABLE_DOCUMENT_INTELLIGENCE true
azd env set ENABLE_FOUNDRY true
azd env set ENABLE_OPENAI true
azd env set ENABLE_KEYVAULT true
azd env set LINK_FUNCTION_TO_SWA true
```

必要なら `infra/main.parameters.json` にこれらの環境変数を追加して、`azd` から直接注入する運用に広げてください。現状は最低限デプロイを優先して、Bicep 側のデフォルトで安く倒しています。
