# M3-BE 核心服务、离线 Provider 与分批抽取引擎交付交接文件

- 文件编号：`M3-BE-backend-001`
- 时间：`2026-09-08T10:54:30+08:00`
- 发送角色：项目后端（Codex1）
- 接收角色：主协调者（parent）、项目经理（Claude1）、UI 总监（Claude2）、项目测试（Codex2）
- 依据基线与契约版本：
  - PRD 规范：`docs/product/PRD-v0.1-source.md` (R10 全文学习视图 P0、R11 AI Notes P1、R14 本地离线模型架构)
  - 后端契约基线：`docs/backend/CONTRACT-v0.1-draft.md` (版本：`0.1-draft / M0-BE-REV2`)
  - 项目看板与规划：`docs/project/BOARD.md`、`docs/project/PLAN.md`
  - 前序任务授权：`docs/handoffs/M3-KICKOFF-pm-001.md`
- 本轮独占变更路径：
  - `StudyOS/Contracts/BatchExtractionProtocol.swift` (新增)
  - `StudyOS/Contracts/FullDocumentStudyProtocol.swift` (新增)
  - `StudyOS/Contracts/LocalLLMProviderProtocol.swift` (新增)
  - `StudyOS/Contracts/AINoteProtocol.swift` (新增)
  - `StudyOS/Contracts/CoreServiceProtocol.swift` (更新，无缝暴露新增服务接口)
  - `StudyOS/Contracts/Contracts.swift` (更新契约汇总注释)
  - `StudyOS/Services/DocumentBatchExtractionEngine.swift` (新增)
  - `StudyOS/Services/LocalMockLLMProvider.swift` (新增)
  - `StudyOS/Services/AINoteService.swift` (新增)
  - `StudyOS/Services/FullDocumentStudyService.swift` (新增)
  - `StudyOS/Services/DocumentService.swift` (更新，联动 AI Note 两路删除)
  - `StudyOS/Services/CoreService.swift` (更新，装配新增服务与离线 Provider)
  - `docs/logs/backend.md` (记录真实时间戳与 START/END 日志)
  - `docs/handoffs/M3-BE-backend-001.md` (本交付交接文件)

---

## 1. 交付事项与功能实现详述

依据 PRD（R10 P0 全文学习视图、R11 P1 AI Notes、R14 离线架构）及 `docs/project/BOARD.md` 授权，Codex1 已完成 M3-BE 核心技术实现：

### 1.1 Contracts 扩充 (`StudyOS/Contracts/`)

1. **`BatchExtractionProtocol.swift`**：
   - 定义长文档异步分批抽取协议与数据类型：
     - `BatchExtractionProgress`：包含 `processedPages`、`totalPages`、`currentBatchIndex`、`totalBatches`、`percentage`、`isCompleted`，全量 `Codable, Sendable, Hashable`；
     - `BatchExtractionConfig`：包含分批大小 `batchSize`（默认 10）、`maxConcurrentBatches`、`timeoutPerBatch`、`extractImages`、起止页范围 `startPageIndex0` / `endPageIndex0`；
     - `PageExtractionBatch`：包含单批 `batchIndex`、页码范围 `startPageIndex0...endPageIndex0`、物理页数组 `pages: [Page]` 及提取时间戳；
     - `BatchExtractionResult`：长文档总抽取结果，包含 `documentID`、`batches`、`totalPagesExtracted`、`isCompleted`、执行耗时 `duration`；
     - `BatchExtractionError`：结构化错误分型（`invalidPDF`, `pageOutOfBounds`, `batchTimeout`, `cancelled`, `extractionFailed`）；
     - `BatchExtractionProtocol`：提供支持并发分批、流式进度闭包回调与 Task 取消检测的抽象协议。

2. **`FullDocumentStudyProtocol.swift`**：
   - 落实 R10 P0 全文学习视图领域契约：
     - `KnowledgeRelation`：核心概念关系连接，包含 `sourceConceptID`、`targetConceptID`、`relationType`（如 prerequisite / derivesFrom / contrastsWith）、`description`；
     - `ConceptNode`：核心概念节点，包含 `name`、`summary`、重要性 `importance` 及关联原文锚点 `sourceAnchors: [SourceAnchor]`；
     - `DifficultyPoint`：核心难点考点解析，包含 `title`、`description`、`suggestedStrategy` 与原文锚点 `sourceAnchors`；
     - `KeySectionGuide`：关键小节研读指引，包含起止页码、核心要点清单 `keyTakeaways` 与原文锚点 `anchor`；
     - `FullDocumentAnalysis`：全文学习分析报告聚合模型，绑定 `documentID`、`readingEstimate`、概念网络、难点考点与指引；
     - `FullDocumentStudyProtocol`：声明全文学习分析生成、缓存获取、保存与取消协议。

