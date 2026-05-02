# 実装方針ガイド

## 1. 目的

このドキュメントは、Review Memory Agent の API / Worker 実装に関する技術方針を定めたものである。

アーキテクチャの判断は `docs/azure-architecture.md` を参照する。
採用コンポーネントとモデルの判断は `docs/azure-component-decisions.md` を参照する。
インフラリソースと環境変数の一覧は `docs/infrastructure-implementation-guide.md` を参照する。

---

## 2. 言語・ランタイム

- Python `3.12`
- Azure Functions v2 プログラミングモデル（デコレーターベース）
- パッケージ管理: `uv`

---

## 3. ディレクトリ構成

```
api/
  function_app.py              # エントリーポイント（Blueprint 登録）
  host.json
  local.settings.json.example
  pyproject.toml

  blueprints/                  # HTTP / Queue トリガーの登録
    review_sets.py             # POST/GET /api/review-sets
    reviews.py                 # POST/GET /api/reviews, /feedback, /rerun
    memories.py                # GET/POST /api/memories
    document_worker.py         # Queue: document-analysis
    review_worker.py           # Queue: review-jobs

  agents/                      # 各エージェントの実装
    classifier.py              # Document Classifier Agent
    memory_retrieval.py        # Memory Retrieval Agent
    multimodal.py              # Multimodal Diagram Agent
    critique.py                # Review Critique Agent
    synthesizer.py             # Review Synthesizer Agent

  models/                      # Pydantic モデル（入出力の型定義）
    documents.py
    reviews.py
    memory.py
    jobs.py

  infra/                       # 外部サービスクライアント
    foundry.py                 # Anthropic SDK (Azure AI Foundry 経由)
    cosmos.py                  # Cosmos DB
    blob.py                    # Blob Storage
    queue.py                   # Queue Storage
    docint.py                  # Document Intelligence
    embeddings.py              # Azure OpenAI Embeddings
```

---

## 4. Azure Functions v2 構成

### 4.1 エントリーポイント

```python
# function_app.py
import azure.functions as func
from blueprints.review_sets import bp as review_sets_bp
from blueprints.reviews import bp as reviews_bp
from blueprints.memories import bp as memories_bp
from blueprints.document_worker import bp as document_worker_bp
from blueprints.review_worker import bp as review_worker_bp

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)
app.register_blueprint(review_sets_bp)
app.register_blueprint(reviews_bp)
app.register_blueprint(memories_bp)
app.register_blueprint(document_worker_bp)
app.register_blueprint(review_worker_bp)
```

### 4.2 HTTP トリガー（Blueprint）

```python
# blueprints/review_sets.py
import azure.functions as func
import json

bp = func.Blueprint()

@bp.route(route="review-sets", methods=["POST"])
async def create_review_set(req: func.HttpRequest) -> func.HttpResponse:
    body = req.get_json()
    # ...
    return func.HttpResponse(json.dumps(result), mimetype="application/json", status_code=201)
```

### 4.3 Queue トリガー（Blueprint）

```python
# blueprints/review_worker.py
import azure.functions as func
import json

bp = func.Blueprint()

@bp.queue_trigger(
    arg_name="msg",
    queue_name="%QUEUE_REVIEW_JOBS%",
    connection="AZURE_STORAGE_CONNECTION_STRING",
)
async def run_review_job(msg: func.QueueMessage) -> None:
    payload = json.loads(msg.get_body())
    await orchestrate_review(payload["reviewJobId"])
```

---

## 5. Claude クライアント（infra/foundry.py）

Azure AI Foundry では Anthropic SDK の `base_url` を差し替えるだけで動作する。

```python
import anthropic
import os
from functools import lru_cache

@lru_cache(maxsize=1)
def get_client() -> anthropic.Anthropic:
    return anthropic.Anthropic(
        api_key=os.environ["FOUNDRY_API_KEY"],
        base_url=os.environ["FOUNDRY_ENDPOINT"],
    )

MAIN_MODEL     = os.environ.get("FOUNDRY_CLAUDE_MAIN_DEPLOYMENT", "claude-main")
FAST_MODEL     = os.environ.get("FOUNDRY_CLAUDE_FAST_DEPLOYMENT", "claude-fast")
REASONING_MODEL = os.environ.get("FOUNDRY_CLAUDE_REASONING_DEPLOYMENT", "claude-reasoning")
```

- モデル名はすべて環境変数経由で参照する（ハードコード禁止）
- クライアントは `lru_cache` で1インスタンスに保つ

---

## 6. エージェント実装パターン

すべてのエージェントは以下を統一する。

- システムプロンプトに `cache_control: ephemeral` を付ける（Prompt Caching）
- 出力は JSON 形式で要求し、Pydantic の `model_validate_json()` でパースする
- 関数シグネチャは「型付き引数 → Pydantic モデル」で統一する

```python
# agents/classifier.py
from pydantic import BaseModel
from infra.foundry import get_client, MAIN_MODEL

SYSTEM_PROMPT = """あなたは文書分類エージェントです。
入力された文書を分析し、以下の JSON 形式で返してください。
{
  "document_type": "string",
  "review_purpose": ["string"],
  "focus_points": ["string"],
  "reviewer_perspectives": ["string"]
}"""

class ClassificationResult(BaseModel):
    document_type: str
    review_purpose: list[str]
    focus_points: list[str]
    reviewer_perspectives: list[str]

async def classify_document(text: str) -> ClassificationResult:
    client = get_client()
    response = client.messages.create(
        model=MAIN_MODEL,
        max_tokens=1024,
        system=[{
            "type": "text",
            "text": SYSTEM_PROMPT,
            "cache_control": {"type": "ephemeral"},
        }],
        messages=[{"role": "user", "content": text}],
    )
    return ClassificationResult.model_validate_json(response.content[0].text)
```

