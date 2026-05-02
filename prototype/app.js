const screenTitles = {
  home: "Review Memory Agent",
  review: "資料をチェック",
  memory: "指摘メモを登録",
  cards: "保存するチェック観点",
};

const reviewSample = `生成AI FAQサービスの提案書です。
問い合わせ対応の効率化を目的として、社内FAQと顧客問い合わせ履歴をもとに回答案を生成します。
効果は問い合わせ対応の効率化、回答品質の標準化、ナレッジ活用です。
まずはお試し導入で効果を確認し、問題なければ本番導入します。`;

const memorySample = `今回の提案では、削減時間だけでは費用対効果が弱い。
対象業務が月に何回発生するのか、誰がどれくらい時間を使っているのかも必要。
お試し導入の段階では正確な効果が出せないので、測定方法と評価タイミングを書いておくべき。
あと、生成AIを使うなら入力禁止情報とログの扱いも最低限入れてほしい。`;

const candidates = [
  {
    id: "frequency",
    title: "効果を書くときは、業務が何回あるかも必要",
    category: "効果",
    priority: "高",
    priorityClass: "high",
    selected: true,
  },
  {
    id: "poc",
    title: "お試し導入では、測り方と判断日を書く",
    category: "効果",
    priority: "高",
    priorityClass: "high",
    selected: true,
  },
  {
    id: "input",
    title: "生成AIの提案では、入れてはいけない情報を書く",
    category: "安全面",
    priority: "高",
    priorityClass: "high",
    selected: true,
  },
  {
    id: "log",
    title: "ログを残すかどうかを書く",
    category: "安全面",
    priority: "中",
    priorityClass: "medium",
    selected: false,
  },
];

const generatedPolicyCards = [
  {
    title: "お試し導入の効果を説明するときの観点",
    category: "効果",
    criteria:
      "お試し導入では効果がまだ確定しないため、想定削減時間だけでなく、対象業務の回数、測り方、いつ判断するかを書く。",
    comment:
      "効果を判断しやすくするため、対象業務が月に何回あるか、想定削減時間、確認する数字、評価タイミングを追記してください。",
    conditions: [
      "お試し導入の提案",
      "業務効率化を目的とした提案",
      "効果説明がざっくりしている、または削減時間だけで説明されている場合",
    ],
  },
  {
    title: "生成AIに入れてはいけない情報を確認する観点",
    category: "安全面",
    criteria:
      "生成AIを使う提案では、入れてはいけない情報、ログを残すか、誰が使えるか、利用者への注意を記載する。",
    comment:
      "生成AI利用時のリスクを抑えるため、入力してはいけない情報、ログ保存の有無、利用できる人、注意事項を追記してください。",
    conditions: [
      "生成AIサービスの提案",
      "AIチャット、FAQボット、議事録AIなどの提案",
      "顧客情報、社内情報、業務データを扱う可能性がある場合",
    ],
  },
];