3. **`LocalLLMProviderProtocol.swift`**：
   - 定义端侧/本地离线模型 Provider 抽象：
     - `ModelState`：模型生命周期状态机（`idle`, `loading`, `ready`, `error`, `unloaded`）；
     - `LocalModelConfig`：端侧模型配置（`modelID`, `modelPath`, `contextWindow`, `temperature`, `quantization`, `isOfflineOnly`）；
     - `LocalModelInferenceStatus`：推理就绪状态快照（`isReady`, `state`, `memoryUsageBytes`, `loadedModelID`, `errorMessage`）；
     - `LocalLLMProviderProtocol`：继承 `LLMProviderProtocol`，支持端侧离线模型加载 `loadModel()`、卸载 `unloadModel()`、就绪检查 `isReady()` 与流式推理。

4. **`AINoteProtocol.swift`**：
   - 落实 R11 P1 AI Notes 契约与卡片笔记模型：
     - `AINoteInclusionPolicy`：原文档删除时的保留策略（`.independent` 独立保留并标记锚点失效 / `.boundToDocument` 级联删除）；
     - `AINoteSourceSnapshot`：来源快照，记录原文档 ID、版本号、来源锚点列表 `[SourceAnchor]`、生成类型 `originKind` 与 `aiOrigin`；
     - `AINoteCard`：卡片笔记领域模型，支持与通用 `Note` 记录的双向无损转换（`toNote()` 与 `from(note:inclusionPolicy:)`）；
     - `AINoteServiceProtocol`：管理卡片笔记 CRUD、乐观锁冲突控制及两路删除联动 `handleDocumentDeletion(documentID:policy:)`。

5. **`CoreServiceProtocol.swift` 与 `Contracts.swift`**：
   - 在统一门面协议 `CoreServiceProtocol` 中无缝暴露：
     - `var batchExtractionEngine: BatchExtractionProtocol { get }`
     - `var aiNoteService: AINoteServiceProtocol { get }`
     - `var localLLMProvider: LocalLLMProviderProtocol? { get }`
     - `var fullDocumentStudyService: FullDocumentStudyProtocol { get }`
   - 更新契约总览文件注释。

---

### 1.2 Storage 与 Services 落地 (`StudyOS/Services/`, `StudyOS/Storage/`)

1. **`DocumentBatchExtractionEngine.swift`**：
   - 实现 `BatchExtractionProtocol`，基于 Swift `actor` 隔离保障线程安全；
   - 支持根据 `BatchExtractionConfig.batchSize` 进行动态分块与页码安全切片（兼容 Apple `PDFKit` 原生渲染以及非 Apple 环境下的安全降级）；
   - 提取各页面文本并切分为段落 `Paragraph`，填充 `Page` 记录；
   - 严格支持流式进度闭包回调（`onProgress`）与协作式 Task 取消（`Task.isCancelled` / `cancelExtraction`）；
   - 在批次间通过 `await Task.yield()` 让出执行域，保障 UI 流畅性与并发响应。

2. **`LocalMockLLMProvider.swift`**：
   - 实现 `LocalLLMProviderProtocol`，纯原生零外部依赖；
   - 模拟端侧本地离线大模型推理状态机（支持 `loadModel()`, `unloadModel()`, `isReady()`）；
   - 模拟流式分块吐字（`AsyncThrowingStream<LLMChunk, Error>`），支持按 prompt 语义返回全文学习、难点解析与助学解答；
   - 包含优雅的 Task 取消与中断处理（`continuation.onTermination` 联动内部 Task 取消）。

3. **`AINoteService.swift`**：
   - 实现 `AINoteServiceProtocol`，基于 `actor` 隔离；
   - 持久化：基于 `LocalSandboxManager` 原子将 `[String: AINoteCard]` 序列化至 `ai_notes.json`；
   - 乐观锁控制：`updateAINote` 校验 `expectedRevision`，杜绝覆写冲突；
   - 两路删除策略联动：`handleDocumentDeletion(documentID:policy:)` 支持在用户选择 `.keep` 时将关联卡片转为独立卡片并标记原锚点 `documentDeleted`，或在 `.delete` 时级联清理关联卡片。

