# Memory 機能 詳細設計

## 1. 目的

このドキュメントは、Review Memory Agent の `Memory` 機能について、MVP実装に必要な詳細設計を整理したものである。

今回の設計では、以下を前提とする。

- Memory は人間の判断や知見を、次回レビューで再利用できるレビュー方針カードに変換する
- Memory の正本と類似検索先は Cosmos DB に統一する
- 候補抽出、カード生成、保存判定は分離し、人間承認を必須にする
- Review結果へのコメントは `review_feedback` に保存し、MVPでは自動で Memory 化しない
- Memory は Review 実行時に Cosmos DB ベクトル検索で自動適用する

---

## 2. スコープ

このドキュメントで扱う範囲は以下である。

- Memory登録画面の入力仕様
- 論点抽出フロー
- レビュー方針カード生成フロー
- 保存・承認ルール
- API設計
- Cosmos DB の論理データ設計
- Review への適用条件

今回は以下を対象外とする。

- Review画面の詳細設計
- 管理者向けメンテナンス画面
- Memory の一括インポート
- Memory の自動失効や自動統合

---

## 3. Memory の基本概念

### 3.1 Memory とは何か

Memory は、過去のレビューコメントや会議メモから抽出された「再利用可能なレビュー判断」である。

MVPでは、Memory を `レビュー方針カード` として管理する。

カードの目的は以下である。

- 次回レビュー時に関連する観点を呼び出す
- 単発コメントを組織知に変換する
- 人に依存していたレビュー基準を再利用可能にする

### 3.2 Memory の単位

1つの Memory は、1つの再利用可能な判断基準を表す。

例:

- PoC提案では測定方法と評価タイミングを明記すべき
- 生成AI提案では入力禁止情報を明記すべき
- 業務効率化提案では発生頻度を含めて効果を示すべき

### 3.3 Memory の構成要素

MVPでは、1カードは最低限以下を持つ。

- `title`
- `category`
- `criteria`
- `recommendedComment`
- `conditions[]`
- `sourceType`
- `sourceText`
- `embedding`
- `status`

---

## 4. 入力仕様

### 4.1 入力ソース

MVPで受け付ける入力ソースは以下とする。

- 正式レビューコメント
- 会議文字起こし
- 観点メモ
- チャットコメント
- QA・問い合わせ回答

### 4.2 入力単位

1回の Memory 登録処理は、1つの `memory_source` を単位とする。

`memory_source` は以下を持つ。

- `sourceType`
- `rawText`
- `title?`
- `relatedReviewId?`
- `relatedReviewSetId?`

### 4.3 入力ルール

- 入力は MVPではテキスト貼り付け中心とする
- ファイル添付からの直接 Memory 化は今回のMVPでは含めない
- `relatedReviewId` がある場合は、どのレビュー結果から派生した知見かを追跡可能にする

---

## 5. 画面仕様

### 5.1 画面構成

Memory 登録は次の2画面で構成する。

1. `レビューMemory登録画面`
2. `レビュー方針カード保存画面`

### 5.2 レビューMemory登録画面

役割:

- ソース入力を受ける
- AIで論点候補を抽出する
- 保存したい候補を選択させる

表示要素:

- 入力タイプ選択
- テキスト入力欄
- 抽出実行ボタン
- 候補一覧
- 候補選択UI
- 次へ進むボタン

候補一覧の各行には以下を表示する。

- `title`
- `category`
- `priority`
- `reason`

### 5.3 レビュー方針カード保存画面

役割:

- 選択された候補をカード化して確認する
- 人間が保存可否を決める

表示要素:

- カード候補一覧
- 各カードの `criteria`
- 各カードの `recommendedComment`
- 各カードの `conditions[]`
- 保存対象トグル
- 保存ボタン

MVPでは以下は持たない。

- 本格的なリッチ編集
- カードのマージ候補提示
- 承認ワークフロー

---

## 6. Memory 登録フロー

### 6.1 全体フロー

```text
1. memory_source を作成する
2. AI が論点候補を抽出する
3. ユーザーが保存候補を選ぶ
4. AI がレビュー方針カード候補を生成する
5. ユーザーが保存対象を確認する
6. Cosmos DB に memory_cards を保存する
7. embedding を付与し検索可能にする
```

### 6.2 論点候補抽出

`POST /api/memories/extract` で以下を行う。

- `memorySourceId` 発行
- `memory_sources` 作成
- `Memory Extraction Agent` 実行
- `memory_candidates` 作成

抽出方針:

- 単なる一時的感想ではなく再利用可能な判断を優先する
- 同じ意味の候補は可能な限り集約する
- 行動指示ではなく判断基準として言い換える

### 6.3 候補選択

ユーザーは抽出候補から保存したいものだけを選ぶ。

ルール:

- 未選択候補は保存しない
- 選択は複数可
- 保存前にカード化結果を必ず確認させる

### 6.4 方針カード生成

`POST /api/memories/cards/generate` で以下を行う。

- 選択候補を受ける
- `Memory Card Generation Agent` 実行
- `memory_card_drafts` 作成

生成ルール:

- タイトルは検索しやすい短い表現にする
- `criteria` は判断基準として書く
- `recommendedComment` はそのままレビューコメントに転用できる表現にする
- `conditions[]` は適用すべき文書・状況を列挙する

### 6.5 保存

`POST /api/memories` で以下を行う。

- 保存対象ドラフトを受ける
- embedding を生成する
- `memory_cards` に保存する
- 保存結果を返す

保存ルール:

