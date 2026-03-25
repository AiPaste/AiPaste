const translations = {
  en: {
    title: "AiPaste | AI Native Clipboard Manager for macOS",
    metaDescription:
      "AiPaste is an AI native clipboard manager for macOS. Keep prompts, context snippets, model outputs, and reusable commands organized and searchable.",
    navAriaLabel: "Primary",
    langSwitchAriaLabel: "Language switch",
    heroNotesAriaLabel: "Product notes",
    toolStripAriaLabel: "AI workflow tools",
    metricsAriaLabel: "Highlights",
    brandTagline: "AI native clipboard manager for macOS",
    nav: ["Overview", "Features", "Install", "FAQ"],
    headerCta: "Try for free",
    heroEyebrow: "AI native clipboard for macOS",
    heroHeadline: [
      "Your prompts, context, and model outputs.",
      "Organized and ready the second you need them.",
    ],
    heroHeadlineAriaLabel:
      "Your prompts, context, and model outputs. Organized and ready the second you need them.",
    heroLead:
      "AiPaste keeps your AI workflow artifacts within reach: prompts, code fixes, research fragments, terminal commands, and the one perfect answer you do not want to lose. Built in SwiftUI, local-first by default, and fast enough to disappear into your workflow until the moment you need it.",
    heroButtons: ["Download for macOS", "View on GitHub"],
    heroNotes: [
      "Built for ChatGPT, Claude, Cursor, and terminal-heavy work",
      "Prompt history, groups, pinning, paste-back, and CLI control",
      "Native SwiftUI app with Homebrew install and local-first storage",
    ],
    toolStrip: ["ChatGPT", "Claude", "Cursor", "Terminal", "Docs"],
    deviceSidebarTitle: "AiPaste",
    deviceSidebarItems: ["All clips", "Pinned", "Work", "Archive"],
    deviceToolbarTitle: "Recent clipboard",
    pill: "Searchable",
    clipApps: ["Claude", "Cursor", "Terminal"],
    clipTimes: ["Just now", "2 min ago", "8 min ago"],
    clipTitles: [
      "Rewrite this API error into a user-facing explanation with next steps.",
      "Use this file as context and propose the smallest safe patch.",
      "./bin/aipaste items paste 1",
    ],
    clipBodies: [
      "Keep the prompt you finally got right instead of reconstructing it from memory.",
      "Reuse the exact context snippet that produced the good code review or patch.",
      "Move from browser to IDE to terminal without losing the answer you were using.",
    ],
    floatTerminalLabel: "prompt ops",
    floatBadgeLabel: "ai native, not ai noisy",
    floatBadgeTitle: "Keep the useful context. Drop the repetitive copy-paste chaos.",
    metricsTitles: ["Prompt-ready", "Context retrieval", "Cross-tool loop"],
    metricsBodies: [
      "Keep your best prompts, reusable instructions, and context snippets one search away.",
      "Find commands, patches, model outputs, and fragments by memory instead of exact wording.",
      "Move cleanly between AI chat, IDE, docs, and terminal without losing state.",
    ],
    storyEyebrow: "AI native workflow",
    storyTitle:
      "When your work is half prompt engineering and half execution, clipboard history becomes infrastructure.",
    storyBody:
      "AiPaste is designed for developers, founders, operators, and researchers who bounce between model chats, code editors, docs, and terminals all day and need their working context to stay intact.",
    useCasesEyebrow: "Use Cases",
    useCasesTitle: "Made for people working with AI all day, not occasionally.",
    useCaseLabels: ["PROMPTS", "CONTEXT", "OUTPUTS"],
    useCaseTitles: [
      "Keep the exact prompt that finally worked",
      "Reuse code and document context across tools",
      "Save the answer before the next tab buries it",
    ],
    useCaseBodies: [
      "Store refined instructions, chain-of-thought wrappers, critique formats, and repeatable prompt patterns.",
      "Move snippets from GitHub, terminal logs, issue threads, and source files into the next AI interaction fast.",
      "Keep useful model responses, rewritten copy, SQL fixes, shell commands, and release notes drafts in reach.",
    ],
    featureLabels: ["CAPTURE", "RETRIEVE", "ORGANIZE", "OPERATE"],
    featureTitles: [
      "Capture AI prompts, answers, and commands without breaking flow.",
      "Find the right prompt or answer before your train of thought breaks.",
      "Build a reusable library of prompts, snippets, and context blocks.",
      "Use the app when you want UI. Use the CLI when your AI workflow is already scripted.",
    ],
    featureBodies: [
      "AiPaste monitors the pasteboard continuously and keeps the working fragments of your AI sessions in a clean, scan-friendly layout instead of burying them in a dense list.",
      "Search across recent clips, jump through groups, and use app context to get back to the exact prompt, code block, or model output you copied earlier.",
      "Pin recurring prompts, move clips into named groups, recolor workspaces, and exclude noisy or sensitive apps so your history stays useful instead of overwhelming.",
      "Show or hide the panel, paste a selected clip, manage groups, and change configuration from terminal commands that match the same workflow you use across AI tools and dev environments.",
    ],
    historyCardLabels: ["Prompt", "Context", "Patch", "Output"],
    historyCardTitles: [
      "Summarize the error log, identify root cause, then propose the safest minimal fix.",
      "Auth middleware, token refresh path, failing stack trace",
      "Guard nil session before attempting refresh",
      "User-facing summary for incident update",
    ],
    searchInput: "Search prompts, outputs, apps, commands...",
    searchResultApps: ["Claude", "Cursor", "Terminal"],
    searchResultTitles: [
      "Rewrite this changelog for users, not engineers",
      "Use this file as context and explain only the regression risk",
      "./bin/aipaste list --search release --limit 10",
    ],
    groupChips: ["claude", "cursor", "research"],
    groupTitles: ["review prompts", "code context blocks", "research fragments"],
    groupCounts: ["7 items", "12 items", "5 items"],
    capabilityLabels: ["AI LOOP", "PASTE BACK", "PRIVATE BY DEFAULT"],
    capabilityTitles: [
      "Move cleanly between prompt, output, code, and docs",
      "Return text to the previously active app",
      "Keep sensitive AI context local",
    ],
    capabilityBodies: [
      "AiPaste keeps the small pieces of context that make AI work actually usable across many tabs and tools.",
      "When Accessibility is enabled, AiPaste can paste directly back into the app you were just using.",
      "Your prompts, snippets, and copied outputs stay in a native local-first app instead of another web layer.",
    ],
    installEyebrow: "Install",
    installTitle: "Choose the path that matches your workflow.",
    installLabels: ["HOMEBREW", "RELEASE ZIP", "CLI"],
    installTitles: ["Best for everyday use", "Best for direct downloads", "Best for scriptable AI workflows"],
    installBlocks: [
      "brew tap AiPaste/aipaste\nbrew install --cask aipaste\nbrew upgrade --cask aipaste",
      "Open GitHub Releases\nDownload the latest zip\nMove AiPaste.app to /Applications",
      "./bin/aipaste help\n./bin/aipaste list --limit 10\n./bin/aipaste items paste 1",
    ],
    faqEyebrow: "FAQ",
    faqTitle: "Built for AI-heavy native Mac workflows.",
    faqQuestions: [
      "Is this an AI app?",
      "Does it store data locally?",
      "Can I automate it?",
      "Can it paste back into another app?",
      "How do I preview this site locally?",
    ],
    faqAnswers: [
      "It is AI native, not an LLM wrapper. AiPaste helps you manage the prompts, context, and outputs around AI work.",
      "Yes. AiPaste is designed as a local-first clipboard tool for macOS.",
      "Yes. The bundled CLI covers panel actions, item actions, groups, ignore rules, and configuration.",
      "Yes, with macOS Accessibility permission enabled for paste-to-app actions.",
      'Run <code>./scripts/serve_website.sh</code> and open the local address it prints.',
    ],
    ctaEyebrow: "AiPaste",
    ctaTitle: "Stop rebuilding the same prompt and context from scratch.",
    ctaBody:
      "A native clipboard manager for people doing serious AI work on macOS and tired of losing the useful parts.",
    ctaButtons: ["Download Release", "Star on GitHub"],
    footerTagline: "AI native macOS clipboard manager built with SwiftUI.",
    footerLinks: ["Repository", "Releases", "Homebrew Tap"],
  },
  zh: {
    title: "AiPaste | 面向 macOS 的 AI Native 剪贴板管理器",
    metaDescription:
      "AiPaste 是一款面向 macOS 的 AI Native 剪贴板管理器，帮助你整理和检索提示词、上下文片段、模型输出与可复用命令。",
    navAriaLabel: "主导航",
    langSwitchAriaLabel: "语言切换",
    heroNotesAriaLabel: "产品特点",
    toolStripAriaLabel: "AI 工作流工具",
    metricsAriaLabel: "核心亮点",
    brandTagline: "面向 macOS 的 AI Native 剪贴板管理器",
    nav: ["概览", "功能", "安装", "常见问题"],
    headerCta: "免费试用",
    heroEyebrow: "AI Native macOS 剪贴板",
    heroHeadline: ["你的提示词、上下文与模型输出。", "在你需要的那一秒，随时可取。"],
    heroHeadlineAriaLabel: "你的提示词、上下文与模型输出。在你需要的那一秒，随时可取。",
    heroLead:
      "AiPaste 让你的 AI 工作流素材始终触手可及：提示词、代码修复、研究片段、终端命令，以及那个你不想再丢掉的完美答案。它基于 SwiftUI 构建，默认本地优先，足够轻快，平时几乎隐形，需要时立刻出现。",
    heroButtons: ["下载 macOS 版本", "查看 GitHub"],
    heroNotes: [
      "为 ChatGPT、Claude、Cursor 与重度终端工作流而生",
      "支持提示词历史、分组、置顶、回贴与 CLI 控制",
      "原生 SwiftUI 应用，支持 Homebrew 安装与本地优先存储",
    ],
    toolStrip: ["ChatGPT", "Claude", "Cursor", "终端", "文档"],
    deviceSidebarTitle: "AiPaste",
    deviceSidebarItems: ["全部片段", "已置顶", "工作", "归档"],
    deviceToolbarTitle: "最近剪贴内容",
    pill: "可搜索",
    clipApps: ["Claude", "Cursor", "终端"],
    clipTimes: ["刚刚", "2 分钟前", "8 分钟前"],
    clipTitles: [
      "把这个 API 错误重写成面向用户的说明，并给出下一步建议。",
      "把这个文件作为上下文，并给出最小且安全的补丁方案。",
      "./bin/aipaste items paste 1",
    ],
    clipBodies: [
      "终于调好的那条提示词，不必再靠记忆重构。",
      "把产出好结果的那段上下文，原样复用到下一次对话里。",
      "在浏览器、IDE 和终端之间切换时，也不会丢掉刚才那条关键回答。",
    ],
    floatTerminalLabel: "prompt ops",
    floatBadgeLabel: "AI Native，不是 AI 噪音",
    floatBadgeTitle: "保留有用上下文，丢掉重复复制粘贴带来的混乱。",
    metricsTitles: ["提示词就绪", "上下文检索", "跨工具闭环"],
    metricsBodies: [
      "把你最好的提示词、可复用指令和上下文片段，保持在一次搜索之内。",
      "无需记住精确措辞，也能按记忆找回命令、补丁、模型输出和零散片段。",
      "在 AI 对话、IDE、文档和终端之间切换时，不再丢状态。",
    ],
    storyEyebrow: "AI Native 工作流",
    storyTitle: "当你的工作一半是提示词工程，一半是执行时，剪贴板历史就是基础设施。",
    storyBody:
      "AiPaste 为开发者、创始人、运营和研究者而设计。你整天在模型对话、代码编辑器、文档和终端之间来回切换，而你的工作上下文需要始终保持完整。",
    useCasesEyebrow: "使用场景",
    useCasesTitle: "为每天都在和 AI 一起工作的人设计，而不是偶尔用一下的人。",
    useCaseLabels: ["PROMPTS", "CONTEXT", "OUTPUTS"],
    useCaseTitles: ["保留那条终于调通的提示词", "在不同工具之间复用代码与文档上下文", "在下一个标签页把它埋没前，先保存答案"],
    useCaseBodies: [
      "沉淀经过打磨的指令、思维框架包装、批判模板和可重复使用的提示词模式。",
      "把 GitHub 片段、终端日志、问题讨论和源文件内容，快速带入下一次 AI 交互。",
      "把有价值的模型回答、改写文案、SQL 修复、shell 命令和发布说明草稿保留在手边。",
    ],
    featureLabels: ["CAPTURE", "RETRIEVE", "ORGANIZE", "OPERATE"],
    featureTitles: [
      "持续捕获 AI 提示词、回答和命令，不打断你的思路。",
      "在思路断掉前，找回正确的提示词或答案。",
      "建立可复用的提示词、片段与上下文库。",
      "想用界面时用界面，AI 工作流脚本化时就直接上 CLI。",
    ],
    featureBodies: [
      "AiPaste 持续监听系统剪贴板，把 AI 会话中的工作片段保存在清晰、易扫读的布局里，而不是埋进拥挤列表。",
      "在最近片段中搜索、跨分组跳转，并结合应用来源信息，找回你之前复制过的提示词、代码块或模型输出。",
      "把常用提示词置顶、把片段移动到命名分组、给工作区上色，并排除噪音或敏感应用，让历史真正有用而不是越积越乱。",
      "通过终端命令显示或隐藏面板、粘贴指定片段、管理分组与修改配置，让它和你的 AI 工具链、开发环境保持同一种工作方式。",
    ],
    historyCardLabels: ["提示词", "上下文", "补丁", "输出"],
    historyCardTitles: [
      "总结错误日志，定位根因，然后给出最安全的最小修复方案。",
      "认证中间件、token 刷新路径、失败堆栈",
      "在尝试刷新前先保护空 session",
      "面向用户的事故说明摘要",
    ],
    searchInput: "搜索提示词、输出、应用、命令……",
    searchResultApps: ["Claude", "Cursor", "终端"],
    searchResultTitles: [
      "把这份更新说明改写成面向用户的版本，而不是工程师版本",
      "把这个文件作为上下文，只解释回归风险",
      "./bin/aipaste list --search release --limit 10",
    ],
    groupChips: ["claude", "cursor", "research"],
    groupTitles: ["评审提示词", "代码上下文块", "研究片段"],
    groupCounts: ["7 条", "12 条", "5 条"],
    capabilityLabels: ["AI LOOP", "PASTE BACK", "PRIVATE BY DEFAULT"],
    capabilityTitles: ["在提示词、输出、代码和文档之间顺滑切换", "把内容直接贴回上一个活跃应用", "让敏感 AI 上下文留在本地"],
    capabilityBodies: [
      "AiPaste 保留那些真正让 AI 工作变得可用的小块上下文，让它们跨多个标签页和工具持续可取。",
      "开启 macOS 辅助功能权限后，AiPaste 可以把内容直接贴回你刚才使用的应用。",
      "你的提示词、片段和复制过的输出都保存在原生、本地优先的应用里，而不是再套一层网页壳。",
    ],
    installEyebrow: "安装",
    installTitle: "选择最适合你工作方式的安装路径。",
    installLabels: ["HOMEBREW", "RELEASE ZIP", "CLI"],
    installTitles: ["适合日常使用", "适合直接下载", "适合可脚本化的 AI 工作流"],
    installBlocks: [
      "brew tap AiPaste/aipaste\nbrew install --cask aipaste\nbrew upgrade --cask aipaste",
      "打开 GitHub Releases\n下载最新 zip\n把 AiPaste.app 移动到 /Applications",
      "./bin/aipaste help\n./bin/aipaste list --limit 10\n./bin/aipaste items paste 1",
    ],
    faqEyebrow: "常见问题",
    faqTitle: "为 AI 重度使用者的原生 Mac 工作流而建。",
    faqQuestions: [
      "这是一个 AI 应用吗？",
      "数据是本地存储吗？",
      "可以自动化吗？",
      "可以直接贴回另一个应用吗？",
      "如何在本地预览这个网站？",
    ],
    faqAnswers: [
      "它是 AI Native 工具，但不是 LLM 外壳。AiPaste 管理的是 AI 工作周边的提示词、上下文和输出。",
      "是的。AiPaste 被设计为面向 macOS 的本地优先剪贴板工具。",
      "可以。内置 CLI 覆盖面板动作、条目动作、分组、忽略规则和配置管理。",
      "可以，前提是为 paste-to-app 动作授予 macOS 辅助功能权限。",
      '运行 <code>./scripts/serve_website.sh</code>，然后打开它输出的本地地址。',
    ],
    ctaEyebrow: "AiPaste",
    ctaTitle: "别再一次次从头重建同样的提示词和上下文。",
    ctaBody: "为那些在 macOS 上进行严肃 AI 工作、并且受够了丢失有效内容的人准备的原生剪贴板管理器。",
    ctaButtons: ["下载 Release", "在 GitHub 上 Star"],
    footerTagline: "基于 SwiftUI 构建的 AI Native macOS 剪贴板管理器。",
    footerLinks: ["仓库", "发布", "Homebrew Tap"],
  },
};