const savedMemories = [
  {
    id: "trial-effect",
    title: "お試し導入の効果",
    description: "何を測るか、いつ判断するかを確認",
    count: 12,
    document: "生成AI FAQサービス提案書",
    documentType: "顧客提案書",
    source: "上司レビューコメント",
    reviewer: "営業部長",
    receivedAt: "2026/04/24",
    feedback:
      "削減時間だけでは費用対効果が弱い。対象業務が月に何回発生するのか、誰がどれくらい時間を使っているのかも書いてください。お試し導入では、測定方法と評価タイミングも必要です。",
    nextCheck: [
      "対象業務が月に何回あるか",
      "誰がどれくらい時間を使っているか",
      "お試し導入で何を測るか",
      "いつ効果を判断するか",
    ],
  },
  {
    id: "ai-safety",
    title: "生成AIの安全面",
    description: "入れてはいけない情報とログの扱いを確認",
    count: 9,
    document: "生成AI FAQサービス提案書",
    documentType: "顧客提案書",
    source: "レビュー会メモ",
    reviewer: "情シス担当",
    receivedAt: "2026/04/25",
    feedback:
      "生成AIを使うなら、個人情報や顧客情報を入力してよいのかが分からない。入力禁止情報、ログ保存の有無、誰が利用できるかを最低限入れてください。",
    nextCheck: [
      "AIに入れてはいけない情報が書かれているか",
      "ログを残すかどうかが書かれているか",
      "利用できる人が明確か",
      "お客様情報を扱う場合の注意があるか",
    ],
  },
  {
    id: "operation",
    title: "運用体制",
    description: "責任者と更新フローを確認",
    count: 7,
    document: "社内FAQ改善 稟議書",
    documentType: "社内稟議書",
    source: "差し戻し理由",
    reviewer: "部門マネージャー",
    receivedAt: "2026/04/18",
    feedback:
      "導入後に誰がFAQを更新するのかが分かりません。責任者、更新頻度、古い回答を見直す流れを書いてください。",
    nextCheck: [
      "導入後の責任者が書かれているか",
      "更新頻度が書かれているか",
      "古い情報を見直す流れがあるか",
      "問い合わせが増えたときの対応先が分かるか",
    ],
  },
];

let currentMemoryList = savedMemories;

const elements = {
  screenTitle: document.querySelector("#screenTitle"),
  reviewText: document.querySelector("#reviewText"),
  reviewResult: document.querySelector("#reviewResult"),
  memoryText: document.querySelector("#memoryText"),
  extractionPanel: document.querySelector("#extractionPanel"),
  candidateList: document.querySelector("#candidateList"),
  policyCardList: document.querySelector("#policyCardList"),
  recentMemoryList: document.querySelector("#recentMemoryList"),
  savedMemoryList: document.querySelector("#savedMemoryList"),
  savedCount: document.querySelector("#savedCount"),
  memoryDetail: document.querySelector("#memoryDetail"),
  memoryDetailBackdrop: document.querySelector("#memoryDetailBackdrop"),
  memoryDetailBody: document.querySelector("#memoryDetailBody"),
  detailTitle: document.querySelector("#detailTitle"),
  toast: document.querySelector("#toast"),
};

