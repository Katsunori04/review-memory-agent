# Review 機能 詳細設計

## 1. 目的

このドキュメントは、Review Memory Agent の `Review` 機能について、MVP実装に必要な詳細設計を整理したものである。

今回の設計では、以下を前提とする。

- 1回のレビューは `主資料1件 + 添付資料複数件` を1セットとして扱う
- 文書解析は Azure AI Document Intelligence を第一段で使う
- 画像や図は、必要時のみ Azure AI Foundry 上の Claude マルチモーダルモデルで補完解釈する
- レビュー結果は毎回保存する
- レビュー結果に対する人間のコメントは保存するが、その場で自動学習・自動再レビューはしない
- Review Memory の保存と検索は Cosmos DB 単体で完結させる

---

## 2. スコープ

このドキュメントで扱う範囲は以下である。

- Review画面の入力仕様
- レビュー実行フロー
- 文書解析フロー
- 画像・図のマルチモーダル解釈
- API設計
- Cosmos DB の論理データ設計
- ジョブ状態と失敗時の扱い

今回は以下を対象外とする。

- Memory登録画面の詳細設計
- Apply画面の詳細設計
- 認証・認可
- 管理者画面

---

## 3. レビュー対象モデル

### 3.1 基本単位

レビュー対象の基本単位は `review_set` とする。

`review_set` は以下で構成する。

- `primaryDocument`
  - レビューの中心となる主資料
- `attachments[]`
  - 補足資料

### 3.2 扱い方

- 主資料は、レビュー判定と指摘生成の中心入力とする
- 添付資料は、主資料の背景情報・補足情報として扱う
- 添付資料は独立採点しない
- テキスト貼り付け入力も `primaryDocument` と同じ扱いにする
- 画像ファイル単体が入力された場合も `documents` に登録し、必要であればマルチモーダル解釈対象にする

### 3.3 想定する資料例

- 主資料
  - 顧客提案書
  - 社内稟議書
  - 設計書
  - システム構成図付き資料
- 添付資料
  - 補足仕様書
  - 構成図単体
  - 会議資料
  - セキュリティ要件メモ

---

## 4. 画面仕様

### 4.1 画面状態

Review画面は次の4状態で設計する。

1. 入力
2. AI推定
3. 実行中
4. 結果

### 4.2 入力状態

入力状態では以下を受け付ける。

- 主資料アップロード
- 主資料テキスト貼り付け
- 添付資料追加
- タイトル任意入力

入力ルール:

- 主資料は必須
- 添付資料は任意
- 主資料は `ファイル` または `テキスト` のどちらか
- 添付資料は複数追加可

### 4.3 AI推定状態

AI推定では、主資料を中心に以下を自動推定する。

- `documentType`
- `reviewPurpose[]`
- `focusPoints[]`
- `reviewerPerspectives[]`
- `strictness`

UI要件:

- 推定結果は実行前に人が修正できる
- 添付資料は推定補助には使うが、推定対象の中心は主資料とする

### 4.4 実行中状態

実行中はジョブ進捗を表示する。

表示するステータス:

- `queued`
- `extracting`
- `multimodal-analyzing`
- `reviewing`
- `completed`
- `failed`

### 4.5 結果状態

結果画面では以下を表示する。

- `summary`
- `score`
- `issues[]`
- `missingInfo[]`
- `suggestedEdits[]`
- `appliedMemories[]`
- `diagramFindings[]`
- `feedback` 入力欄
- `再レビュー` ボタン

MVPでは以下は持たない。

- 指摘ごとの採用 / 却下
- 指摘ごとの手修正
- 結果そのものの上書き保存

---

## 5. レビュー実行フロー

### 5.1 全体フロー

```text
1. review_set を作成する
2. 主資料・添付資料を Blob に保存する
3. documents を Cosmos DB に登録する
4. 文書解析ジョブを投入する
5. Document Intelligence で抽出する
6. 必要ページのみマルチモーダル解析する
7. review を作成する
8. Agent群でレビューする
9. 結果を Blob / Cosmos DB に保存する
10. UI に結果を返す
```

### 5.2 `review_set` 作成

`POST /api/review-sets` で以下を行う。

- `reviewSetId` 発行
- 主資料登録
- 添付資料登録
- Blob Storage 保存
- `documents` レコード作成
- `review_sets` レコード作成

### 5.3 文書解析

ファイル入力がある場合は `document-analysis` ジョブを作成する。

Document Intelligence Layout で以下を抽出する。

- `pages`
- `paragraphs`
- `tables`
- `sections`
- `figures`