const setText = (selector, value) => {
  const node = document.querySelector(selector);
  if (node) node.textContent = value;
};

const setHtml = (selector, value) => {
  const node = document.querySelector(selector);
  if (node) node.innerHTML = value;
};

const setTexts = (selector, values) => {
  const nodes = document.querySelectorAll(selector);
  nodes.forEach((node, index) => {
    if (values[index] !== undefined) {
      node.textContent = values[index];
    }
  });
};

const applyLanguage = (lang) => {
  const copy = translations[lang] ?? translations.en;

  document.documentElement.lang = lang === "zh" ? "zh-CN" : "en";
  document.title = copy.title;

  const metaDescription = document.querySelector("#meta-description");
  if (metaDescription) {
    metaDescription.setAttribute("content", copy.metaDescription);
  }

  const nav = document.querySelector(".site-nav");
  if (nav) {
    nav.setAttribute("aria-label", copy.navAriaLabel);
  }

  const langSwitch = document.querySelector(".lang-switch");
  if (langSwitch) {
    langSwitch.setAttribute("aria-label", copy.langSwitchAriaLabel);
  }

  const heroNotes = document.querySelector(".hero-notes");
  if (heroNotes) {
    heroNotes.setAttribute("aria-label", copy.heroNotesAriaLabel);
  }

  const toolStrip = document.querySelector(".tool-strip");
  if (toolStrip) {
    toolStrip.setAttribute("aria-label", copy.toolStripAriaLabel);
  }

  const metricsStrip = document.querySelector(".metrics-strip");
  if (metricsStrip) {
    metricsStrip.setAttribute("aria-label", copy.metricsAriaLabel);
  }

  const heroHeadline = document.querySelector(".hero-headline");
  if (heroHeadline) {
    heroHeadline.setAttribute("aria-label", copy.heroHeadlineAriaLabel);
  }

  setText(".brand-copy span", copy.brandTagline);
  setTexts(".site-nav a", copy.nav);
  setText(".header-cta", copy.headerCta);
  setText(".hero .eyebrow", copy.heroEyebrow);
  setTexts(".hero-headline span", copy.heroHeadline);
  setText(".hero-lead", copy.heroLead);
  setTexts(".hero-copy .hero-actions a", copy.heroButtons);
  setTexts(".hero-notes li", copy.heroNotes);
  setTexts(".tool-strip span", copy.toolStrip);
  setText(".device-sidebar p", copy.deviceSidebarTitle);
  setTexts(".device-sidebar span", copy.deviceSidebarItems);
  setText(".device-toolbar strong", copy.deviceToolbarTitle);
  setText(".device-toolbar .pill", copy.pill);
  setTexts(".clip-preview .clip-app", copy.clipApps);
  setTexts(".clip-preview .clip-time", copy.clipTimes);
  setTexts(".clip-preview strong", copy.clipTitles);
  setTexts(".clip-preview p", copy.clipBodies);
  setText(".float-terminal p", copy.floatTerminalLabel);
  setText(".float-badge span", copy.floatBadgeLabel);
  setText(".float-badge strong", copy.floatBadgeTitle);
  setTexts(".metrics-strip article strong", copy.metricsTitles);
  setTexts(".metrics-strip article p", copy.metricsBodies);
  setText(".story-block .eyebrow", copy.storyEyebrow);
  setText(".story-block h2", copy.storyTitle);
  setText(".story-block .story-copy p:last-child", copy.storyBody);
  setText(".ai-usecases .eyebrow", copy.useCasesEyebrow);
  setText(".ai-usecases h2", copy.useCasesTitle);
  setTexts(".usecase-card .feature-label", copy.useCaseLabels);
  setTexts(".usecase-card h3", copy.useCaseTitles);
  setTexts(".usecase-card p:last-child", copy.useCaseBodies);
  setTexts(".feature-panel .feature-copy .feature-label", copy.featureLabels);
  setTexts(".feature-panel .feature-copy h3", copy.featureTitles);
  setTexts(".feature-panel .feature-copy p:last-child", copy.featureBodies);
  setTexts(".history-card span", copy.historyCardLabels);
  setTexts(".history-card strong", copy.historyCardTitles);
  setText(".search-input", copy.searchInput);
  setTexts(".search-result span", copy.searchResultApps);
  setTexts(".search-result strong", copy.searchResultTitles);
  setTexts(".group-chip", copy.groupChips);
  setTexts(".group-row strong", copy.groupTitles);
  setTexts(".group-row em", copy.groupCounts);
  setTexts(".capability-card .feature-label", copy.capabilityLabels);
  setTexts(".capability-card h3", copy.capabilityTitles);
  setTexts(".capability-card p:last-child", copy.capabilityBodies);
  setText(".install-section .eyebrow", copy.installEyebrow);
  setText(".install-section h2", copy.installTitle);
  setTexts(".install-card .feature-label", copy.installLabels);
  setTexts(".install-card h3", copy.installTitles);
  setTexts(".install-card pre code", copy.installBlocks);
  setText(".faq-section .eyebrow", copy.faqEyebrow);
  setText(".faq-section h2", copy.faqTitle);
  setTexts(".faq-grid h3", copy.faqQuestions);
  const faqBodies = document.querySelectorAll(".faq-grid article p");
  faqBodies.forEach((node, index) => {
    if (copy.faqAnswers[index] !== undefined) {
      node.innerHTML = copy.faqAnswers[index];
    }
  });
  setText(".cta-section .eyebrow", copy.ctaEyebrow);
  setText(".cta-section h2", copy.ctaTitle);
  setText(".cta-section > p:not(.eyebrow)", copy.ctaBody);
  setTexts(".cta-section .hero-actions a", copy.ctaButtons);
  setText(".footer-brand p", copy.footerTagline);
  setTexts(".footer-links a", copy.footerLinks);

  const langButtons = document.querySelectorAll(".lang-button");
  langButtons.forEach((button) => {
    button.classList.toggle("is-active", button.dataset.lang === lang);
  });

  localStorage.setItem("aipaste-lang", lang);
};

const storedLanguage = localStorage.getItem("aipaste-lang");
const browserLanguage = navigator.language.toLowerCase().startsWith("zh") ? "zh" : "en";
const initialLanguage = storedLanguage === "zh" || storedLanguage === "en" ? storedLanguage : browserLanguage;

document.querySelectorAll(".lang-button").forEach((button) => {
  button.addEventListener("click", () => {
    const nextLanguage = button.dataset.lang === "zh" ? "zh" : "en";
    applyLanguage(nextLanguage);
  });
});

applyLanguage(initialLanguage);

const yearNode = document.querySelector("#year");
if (yearNode) {
  yearNode.textContent = String(new Date().getFullYear());
}