- 人間が選択したドラフトだけ保存する
- 生成済みだが未選択のドラフトは保存しない
- 保存後は Review の類似検索対象に含める

---

## 7. Agent 設計

### 7.1 Memory Extraction Agent

役割:

- 入力テキストから再利用候補を抽出する
- カテゴリと推奨度を付ける
- 再利用しにくい感想や文脈依存の強い文は落とす

入力:

- `sourceType`
- `rawText`
- `relatedReviewContext?`

出力:

- `candidates[]`
  - `title`
  - `category`
  - `priority`
  - `reason`

### 7.2 Memory Card Generation Agent

役割:

- 選択候補をレビュー方針カード化する
- 判断基準と推奨コメントを構造化する

入力:

- 選択済み `candidates[]`
- 元の `sourceText`

出力:

- `cardDrafts[]`
  - `title`
  - `category`
  - `criteria`
  - `recommendedComment`
  - `conditions[]`

### 7.3 Memory Embedding Step

役割:

- 保存対象カードの埋め込みベクトルを生成する
- Cosmos DB の類似検索に使える形にする

入力:

- `title`
- `criteria`
- `recommendedComment`
- `conditions[]`

出力:

- `embedding`

---

## 8. API 設計

### 8.1 `POST /api/memories/extract`

入力:

- `sourceType`
- `rawText`
- `title?`
- `relatedReviewId?`
- `relatedReviewSetId?`

出力:

- `memorySourceId`
- `candidates[]`

### 8.2 `POST /api/memories/cards/generate`

入力:

- `memorySourceId`
- `selectedCandidateIds[]`

出力:

- `draftIds[]`
- `cardDrafts[]`

### 8.3 `POST /api/memories`

入力:

- `draftIds[]`
- `saveSelections[]`

出力:

- `savedMemoryIds[]`
- `status`

### 8.4 `GET /api/memories`

出力:

- 保存済みカード一覧
- `title`
- `category`
- `status`
- `createdAt`
- `usageCount?`

### 8.5 `GET /api/memories/search`

入力:

- `queryText`
- `documentType?`
- `focusPoints[]?`
- `topK?`

出力:

- `matchedMemories[]`
  - `memoryId`
  - `title`
  - `category`
  - `criteria`
  - `score`
  - `matchReason`

---

## 9. Cosmos DB 論理設計

### 9.1 `memory_sources`

- `id`
- `sourceType`
- `title`
- `rawText`
- `relatedReviewId?`
- `relatedReviewSetId?`
- `status`
- `createdAt`

### 9.2 `memory_candidates`

- `id`
- `memorySourceId`
- `title`
- `category`
- `priority`
- `reason`
- `selected`
- `createdAt`

### 9.3 `memory_card_drafts`

- `id`
- `memorySourceId`
- `sourceCandidateIds[]`
- `title`
- `category`
- `criteria`
- `recommendedComment`
- `conditions[]`
- `selectedForSave`
- `createdAt`

### 9.4 `memory_cards`

- `id`
- `title`
- `category`
- `criteria`
- `recommendedComment`
- `conditions[]`
- `sourceType`
- `sourceText`
- `sourceMemorySourceId`
- `sourceCandidateIds[]`
- `relatedReviewId?`
- `relatedReviewSetId?`
- `embedding`
- `status`
- `createdAt`
- `updatedAt`

### 9.5 パーティション方針

- `memory_sources`
- `memory_candidates`
- `memory_card_drafts`

は `memorySourceId` 単位の参照が多いため、そのまとまりを意識したパーティション設計にする。

`memory_cards` は検索主体で使うため、Review系コンテナとは独立して扱う。

---

## 10. Review への適用ルール

### 10.1 適用タイミング

Memory は Review 実行時の `Memory Retrieval Agent` で取得する。

### 10.2 検索キー

検索には以下を使う。

- 主資料要約
- 文書タイプ
- 重点観点
- レビュー目的

### 10.3 適用対象

MVPでは `status=active` の Memory だけを検索対象にする。

### 10.4 適用結果

Review 結果には以下を返す。

- `appliedMemoryIds[]`
- `appliedMemories[]`
- `matchReason`

---

## 11. 状態設計

### 11.1 `memory_sources.status`

- `created`
- `extracted`
- `failed`

### 11.2 `memory_cards.status`

- `active`
- `inactive`

MVPでは削除よりも `inactive` 化を基本とする。

---

## 12. ユーザーコメントとの関係

Review結果に対するコメントは `review_feedback` に保存する。

MVPでの扱い:

- コメントは自動で `memory_sources` に変換しない
- コメントは自動で候補抽出しない
- コメントを Memory 化する場合は、将来 `review_feedback` を入力ソースとして使う

これにより、Review と Memory の責務を分ける。

---

## 13. 受け入れ条件

- 正式レビューコメント、会議文字起こし、観点メモから候補抽出できる
- 候補ごとにカテゴリと推奨度を表示できる
- ユーザーが保存対象候補を選択できる
- 選択候補からレビュー方針カードを生成できる
- 人間承認後のみ `memory_cards` に保存される
- 保存済みカードに embedding が付き、Cosmos DB 検索に利用できる
- Review 実行時に保存済み Memory を自動適用できる
- Review コメントは保存されるが、自動では Memory 化されない

---

## 14. 今後の拡張候補

- `review_feedback` からの Memory 候補自動生成
- 類似カードの重複検知
- カード統合・改訂履歴管理
- 保存前の軽微な手修正
- sourceType ごとの抽出プロンプト最適化
- 利用回数や採用率を使ったランキング改善