抽出結果は:

- Blob Storage にフルJSON保存
- Cosmos DB に要約メタデータ保存

### 5.4 レビュー実行

`POST /api/reviews` で以下を行う。

- `reviewId` 発行
- `review_jobs` 作成
- `reviews` 下書き作成
- `review` ジョブ投入

Review Orchestrator は次の順で実行する。

1. `Document Classifier Agent`
2. `Memory Retrieval Agent`
3. `Multimodal Diagram Agent`（必要時のみ）
4. `Review Critique Agent`
5. `Review Synthesizer Agent`

### 5.5 再レビュー

`POST /api/reviews/{reviewId}/rerun` で新しいレビュー実行を起動する。

ルール:

- 既存レビューは上書きしない
- 新しい `reviewId` を発行する
- 同じ `reviewSetId` に対する別履歴として保存する

---

## 6. 画像・図のマルチモーダル解釈

### 6.1 基本方針

画像・図は、常時マルチモーダルに渡すのではなく、必要時のみ解析する。

理由:

- コストを抑える
- レイテンシを抑える
- 通常文書では Document Intelligence の抽出を優先できる

### 6.2 マルチモーダル実行条件

以下のいずれかに一致した場合のみ、Vision に回す。

- `figures` が検出された
- ページ内テキスト量が少なく、図中心ページと判定された
- 構成図、アーキテクチャ図、フロー図を示す語が周辺にある
- 重点観点に `セキュリティ`、`構成`、`データフロー` が含まれる

### 6.3 入力単位

Vision に渡す対象は **該当ページ全体** とする。

図切り出しだけではなく、以下も含めて解釈させる。

- タイトル
- 注釈
- ラベル
- 凡例
- 矢印
- 周辺説明文

### 6.4 出力形式

Vision の結果は `diagramFindings[]` に正規化する。

各要素は少なくとも以下を持つ。

- `pageNumber`
- `observation`
- `risk`
- `suggestedCheck`

### 6.5 役割分担

- Document Intelligence
  - テキスト抽出
  - レイアウト抽出
  - `figures` 検出
- Multimodal Diagram Agent
  - 図の意味理解
  - 構成関係の読み取り
  - 欠落観点の抽出

### 6.6 失敗時の扱い

Vision 対象が必要なレビューで、そのステップが失敗した場合は、MVPでは **レビュー全体を failed** とする。

部分成功にはしない。

---

## 7. Agent 設計

### 7.1 Document Classifier Agent

役割:

- 文書タイプ推定
- レビュー目的推定
- 重点観点推定
- 想定レビュワー観点推定

入力:

- 主資料本文
- 添付資料の要約

出力:

- `documentType`
- `reviewPurpose[]`
- `focusPoints[]`
- `reviewerPerspectives[]`

### 7.2 Memory Retrieval Agent

役割:

- Cosmos DB の `memory_cards` から関連Memoryを取得する
- 適用候補を絞り込む

入力:

- 主資料要約
- レビュー条件

出力:

- `appliedMemories[]`
- `appliedMemoryIds[]`

### 7.3 Multimodal Diagram Agent

役割:

- 図や画像の意味解釈
- 主要構成要素の抽出
- 欠落観点の抽出

入力:

- 対象ページ画像
- そのページの抽出テキスト

出力:

- `diagramFindings[]`

### 7.4 Review Critique Agent

役割:

- 指摘生成
- リスク抽出
- 不足情報抽出
- 修正案生成

入力:

- 主資料本文
- 添付資料要約
- 適用Memory
- `diagramFindings[]`

出力:

- `issues[]`
- `missingInfo[]`
- `suggestedEdits[]`

### 7.5 Review Synthesizer Agent

役割:

- 総合判定作成
- スコア作成
- 表示順整形
- UI向けレスポンス整形

入力:

- 各Agentの出力

出力:

- `summary`
- `score`
- 最終レビューJSON

---

## 8. API 設計

### 8.1 `POST /api/review-sets`

入力:

- `primaryDocument`
  - `file` または `rawText`
- `attachments[]`
- `title?`

出力:

- `reviewSetId`
- `documentIds[]`
- `status`

### 8.2 `GET /api/review-sets/{reviewSetId}`

出力:

- 主資料情報
- 添付資料情報
- 抽出状態
- Vision対象候補ページの有無
- 最新レビュー概要

### 8.3 `POST /api/reviews`

入力:

- `reviewSetId`
- `documentType?`
- `reviewPurpose[]?`
- `focusPoints[]?`
- `reviewerPerspectives[]?`
- `strictness`

出力:

