# Azure コンポーネント / モデル採用方針

## 1. 目的

このドキュメントは、Review Memory Agent の MVP で採用する Azure コンポーネント、プラン、モデルを整理したものである。

判断基準は以下とする。

- 2026-05-02 時点での公式情報に基づくこと
- MVP / 社内PoCとして過不足がないこと
- 将来の本番化に無理なく拡張できること
- コスト、実装容易性、性能のバランスがよいこと

---

## 2. 結論

MVPで採用する主な構成は以下とする。

- フロントエンド: `Azure Static Web Apps Standard`
- API / Worker: `Azure Functions Flex Consumption`
- 文書保存: `Azure Storage Account (GPv2 / Hot / LRS)`
- 文書解析: `Azure AI Document Intelligence S0`
- モデル基盤: `Azure AI Foundry`
- LLM（主力）: `Claude Sonnet 4.6`
- LLM（軽量補助）: `Claude Haiku 4.5`
- LLM（高度推論が必要な時の拡張候補）: `Claude Opus 4.6`
- 埋め込み: `Azure OpenAI text-embedding-3-small`
- Memory / 履歴DB: `Azure Cosmos DB for NoSQL (Serverless)`
- 監視: `Application Insights`
- 秘密情報管理: `Azure Key Vault`

---

## 3. 採用コンポーネント

### 3.1 フロントエンド

採用:

- `Azure Static Web Apps Standard`

理由:

- 今回は `Bring your own Functions app` 構成を前提にしている
- 公式のプラン比較では、既存の Azure Functions アプリを使う場合や HTTP 以外の Functions を使う場合は Standard が適している
- Free は managed Functions 前提の用途に寄るため、今回の Queue / Worker 分離構成と相性がよくない

不採用:

- `Static Web Apps Free`
  - コストは低いが、今回の API / Worker 分離構成に合わない

### 3.2 API / Worker

採用:

- `Azure Functions Flex Consumption`
- インスタンスサイズは `2048 MB` を基本値とする

理由:

- Microsoft Learn では Flex Consumption が Azure Functions の推奨サーバレスプラン
- Consumption は legacy 扱い
- Queue Trigger / HTTP Trigger を同一スタックで扱いやすい
- Always Ready を必要に応じて付けられる

初期設定:

- 開発 / 検証環境: `Always Ready = 0`
- デモ / 本番PoC環境: HTTPグループに `Always Ready = 1` を検討

補足:

- 文書解析やマルチモーダル処理のため、メモリは `512 MB` ではなく `2048 MB` を標準にする
- まずは 1 アプリで開始し、必要になったら API 系と Worker 系を分離する

### 3.3 ストレージ

採用:

- `Azure Storage Account (General-purpose v2)`
- Blob: `Hot`
- 冗長性: `LRS`

理由:

- MVPでは原本、抽出JSON、レビュー結果JSONの保存が主用途
- 可用性や災害対策より、コストと単純さを優先する
- 将来は要件に応じて `ZRS` や `GRS` に拡張可能

---

## 4. AI / モデル採用

### 4.1 モデル基盤

採用:

- `Azure AI Foundry`
- `Anthropic Claude models in Foundry`

理由:

- ユーザー要件として Claude を主力にしたい
- Microsoft Learn では Claude は Foundry で利用可能
- Claude は Global Standard deployment で提供される
- Claude は長文読解、推論、コード生成、画像入力に対応し、本プロダクトの Review / Memory / Apply と相性がよい

重要な前提:

- Claude は `Azure OpenAI` ではなく `Azure AI Foundry` 経由で使う
- 2026-05-02 時点の公式記事では Claude は preview
- 同記事では Claude 利用は Enterprise / MCA-E の条件が明記されているため、契約条件は事前確認が必要

### 4.2 主力モデル

採用:

- `claude-sonnet-4-6`

用途:

- Document Classifier Agent
- Memory Extraction Agent
- Memory Card Generation Agent
- Memory Retrieval の条件整合判定
- Review Critique Agent
- Review Synthesizer Agent
- Multimodal Diagram Agent

理由:

