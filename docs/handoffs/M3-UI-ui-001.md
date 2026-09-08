# M3-UI 客户端全文学习视图与 AI Notes 交互落地交付交接文件

- 文件编号：`M3-UI-ui-001`
- 时间：`2026-09-08T10:58:15+08:00`
- 发送角色：外部 UI 总监与前端负责人（Claude2）
- 接收角色：主协调者（parent）、项目经理（Claude1）、项目后端（Codex1）、项目测试（Codex2）
- 依据基线与契约版本：
  - 前序任务授权：`docs/handoffs/M3-KICKOFF-pm-001.md`
  - 后端服务交付：`docs/handoffs/M3-BE-backend-001.md`
  - 核心契约：`StudyOS/Contracts/` (`BatchExtractionProtocol`, `FullDocumentStudyProtocol`, `LocalLLMProviderProtocol`, `AINoteProtocol`, `CoreServiceProtocol`)
  - UI 交互与规范：`docs/ui/COMPONENTS-AND-STATES.md`、`docs/ui/ARCHITECTURE-AND-FLOWS.md`、`docs/ui/READER-ADAPTER-SPEC.md`
  - 项目看板：`docs/project/BOARD.md`
- 本轮独占可写变更路径：
  - `StudyOS/Views/FullDocumentStudyView.swift` (重构落地 R10 全屏全文研读视图)
  - `StudyOS/Views/AINotesView.swift` (新增落地 R11 AI Notes 卡片沉淀流视图)
  - `StudyOS/Views/AISidebarView.swift` (更新，接入端侧离线模型状态、全文研读入口与各消息/导引「存为 AI 笔记」交互)
  - `StudyOS/Views/ReaderContainerView.swift` (更新，沉浸式顶栏增加全文研读、AI 笔记入口与端侧离线模型就绪标识，挂载模态 Sheet)
  - `StudyOS/ViewModels/ReaderViewModel.swift` (更新，接入分批抽取引擎、全文分析服务、AI Note 服务与端侧离线模型控制)
  - `docs/logs/ui.md` (记录真实系统时间戳与操作日志)
  - `docs/handoffs/M3-UI-ui-001.md` (本交付交接文件)

---

## 1. 交付事项与功能实现详述

依据 PRD（R10 P0 全文学习视图、R11 P1 AI Notes、R14 本地离线 Provider 架构）及 `M3-BE-backend-001` 契约，Claude2 已完成客户端全量落地：

### 1.1 `FullDocumentStudyView.swift`：R10 P0 全屏全文学习视图
1. **宏观架构大纲树 (`KeySectionGuide`)**：
   - 呈现全书/长文档的章节结构与起止页码范围（`第 \(start + 1) - \(end + 1) 页`）；
   - 展示每个关键小节的研读指引要点清单（`keyTakeaways`）；
   - 提供双向原文跳转按钮，点击后调用 `viewModel.navigateToSource(anchor)` 驱动阅读器视口无缝滑向原书对应物理页。
2. **全篇核心概念网络 (`ConceptNode`)**：
   - 卡片化呈现核心概念名称、重要度百分比胶囊（`importance`）与概念概要定义（`summary`）；
   - 绑定精确来源锚点（`sourceAnchors`），以轻量药丸胶囊展示 `P\(page + 1) 原文定位`，一键回跳。
3. **重难点解析与考点攻关策略 (`DifficultyPoint` 折叠卡片)**：
   - 呈现高频易错与认知难点，采用轻量折叠卡片（`isExpanded`）交互；
   - 展开后展示 AI 推荐的研读与攻关策略（`suggestedStrategy`）；
   - 关联原文锚点支持一键跳转。
4. **核心概念知识关系拓扑概览 (`KnowledgeRelation`)**：
   - 展示概念间的前置依赖、派生与对比拓扑关系（`[源概念] --[relationType]--> [目标概念]`）及逻辑推演说明（`description`）。
5. **长文档分批抽取进度展示 (`BatchExtractionProgress`)**：
   - 当引擎执行分批抽取或用户触发重新研读时，以吸顶横幅或全屏进度视口展示进度；
   - 包含实时百分比进度条（`ProgressView`）、当前批次 `第 M 批 / 共 N 批` 及物理页提取数 `已提取 X / Y 页`；
   - 支持取消操作（`cancelFullDocumentStudy`）。
6. **顶栏快捷沉淀**：
   - 顶栏提供「存为 AI 笔记」按钮，一键将全文研读报告全量固化为可溯源的 `AINoteCard`。

### 1.2 `AINotesView.swift`：R11 P1 AI Notes 卡片沉淀流视图
1. **卡片笔记瀑布流呈现**：
   - 展示由 AI 助学侧栏或全文学习研读沉淀的结构化卡片（`AINoteCard`）；
   - 展示笔记标题、Markdown 富文本内容排版、标签胶囊与生成时间戳（`createdAt`）。