---

## 7. レビュー オーケストレーター

Review Worker は以下の順序で各エージェントを呼び出す。

```
1. classifying          → classifier.py
2. retrieving-memory    → memory_retrieval.py
3. multimodal-analyzing → multimodal.py（条件付き）
4. reviewing            → critique.py
5. synthesizing         → synthesizer.py
```

```python
# blueprints/review_worker.py（orchestrate_review の骨格）
async def orchestrate_review(review_job_id: str) -> None:
    job = await cosmos.get_review_job(review_job_id)

    try:
        await cosmos.update_job_step(review_job_id, "classifying")
        classification = await classify_document(job.primary_text)

        await cosmos.update_job_step(review_job_id, "retrieving-memory")
        memories = await retrieve_memories(job.primary_text, classification)

        diagram_findings = []
        if job.has_vision_pages and feature_enabled("FEATURE_ENABLE_MULTIMODAL_DIAGRAM"):
            await cosmos.update_job_step(review_job_id, "multimodal-analyzing")
            diagram_findings = await analyze_diagrams(job.vision_pages)

        await cosmos.update_job_step(review_job_id, "reviewing")
        critique = await generate_critique(job, classification, memories, diagram_findings)

        await cosmos.update_job_step(review_job_id, "synthesizing")
        result = await synthesize_review(classification, memories, critique, diagram_findings)

        await save_review_result(job, result)
        await cosmos.update_job_step(review_job_id, "completed")

    except Exception:
        current_step = await cosmos.get_current_step(review_job_id)
        await cosmos.mark_job_failed(review_job_id, failure_step=current_step)
        raise
```

---

## 8. エラーハンドリング方針

- いずれかのエージェントが失敗した場合、ジョブ全体を `failed` にする
- 部分成功は MVP では行わない
- `failure_step` に失敗したステップ名を記録する
- Queue トリガーは例外を再 raise することで Azure Functions の再試行機構に委ねる
- マルチモーダル解析の失敗もレビュー全体を `failed` にする（`review-detailed-design.md` §6.6 の方針）

---

## 9. 非同期方針

- HTTP トリガー・Queue トリガーともに `async def` で統一する
- エージェント関数もすべて `async def` にする
- Anthropic SDK の同期クライアントを `asyncio.to_thread()` でラップして使う

```python
import asyncio
from infra.foundry import get_client

async def call_claude(model: str, system: list, messages: list, max_tokens: int):
    client = get_client()
    return await asyncio.to_thread(
        client.messages.create,
        model=model,
        max_tokens=max_tokens,
        system=system,
        messages=messages,
    )
```

---

## 10. 依存関係（pyproject.toml）

```toml
[project]
name = "review-memory-agent-api"
requires-python = ">=3.12"
dependencies = [
    "azure-functions>=1.21.0",
    "anthropic>=0.40.0",
    "azure-cosmos>=4.7.0",
    "azure-storage-blob>=12.19.0",
    "azure-storage-queue>=12.10.0",
    "azure-ai-documentintelligence>=1.0.0",
    "azure-keyvault-secrets>=4.8.0",
    "azure-identity>=1.17.0",
    "openai>=1.0.0",
    "pydantic>=2.0",
]

[tool.uv]
dev-dependencies = [
    "pytest>=8.0",
    "pytest-asyncio>=0.23",
]
```

---

## 11. 固定ルール一覧

| 項目 | 決定 |
|---|---|
| Python バージョン | 3.12 |
| Functions プログラミングモデル | v2（Blueprint + デコレーター） |
| 非同期 | `async def` 統一（HTTP / Queue 両方） |
| SDK 同期呼び出し | `asyncio.to_thread()` でラップ |
| Claude 呼び出し | Anthropic SDK + `base_url` = `FOUNDRY_ENDPOINT` |
| モデル指定 | 環境変数のみ（ハードコード禁止） |
| 出力パース | Pydantic `model_validate_json()` |
| Prompt Caching | 各エージェントのシステムプロンプトに `cache_control: ephemeral` |
| エラー時 | ジョブ全体を `failed` / `failure_step` を記録して raise |
| パッケージ管理 | uv |
| エージェントフレームワーク | 不使用（Anthropic SDK + 自前オーケストレーション） |

---

## 12. 採用しないもの

| 候補 | 不採用理由 |
|---|---|
| LangChain / LangGraph / DeepAgents | 順次パイプラインに対してオーバースペック。Azure Foundry との相性が未確認 |
| Anthropic Managed Agents | Azure AI Foundry 経由では利用不可（1st-party API 専用） |
| Azure AI Foundry Agent Service | Claude 主力構成との相性が悪い（`azure-component-decisions.md` §9 参照） |
| Anthropic SDK 非同期クライアント | `anthropic.AsyncAnthropic` は Azure Foundry の `base_url` 対応が未確認のため、同期クライアント + `asyncio.to_thread()` を採用 |