- Claude 系の中で、性能とコストのバランスがよい主力候補
- 画像とテキストの両方を扱えるため、図解釈も1系統に寄せやすい
- Review / Memory / Apply の大半を1モデル系列に統一できる

### 4.3 軽量補助モデル

採用:

- `claude-haiku-4-5`

用途:

- 軽い要約
- 前処理
- 低コストな下書き生成
- レイテンシ優先の補助処理

理由:

- Sonnet を常に使うよりコストを抑えやすい
- 高速応答が欲しい前処理タスクに向く

### 4.4 高度推論の拡張候補

採用候補:

- `claude-opus-4-6`

用途:

- 将来、複雑な統合判断や難しいレビューケースでのみ限定利用

理由:

- 高性能だが、MVPの全面適用には過剰で高コストになりやすい
- 初期構成では必須にしない

### 4.5 埋め込みモデル

採用:

- `Azure OpenAI text-embedding-3-small`

用途:

- `memory_cards` の埋め込み生成
- Review 時の類似検索クエリ生成

理由:

- Claude を主力にしても、埋め込みは Azure OpenAI を併用するのが実装しやすい
- `text-embedding-3-small` は多言語検索で十分実用的
- MVPでは Memory 件数がまだ少ないため、まずはコスト効率を優先する
- 出力次元は `1536` で扱いやすい

将来の切り替え条件:

- Memory件数が増えて検索ミスが目立つ
- 日本語の意味検索精度をさらに上げたい

この場合は `text-embedding-3-large` へ再埋め込みを検討する。

---

## 5. Document Intelligence 採用方針

### 5.1 プラン

採用:

- `Azure AI Document Intelligence S0`

理由:

- F0 は 2ページ / 4MB / 1 TPS 制限が強く、実利用やデモに向かない
- S0 は 500MB、2000ページ、15 TPS が初期値で、MVPには十分

### 5.2 モデル

採用:

- `Layout model (v4.0 GA)`
- 必要に応じて `output=figures`

理由:

- ページ、段落、表、セクション、figure を取れる
- figures は切り出し画像取得にも使える
- Review / Apply の前処理として最も相性がよい

### 5.3 Office 文書の重要な注意点

重要:

- 最新の v4.0 GA の公式ドキュメントでは、Office ファイルについて embedded / linked images はサポートされない
- Word / Excel / PowerPoint / HTML は、埋め込みテキスト抽出はできるが、埋め込み画像の解析は前提にできない

したがって、MVPでは以下を採用する。

- 図や画像の理解が重要な資料は **PDF を推奨入力形式** にする
- `DOCX / PPTX / XLSX` は、まずテキスト抽出に使う
- 図解釈が必要な Office 資料は、別途 PDF 化またはページレンダリングして Vision に渡す拡張を前提にする

---

## 6. Cosmos DB 採用方針

### 6.1 アカウント種別

採用:

- `Azure Cosmos DB for NoSQL`
- `Serverless`

理由:

- MVPではアクセス量がまだ小さい前提
- Serverless は使った分だけ課金で、初期コストを抑えやすい
- Memory、レビュー履歴、ドキュメントメタデータを1つのDB系統で扱える

本番化時の切り替え候補:

- 同時利用者が増える
- ベクトル検索のRU消費が増える
- レイテンシを安定させたい

この場合は `Autoscale` へ移行を検討する。

### 6.2 ベクトル検索

採用:

- `Vector Search for NoSQL`
- 初期インデックスは `quantizedFlat`

理由:

- 公式では `quantizedFlat` は 4,096 次元まで対応
- 公式では比較的小規模のシナリオや 50,000 ベクトル程度までに向く
- MVPの Memory 件数と相性がよい

補足:

- `flat` は 505 次元までなので今回使わない
- `diskANN` は将来の大規模化時の候補
- ベクトルポリシーとベクトルインデックスは作成後に変更できないため、専用コンテナを前提に作る
- Shared throughput は使わない

---

## 7. Azure AI Foundry / Claude のデプロイ種別

採用:

- `Global Standard`

理由:

- Claude の公式 Foundry 記事では Global Standard deployment で提供される
- ユーザー要件としてリージョン固定にこだわらない
- したがって、Claude 優先なら Global Standard を前提にするのが自然