- `reviewId`
- `reviewJobId`
- `status`

### 8.4 `GET /api/reviews/{reviewId}`

出力:

- `status`
- `inferredContext`
- `summary`
- `score`
- `issues[]`
- `missingInfo[]`
- `suggestedEdits[]`
- `appliedMemories[]`
- `diagramFindings[]`
- `feedbackSummary?`

### 8.5 `POST /api/reviews/{reviewId}/feedback`

入力:

- `comment`

出力:

- `feedbackId`
- `status`

### 8.6 `POST /api/reviews/{reviewId}/rerun`

入力:

- `overrideOptions?`

出力:

- 新しい `reviewId`
- 新しい `reviewJobId`
- `status`

---

## 9. Cosmos DB 論理設計

### 9.1 `documents`

- `id`
- `reviewSetId`
- `role` (`primary` / `attachment`)
- `fileName`
- `blobPath`
- `contentType`
- `analysisStatus`
- `extractedTextPath`
- `layoutResultPath`
- `candidateVisionPages[]`
- `createdAt`

### 9.2 `review_sets`

- `id`
- `title`
- `primaryDocumentId`
- `attachmentDocumentIds[]`
- `latestReviewId`
- `status`
- `createdAt`
- `updatedAt`

### 9.3 `review_jobs`

- `id`
- `reviewId`
- `reviewSetId`
- `status`
- `currentStep`
- `failureStep?`
- `requestedOptions`
- `createdAt`
- `updatedAt`

### 9.4 `reviews`

- `id`
- `reviewSetId`
- `reviewJobId`
- `inputSnapshot`
- `inferredContext`
- `summary`
- `score`
- `issues[]`
- `missingInfo[]`
- `suggestedEdits[]`
- `appliedMemoryIds[]`
- `diagramFindings[]`
- `resultBlobPath`
- `createdAt`

### 9.5 `review_feedback`

- `id`
- `reviewId`
- `reviewSetId`
- `comment`
- `status`
- `intendedUse`
- `createdAt`

### 9.6 `memory_cards`

- `id`
- `title`
- `category`
- `criteria`
- `recommendedComment`
- `conditions[]`
- `embedding`
- `status`
- `createdAt`

### 9.7 パーティション方針

- `documents`
- `review_sets`
- `review_jobs`
- `reviews`
- `review_feedback`

は MVPでは `reviewSetId` を基本のパーティションキー候補とする。

`memory_cards` は検索主体で使うため、レビュー履歴系とは独立して扱う。

### 9.8 Blob に置くもの

次の重いデータは Cosmos DB に直接格納しない。

- 原本ファイル
- Document Intelligence のフルJSON
- Vision入力に使うページ画像
- 最終レビュー結果JSONの完全版

Cosmos DB には参照パスと要約メタデータを保存する。

---

## 10. ジョブ状態設計

### 10.1 文書解析ジョブ

状態:

- `queued`
- `extracting`
- `completed`
- `failed`

### 10.2 レビュージョブ

状態:

- `queued`
- `classifying`
- `retrieving-memory`
- `multimodal-analyzing`
- `reviewing`
- `synthesizing`
- `completed`
- `failed`

### 10.3 失敗情報

失敗時は以下を残す。

- `status=failed`
- `failureStep`
- `updatedAt`

必要であれば将来、`errorCode` や `errorMessage` を追加する。

---

## 11. ユーザーコメントの扱い

レビュー結果に対して、ユーザーは自由コメントを付与できる。

MVPでの扱いは以下とする。

- `review_feedback` に保存する
- 当該レビュー結果には自動反映しない
- 自動で Memory 候補化しない
- 自動で再レビューしない

このコメントは、将来の Memory 抽出やレビュー改善の元データとして使う。

---

## 12. 受け入れ条件

- 主資料1件だけでレビューが成立する
- 主資料 + 添付資料複数件でもレビューが成立する
- 添付資料は補足コンテキストとして扱われる
- Document Intelligence による抽出結果でレビューできる
- 図や画像がある場合、必要ページだけ Vision に回せる
- `diagramFindings[]` を結果に含められる
- Review Memory が Cosmos DB から自動適用される
- レビュー結果は毎回履歴として保存される
- コメント保存後に自動再レビューしない
- 再レビューは別実行として新しい `reviewId` が発行される

---

## 13. 今後の拡張候補

- コメントからの Memory 自動候補化
- 指摘ごとの採用 / 却下
- 部分成功時の graceful degradation
- Vision対象ページの自動判定精度改善
- Durable Functions への移行
- 管理者向けレビュー履歴画面
