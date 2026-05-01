# Apply 機能 詳細設計

## 1. 目的

このドキュメントは、Review Memory Agent の `Apply` 機能について、MVP実装に必要な詳細設計を整理したßものである。

今回の設計では、以下を前提とする。

- Apply は、保存済み Memory を Review 実行時に自動検索し、今回のレビューに反映する機能である
- Memory の検索と適用は Cosmos DB 単体で完結させる
- 適用はユーザーの事前選択ではなく自動実行とし、結果画面でß根拠ßを表示する
- 適用結果は Review 結果の一部として毎回保存する
- 適用された Memory はレビュー本文生成だけでなく、説明責任のための表示対象にもする

---

## 2. スコープ

このドキュメントで扱う範囲は以下である。
ß
- Apply の役割定義
- Memory 検索フロー
- 適用判定ルール
- 適用結果の画面表示
- API設計
- Cosmos DB の論理データ設計
- Review 実行との接続方式

今回は以下を対象外とする。

- Memory 登録機能の詳細設計
- Review 指摘生成そのものの詳細ロジック
- Memory の手動選択UI
- 管理者向けランキング調整画面

---

## 3. Apply の基本概念

### 3.1 Apply とは何か

Apply は、今回のレビュー対象に対して、過去に保存されたレビュー方針カードの中から関連性の高いものを検索し、レビュー生成に反映する機能である。

Apply の役割は次の2つである。

- レビュー生成の入力として、過去の判断基準をAIに与える
- 「何を根拠に今回のレビューが行われたか」を画面に表示する

### 3.2 Apply の単位

Apply は `review` 単位で行う。

1回の Review 実行に対して:

- 0件以上の Memory を検索する
- 上位の候補を適用候補として採用する
- 採用結果を `appliedMemories[]` として保存する

### 3.3 Apply の成果物

MVPでは、Apply の結果として以下を持つ。

- `appliedMemoryIds[]`
- `appliedMemories[]`
- `matchReason`
- `appliedFocusSummary`

---

## 4. 適用タイミング

### 4.1 実行タイミング

Apply は Review 実行中に自動で行う。

順序は以下とする。

1. 文書抽出
2. 文脈推定
3. Memory 検索
4. Memory 適用
5. 指摘生成
6. 結果整形

### 4.2 入力に使う情報

Apply では以下を検索キーとして使う。

- 主資料要約
- `documentType`
- `reviewPurpose[]`
- `focusPoints[]`
- 添付資料の補足要約

### 4.3 適用対象

MVPでは `memory_cards.status=active` のみを対象にする。

---

## 5. Memory 検索フロー

### 5.1 全体フロー

```text
1. Review から検索用コンテキストを作る
2. 検索用テキストを正規化する
3. embedding を生成する
4. Cosmos DB の memory_cards をベクトル検索する
5. 条件が合う候補だけに絞る
6. 上位候補を適用対象として採用する
7. matchReason を生成する
8. Review 結果に反映する
```

### 5.2 検索用コンテキスト生成

検索用コンテキストは以下を1つにまとめた短い要約とする。

- 主資料の要旨
- 文書タイプ
- レビュー目的
- 重点観点
- 補足資料の要点

この要約を `applyQueryText` として扱う。

### 5.3 ベクトル検索

`applyQueryText` から embedding を生成し、`memory_cards.embedding` に対して類似検索する。

MVPの方針:

- まずベクトル類似度で候補を取る
- その後に適用条件で絞る

### 5.4 条件フィルタ

ベクトル類似度だけではなく、`conditions[]` を使って機械的な絞り込みを行う。

例:

- `PoC提案`
- `生成AIサービスの提案`
- `業務効率化を目的とした提案`
- `構成図を含む資料`

MVPでは、`conditions[]` は自由文のまま保存しつつ、適用時にはAIに「今回条件に合うか」を判定させる。

### 5.5 採用件数

MVPでは、検索上位のうち **最大3件** を適用対象にする。

理由:

- UIで説明しやすい
- 過剰な条件注入を避ける
- 同じレビューに多すぎる観点を混ぜない

### 5.6 0件時の扱い

一致する Memory がない場合でも Review は継続する。

結果では:

- `appliedMemories[] = []`
- `appliedFocusSummary = null`

とする。

---

## 6. 適用判定ルール

### 6.1 採用条件

Memory は以下を満たした場合に採用する。

- ベクトル検索で上位に入る
- `status=active`
- 今回の文書タイプや目的に明らかに矛盾しない
- 同じ意味の候補が複数ある場合は重複しすぎない