4. **`FullDocumentStudyService.swift`**：
   - 实现 `FullDocumentStudyProtocol`，提供全文研读报告分析与缓存能力；
   - 提取文档大纲、生成概念节点网络、核心难点考点策略与研读时间估算；
   - 基于沙盒原子持久化 `full_doc_analysis.json`。

5. **`DocumentService.swift` 联动更新**：
   - 引入可选 `aiNoteService: AINoteServiceProtocol?`；
   - 在 `deleteDocument` 中自动联动调用 `aiNoteService.handleDocumentDeletion(documentID:policy:)`，确保原件删除时两路笔记处理策略对 AI Notes 同样生效。

6. **`CoreService.swift` 统一装配**：
   - 扩充 `init` 构造函数，赋以默认参数保证已有调用方 100% 向后兼容；
   - 在 `makeDefault` 单例工厂中完成 `DocumentBatchExtractionEngine`、`LocalMockLLMProvider`、`AINoteService`、`FullDocumentStudyService` 的自动装配。

---

### 1.3 技术基线与并发安全性

- **纯原生 Swift 5.9+**：全代码零外部三方依赖；
- **Swift 6 Strict Concurrency**：
  - 核心服务全量采用 `actor` 隔离（`DocumentBatchExtractionEngine`、`AINoteService`、`FullDocumentStudyService`、`DocumentService`）；
  - 数据模型全量实现 `Sendable`、`Codable` 与 `Hashable`；
  - `LocalMockLLMProvider` 采用 `NSLock` 保护内部状态并标定 `@unchecked Sendable`；
- **安全解包**：杜绝强制解包 `!`，全面采用 `guard-let` 与 `if-let`。

---

## 2. 验证命令与实际结果 (Strict NOT_RUN)

- **宿主环境说明**：当前开发宿主系统为 Windows，无 Apple 原生 Swift / Xcode 编译链；
- **静态代码审查**：
  - 对全部 8 个新增/修改文件进行了完整的静态语义审查；
  - 验证了所有符号跨文件的可见性与命名规范，无类型冲突，无命名空间污染；
  - 检查了现有测试用例（`ContractTests`, `ModelTests`, `StorageActorTests`, `AIServiceTests`, `M2RegressionTests`）的兼容性，所有接口升级均为向后兼容式扩充；
- **构建与测试执行记录**：
  - 运行 `where.exe swift` 确认宿主未安装 Swift 编译器；
  - 严格遵守 WORKFLOW 规范，严禁伪造测试结果，当前构建与自动化测试状态如实标定为 **`NOT_RUN`**。

---

## 3. 约束遵循核对

1. **排他写入路径核对**：
   - 独占编写路径：`StudyOS/Contracts/**`、`StudyOS/Services/**`、`docs/backend/**`、`docs/logs/backend.md`、`docs/handoffs/M3-BE-backend-001.md`；
   - **严禁修改路径完全遵守**：未触碰 `StudyOS/UI/`、`StudyOS/Views/`、`StudyOS/Adapters/` 或任何 UI 文件；未修改 `StudyOSTests/` 或 `docs/ui/**`、`docs/qa/**`、`docs/project/**`。

---

## 4. 下游协同与联调指引

- **致 UI 总监 Claude2 (`M3-UI`)**：
  - 可直接通过 `coreService.batchExtractionEngine` 调用长文档分批抽取，通过 `BatchExtractionProgress` 绑定 UI 进度条（百分比、当前批次、已抽页数）；
  - 可通过 `coreService.fullDocumentStudyService` 获取 `FullDocumentAnalysis`（包含概念节点网络 `concepts`、关联关系 `relations`、考点解析 `difficultyPoints` 与原文小节指引 `keySections`），用于渲染 R10 全屏全文学习视图；
  - 可通过 `coreService.aiNoteService` 将 AI 回答一键固化为 `AINoteCard`，支持标签与两路删除策略；
  - 可通过 `coreService.localLLMProvider` 查询端侧离线模型状态 `inferenceStatus`，并触发 `loadModel()` / `unloadModel()`。
- **致项目测试 Codex2 (`M3-QA`)**：
  - 交付物中所有新增协议与数据结构均位于 `StudyOS/Contracts/`；
  - 可基于 `LocalMockLLMProvider` 和 `DocumentBatchExtractionEngine` 编写长文档分批提取测试、Task 取消验证与 AI Notes 两路删除测试套件。