function showScreen(screen) {
  document.querySelectorAll("[data-screen-panel]").forEach((panel) => {
    panel.classList.toggle("is-active", panel.dataset.screenPanel === screen);
  });

  document.querySelectorAll("[data-screen]").forEach((button) => {
    button.classList.toggle("is-active", button.dataset.screen === screen);
  });

  elements.screenTitle.textContent = screenTitles[screen] ?? screenTitles.home;
  if (window.location.hash.slice(1) !== screen) {
    window.history.replaceState(null, "", `#${screen}`);
  }
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function toggleChip(button) {
  if (button.classList.contains("add")) return;
  button.classList.toggle("is-active");
}

function renderCandidates() {
  elements.candidateList.innerHTML = candidates
    .map(
      (candidate) => `
        <label class="candidate-row">
          <input type="checkbox" ${candidate.selected ? "checked" : ""} data-candidate-id="${candidate.id}" />
          <span class="candidate-main">
            <strong>${candidate.title}</strong>
            <span>次回も忘れずに見たいポイント</span>
          </span>
          <span class="category-pill">${candidate.category}</span>
          <span class="priority-pill ${candidate.priorityClass}">${candidate.priority}</span>
        </label>
      `,
    )
    .join("");
}

function renderPolicyCards() {
  elements.policyCardList.innerHTML = generatedPolicyCards
    .map(
      (card) => `
        <article class="policy-card">
          <div class="policy-card-header">
            <div>
              <span class="eyebrow">${card.category}</span>
              <h3>${card.title}</h3>
            </div>
            <label class="chip is-active">
              <input type="checkbox" checked />
              保存対象
            </label>
          </div>
          <div class="policy-block">
            <span>判断基準</span>
            <p>${card.criteria}</p>
          </div>
          <div class="policy-block">
            <span>推奨レビューコメント</span>
            <p>${card.comment}</p>
          </div>
          <div class="policy-block">
            <span>適用条件</span>
            <ul>${card.conditions.map((condition) => `<li>${condition}</li>`).join("")}</ul>
          </div>
        </article>
      `,
    )
    .join("");
}

function renderSavedMemories(extraSaved = false) {
  const list = extraSaved
    ? [
        ...savedMemories,
        {
          id: "trial-effect-new",
          title: "お試し導入の効果",
          description: "回数、測り方、判断日を確認",
          count: 1,
          document: "生成AI FAQサービス提案書 改訂版",
          documentType: "顧客提案書",
          source: "上司の指摘",
          reviewer: "営業部長",
          receivedAt: "2026/05/02",
          feedback: "効果説明には、対象業務の回数、想定削減時間、測定方法、判断日を入れてください。",
          nextCheck: ["業務の発生回数", "想定削減時間", "測定方法", "判断日"],
        },
        {
          id: "ai-input-new",
          title: "生成AIの入力情報",
          description: "入力禁止情報、ログ、権限を確認",
          count: 1,
          document: "生成AI FAQサービス提案書 改訂版",
          documentType: "顧客提案書",
          source: "会議メモ",
          reviewer: "情シス担当",
          receivedAt: "2026/05/02",
          feedback: "生成AIに入れてはいけない情報、ログの扱い、利用できる人を明記してください。",
          nextCheck: ["入力禁止情報", "ログの扱い", "利用できる人"],
        },
      ]
    : savedMemories;

  currentMemoryList = list;
  elements.savedCount.textContent = `${list.length}件`;
  elements.savedMemoryList.innerHTML = list
    .map(
      (memory) => `
        <button class="memory-item" type="button" data-memory-id="${memory.id}">
          <div>
            <strong>${memory.title}</strong>
            <span>${memory.description}</span>
          </div>
          <small>${memory.count}回適用</small>
        </button>
      `,
    )
    .join("");

  if (elements.recentMemoryList) {
    elements.recentMemoryList.innerHTML = savedMemories
      .map(
        (memory) => `
          <button class="memory-item" type="button" data-memory-id="${memory.id}">
            <div>
              <strong>${memory.title}</strong>
              <span>${memory.description}</span>
            </div>
            <small>詳細</small>
          </button>
        `,
      )
      .join("");
  }
}

function findMemory(memoryId) {
  return currentMemoryList.find((memory) => memory.id === memoryId) ?? savedMemories.find((memory) => memory.id === memoryId);
}

function openMemoryDetail(memoryId) {
  const memory = findMemory(memoryId);
  if (!memory) return;

  elements.detailTitle.textContent = memory.title;
  elements.memoryDetailBody.innerHTML = `
    <section class="detail-section">
      <span>対象資料</span>
      <h3>${memory.document}</h3>
      <p>${memory.documentType} / ${memory.receivedAt}</p>
    </section>
    <section class="detail-section">
      <span>どこから来た指摘か</span>
      <p>${memory.source} / ${memory.reviewer}</p>
    </section>
    <section class="detail-section">
      <span>実際にもらったフィードバック</span>
      <blockquote>${memory.feedback}</blockquote>
    </section>
    <section class="detail-section">
      <span>次回から確認すること</span>
      <ul>${memory.nextCheck.map((item) => `<li>${item}</li>`).join("")}</ul>
    </section>
  `;
  elements.memoryDetailBackdrop.hidden = false;
  elements.memoryDetail.classList.add("is-open");
  elements.memoryDetail.setAttribute("aria-hidden", "false");
  refreshIcons();
}

function closeMemoryDetail() {
  elements.memoryDetail.classList.remove("is-open");
  elements.memoryDetail.setAttribute("aria-hidden", "true");
  window.setTimeout(() => {
    elements.memoryDetailBackdrop.hidden = true;
  }, 160);
}

function showToast(message) {
  elements.toast.textContent = message;
  elements.toast.classList.add("is-visible");
  window.setTimeout(() => {
    elements.toast.classList.remove("is-visible");
  }, 2600);
}

function refreshIcons() {
  if (window.lucide) {
    window.lucide.createIcons();
  }
}

document.addEventListener("click", (event) => {
  const screenButton = event.target.closest("[data-screen], [data-screen-jump]");
  if (screenButton) {
    showScreen(screenButton.dataset.screen ?? screenButton.dataset.screenJump);
    return;
  }

  const memoryItem = event.target.closest("[data-memory-id]");
  if (memoryItem) {
    openMemoryDetail(memoryItem.dataset.memoryId);
    return;
  }

  if (event.target.closest("#closeMemoryDetail") || event.target === elements.memoryDetailBackdrop) {
    closeMemoryDetail();
    return;
  }

  const chip = event.target.closest(".chip");
  if (chip && !event.target.matches("input")) {
    toggleChip(chip);
    return;
  }

  if (event.target.closest("[data-add-security]")) {
    event.target.closest("[data-add-security]").classList.add("is-active");
    showToast("「安全面」をチェック項目に追加しました。");
    return;
  }

  if (event.target.closest("#autoFillReview")) {
    elements.reviewText.value = reviewSample;
    showToast("サンプルの提案書を入れました。資料の種類は自動で判定されます。");
    return;
  }

  if (event.target.closest("#runReview")) {
    if (!elements.reviewText.value.trim()) {
      elements.reviewText.value = reviewSample;
    }
    elements.reviewResult.classList.add("is-visible");
    showToast("資料をチェックしました。以前の指摘も使っています。");
    window.setTimeout(() => elements.reviewResult.scrollIntoView({ behavior: "smooth", block: "start" }), 120);
    return;
  }

  if (event.target.closest("#autoFillMemory")) {
    elements.memoryText.value = memorySample;
    showToast("上司からの指摘サンプルを入れました。");
    return;
  }

  if (event.target.closest("#extractMemory")) {
    if (!elements.memoryText.value.trim()) {
      elements.memoryText.value = memorySample;
    }
    renderCandidates();
    elements.extractionPanel.classList.add("is-visible");
    refreshIcons();
    showToast("次回も見るポイントを4件見つけました。");
    return;
  }

  if (event.target.closest("#generateCards")) {
    renderPolicyCards();
    showScreen("cards");
    showToast("選んだポイントを保存用カードにしました。");
    refreshIcons();
    return;
  }

  if (event.target.closest("#saveCards")) {
    renderSavedMemories(true);
    showToast("保存しました。次回の資料チェックで自動で確認します。");
    const saveComplete = document.querySelector("#saveComplete");
    if (saveComplete) {
      saveComplete.hidden = false;
      refreshIcons();
    }
    return;
  }
});

document.addEventListener("change", (event) => {
  const checkbox = event.target.closest("[data-candidate-id]");
  if (!checkbox) return;

  const candidate = candidates.find((item) => item.id === checkbox.dataset.candidateId);
  if (candidate) {
    candidate.selected = checkbox.checked;
  }
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    closeMemoryDetail();
  }
});

renderCandidates();
renderPolicyCards();
renderSavedMemories();
refreshIcons();

const initialScreen = window.location.hash.slice(1);
if (screenTitles[initialScreen]) {
  showScreen(initialScreen);
}

const demoMode = new URLSearchParams(window.location.search).get("demo");
const detailMode = new URLSearchParams(window.location.search).get("detail");
if (demoMode === "review") {
  elements.reviewText.value = reviewSample;
  elements.reviewResult.classList.add("is-visible");
  showScreen("review");
}

if (demoMode === "memory") {
  elements.memoryText.value = memorySample;
  elements.extractionPanel.classList.add("is-visible");
  showScreen("memory");
}

if (demoMode === "cards") {
  showScreen("cards");
}

if (detailMode) {
  openMemoryDetail(detailMode);
}