使い分け:

- Claude 主力: `Global Standard`
- 埋め込み用 Azure OpenAI: 同一アーキテクチャ内で Standard または利用可能なデプロイ種別を選ぶ

---

## 8. リージョン方針

推奨:

- 第一候補: `East US2`
- 代替候補: `Sweden Central`

理由:

- Claude の Foundry 記事では Foundry project の前提リージョンとして East US2 / Sweden Central が案内されている
- ユーザー条件としてリージョン制約がない
- Claude を最優先するなら、まず公式案内に寄せるのが安全

補足:

- Claude と埋め込み用 Azure OpenAI を同一リージョンで揃えられない場合がある
- その場合は Foundry と Azure OpenAI を別リソース / 別リージョンで持つことを許容する

---

## 9. 今回採用しないもの

- `Azure AI Search`
  - 今回は Cosmos DB 単体で完結させる
- `Azure AI Foundry Agent Service`
  - 2026-05-02 時点の公式情報では Agent Service の対応は Azure OpenAI 系中心で、Claude 主力構成と合わせにくい
  - 今回は Azure Functions 側で自前オーケストレーションする
- `Azure Container Apps`
  - Functions Flex Consumption で十分
- `Static Web Apps Free`
  - BYO Functions 前提と合わない
- `Document Intelligence F0`
  - 制限が強すぎる

---

## 10. 最終採用一覧

| 領域 | 採用 |
| --- | --- |
| フロント | Azure Static Web Apps Standard |
| API / Worker | Azure Functions Flex Consumption |
| Functions 初期メモリ | 2048 MB |
| Functions Always Ready | dev=0 / demo-prod=1検討 |
| ストレージ | Storage Account GPv2 / Hot / LRS |
| 文書解析 | Azure AI Document Intelligence S0 |
| レイアウト抽出 | Layout model v4.0 GA |
| モデル基盤 | Azure AI Foundry |
| テキスト主力モデル | Claude Sonnet 4.6 |
| 軽量補助モデル | Claude Haiku 4.5 |
| 高度推論の拡張候補 | Claude Opus 4.6 |
| 埋め込みモデル | Azure OpenAI text-embedding-3-small |
| DB | Azure Cosmos DB for NoSQL Serverless |
| ベクトルインデックス | quantizedFlat |
| 監視 | Application Insights |
| 秘密情報 | Key Vault |
| Claude デプロイ種別 | Global Standard |
| 推奨リージョン | East US2 |

---

## 11. 参考ソース

- Azure Static Web Apps hosting plans  
  https://learn.microsoft.com/en-us/azure/static-web-apps/plans
- Azure Functions Flex Consumption plan hosting  
  https://learn.microsoft.com/en-us/azure/azure-functions/flex-consumption-plan
- Azure Functions hosting options  
  https://learn.microsoft.com/en-us/azure/azure-functions/functions-scale
- Deploy and use Claude models in Microsoft Foundry  
  https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/how-to/use-foundry-models-claude
- Foundry deployment types  
  https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/concepts/deployment-types
- Foundry partner/community models  
  https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/concepts/models-from-partners
- Foundry Agent Service supported models  
  https://learn.microsoft.com/en-us/azure/ai-services/agents/concepts/model-region-support
- Azure OpenAI embeddings  
  https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/embeddings
- Document Intelligence layout model  
  https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/prebuilt/layout
- Document Intelligence service limits  
  https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/service-limits
- Document Intelligence pricing  
  https://azure.microsoft.com/en-us/pricing/details/ai-document-intelligence/
- Cosmos DB vector search for NoSQL  
  https://learn.microsoft.com/en-gb/azure/cosmos-db/nosql/vector-search
- Cosmos DB vector index policy  
  https://learn.microsoft.com/en-us/azure/cosmos-db/index-policy
- Cosmos DB serverless  
  https://learn.microsoft.com/en-us/azure/cosmos-db/serverless
- Cosmos DB autoscale throughput  
  https://learn.microsoft.com/en-us/azure/cosmos-db/provision-throughput-autoscale