### 6.2 重複制御

似た Memory が複数ヒットした場合は、MVPでは以下で制御する。

- 同カテゴリで内容が近いものは1件に寄せる
- 表現違いだが同じ観点なら、より具体的な方を優先する

### 6.3 優先順位

優先順位は以下とする。

1. 文書タイプとの整合
2. 重点観点との整合
3. ベクトル類似度
4. コメント文としての再利用しやすさ

### 6.4 不採用理由

MVPでは不採用理由一覧は返さない。

返すのは採用済み Memory のみとする。

---

## 7. Review への反映方法

### 7.1 Agent への渡し方

Apply 結果は `Review Critique Agent` に構造化入力として渡す。

渡す内容:

- `title`
- `criteria`
- `recommendedComment`
- `conditions[]`
- `matchReason`

### 7.2 反映のしかた

Memory は以下の用途で使う。

- 重点確認観点としてレビュー指摘に反映する
- 不足情報の判定に使う
- 推奨コメント生成の参考にする

### 7.3 反映しないもの

Memory は次の用途には使わない。

- スコア計算の単独根拠
- ユーザー未確認の強制判定
- 元文書の改ざん

---

## 8. 画面仕様

### 8.1 表示場所

Apply の結果は Review 結果画面の `適用した過去レビュー方針` セクションに表示する。

### 8.2 表示内容

各適用Memoryについて以下を表示する。

- `title`
- `category`
- `matchReason`
- `recommendedComment` の要約

さらに、上部に `appliedFocusSummary` を表示する。

表示例:

```text
前回のレビュー会メモに基づき、以下の観点を重点確認しました。

- PoC提案では、測定方法と評価タイミングを明記する
- 生成AI提案では、入力禁止情報とログ管理方針を記載する
```

### 8.3 0件時表示

適用対象がない場合は、セクション自体は表示するが、次のような文言にする。

```text
今回自動適用された過去レビュー方針はありません。
```

### 8.4 ユーザー操作

MVPでは以下のみ許可する。

- 適用結果を見る
- 再レビューを行う

MVPでは以下は持たない。

- 適用Memoryの手動ON/OFF
- 適用順位の手動入れ替え
- この場でのMemory保存/修正

---

## 9. API 設計

### 9.1 `GET /api/reviews/{reviewId}`

Apply 関連として以下を返す。

- `appliedMemories[]`
- `appliedMemoryIds[]`
- `appliedFocusSummary`

`appliedMemories[]` の各要素:

- `memoryId`
- `title`
- `category`
- `criteria`
- `recommendedComment`
- `matchReason`

### 9.2 `GET /api/memories/search`

このAPIは主に検証や将来の一覧UI向けとし、Review 内部の検索ロジックと同じ考え方を使う。

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

### 9.3 Review 内部インターフェース

`Memory Retrieval Agent` の出力は少なくとも以下とする。

- `appliedMemoryIds[]`
- `appliedMemories[]`
- `appliedFocusSummary`

---

## 10. Cosmos DB 論理設計

### 10.1 `memory_cards`

Apply で参照する主コンテナは `memory_cards` とする。

必要項目:

- `id`
- `title`
- `category`
- `criteria`
- `recommendedComment`
- `conditions[]`
- `embedding`
- `status`
- `createdAt`
- `updatedAt`

### 10.2 `reviews`

Apply の結果は `reviews` に保存する。

保持項目:

- `appliedMemoryIds[]`
- `appliedMemories[]`
- `appliedFocusSummary`

### 10.3 保存方針

MVPでは、適用時の候補全件は保持せず、採用した Memory のみ `reviews` に保存する。

---

## 11. 状態設計

Apply 専用の永続状態は持たず、Review ジョブ内の1ステップとして扱う。

レビュージョブの `currentStep` では以下を使う。

- `retrieving-memory`

失敗時は:

- `review_jobs.status=failed`
- `failureStep=retrieving-memory`

とする。

---

## 12. 受け入れ条件

- Review 実行時に保存済み Memory を自動検索できる
- 検索結果から最大3件を適用対象にできる
- 0件でもレビューが継続できる
- 適用結果を `appliedMemories[]` として保存できる
- Review 結果画面に適用した過去方針を表示できる
- `matchReason` を人に読める形で返せる
- Apply の失敗時に `failureStep` を記録できる

---

## 13. 今後の拡張候補

- 適用Memoryの手動選択モード
- 不採用候補の説明表示
- カテゴリ別の適用上限調整
- 利用回数や効果を加味したランキング改善
- Review 実行前プレビューとしての Apply 候補表示