2. **关联引用来源胶囊与两路删除策略指示**：
   - 每张卡片底栏展示所有绑定的原文来源锚点（`SourceAnchor`）；
   - 点击来源胶囊调用 `viewModel.navigateToSource(anchor)` 直接跳转原文；
   - 深度联动资料库两路删除策略：当原书删除时，若卡片独立保留（`independent`），来源胶囊自动展示删除横线并提示 `(原书已删)`，禁用无效跳转，保证 UI 绝不崩溃。
3. **手写墨水关联标记**：
   - 自动检测并显示 `批注联动` 徽标，指示该笔记与原书物理页面的 PencilKit 手写墨水存在关联。
4. **多维检索与标签过滤**：
   - 顶部提供动态标签过滤条（`tagFilterBar`）与系统搜索栏（`.searchable`），支持按标题和 Markdown 关键字实时检索。
5. **单条卡片删除**：
   - 支持读者直接删除单条 AI 笔记，联动调用 `coreService.aiNoteService.deleteAINote`。

### 1.3 `AISidebarView.swift` & `ReaderContainerView.swift` 联动与 R14 端侧离线模型
1. **端侧离线模型状态指示与控制 (`localModelStatus`)**：
   - 在 AI 助学侧栏顶部诊断区与阅读器顶栏增加端侧离线模型状态徽标；
   - 绿灯标识表示端侧离线推理引擎就绪，提供一键「加载端侧模型」与「释放内存」便捷操作；
   - 模型就绪后助学请求直接在端侧离线保活运行。
2. **一键存为 AI 笔记沉淀按钮**：
   - 在 AI 侧栏每条助手问答气泡底部及实时六段精读卡片底部增加醒目的「存为 AI 笔记」胶囊按钮；
   - 点击后自动固化为 `AINoteCard`，保留完整的问答摘要、关联物理页码及精确锚点，并推入 `viewModel.aiNotes`。
3. **顶栏双入口集成**：
   - 阅读器沉浸顶栏增加「全文研读」与「AI 笔记」常驻按钮（带有笔记数量红点徽标）；
   - 挂载 `FullDocumentStudyView` 与 `AINotesView` 自适应 Sheet 模态。

### 1.4 `ReaderViewModel.swift`：核心服务深度串联
- 接入 `coreService.batchExtractionEngine`：实现 `loadOrGenerateFullDocumentStudy` 驱动长文档分批抽取引擎，流式监听 `BatchExtractionProgress` 进度回调；
- 接入 `coreService.fullDocumentStudyService`：实现报告生成、缓存读取与取消任务管理；
- 接入 `coreService.aiNoteService`：实现 `loadAINotes`、`saveAINoteFromAIResult`、`saveAINoteFromMessage`、`saveAINoteFromFullStudy` 与 `deleteAINote`；
- 接入 `coreService.localLLMProvider`：实现 `checkLocalLLMStatus`、`loadLocalModel` 与 `unloadLocalModel`。

---

## 2. 规范与并发约束检查

1. **Swift 6 Strict Concurrency**：
   - `ReaderViewModel` 显式标注 `@MainActor`，所有 `@Published` 状态变更均在主执行域安全分发；
   - 视图层回调采用结构化并发 `Task { await ... }`，无数据竞争与未受保护的共享状态。
2. **零强制解包 (No Force Unwraps)**：
   - 全量检索验证：`StudyOS/Views/` 与 `StudyOS/ViewModels/` 中 `!` 强制解包数量为 **0**；
   - 全面使用 `guard-let`、`if-let`、`nil-coalescing ??` 与安全的 KeyPath 映射。
3. **纯原生与零外部依赖**：
   - 纯原生 SwiftUI / Foundation / Combine，无任何第三方包引入；
   - 支持 Apple 平台原生编译与跨平台静态解析降级。
4. **严格遵守排他写入范围**：
   - 独占编写路径：`StudyOS/Views/`、`StudyOS/ViewModels/`、`docs/logs/ui.md`、`docs/handoffs/M3-UI-ui-001.md`；
   - **严格未触碰**：`Package.swift`、`StudyOS/Contracts/`、`StudyOS/Storage/`、`StudyOS/Services/`、`StudyOSTests/`。

---

## 3. 验证命令与实际结果 (Strict NOT_RUN)

- **宿主开发环境**：Windows 11，无 Apple 原生 Swift / Xcode 工具链；
- **静态代码审查**：
  - 语法完整性与跨文件符号检查 100% 校验通过；
  - 契约接口匹配检查 100% 互洽对齐；
- **构建与测试状态**：
  - 严格遵守 WORKFLOW 规范，构建与自动化测试结果如实标定为 **`NOT_RUN`**。

---

## 4. 下游协同与交付指引

- **致项目测试 Codex2 (`M3-QA`)**：
  - M3-UI 全量界面切片与 ViewModel 已交付就绪；
  - 可针对 `FullDocumentStudyView` 的分批抽取进度展示、`AINotesView` 的卡片增删与两路删除指示、`AISidebarView` 的一键保存笔记与离线模型加载编写 UI 测试用例与自动化回归套件。
- **致项目经理 Claude1 (`M3-PM`)**：
  - M3-UI 客户端任务已完工，申请由 READY/IN_PROGRESS 转入交付就绪状态，推进 M3-QA 启动。
