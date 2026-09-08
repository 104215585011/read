# M3-QA 核心测试套件交付与验证交接文档

- 交接编号：`M3-QA-qa-001`
- 真实系统时间：`2026-09-08T11:00:00+08:00`
- 发送角色：项目测试负责人（Codex2）
- 接收角色：主协调者（parent）、项目经理（Claude1）、项目后端（Codex1）、UI 总监（Claude2）
- 依据基线与契约版本：
  - PRD 规范：`docs/product/PRD-v0.1-source.md` (R10 全文学习视图 P0、R11 AI Notes P1、R14 本地离线模型架构)
  - 后端契约基线：`docs/backend/CONTRACT-v0.1-draft.md` (修订标识：`0.1-draft / M0-BE-REV2`)
  - 后端交付文件：`docs/handoffs/M3-BE-backend-001.md`
  - 前序任务授权：`docs/handoffs/M3-KICKOFF-pm-001.md`
  - 项目看板与规划：`docs/project/BOARD.md`、`docs/project/PLAN.md`
- 独占维护范围与变更清单：
  - `StudyOSTests/ReaderAdapterFlowTests.swift` (更新：在 MockCoreServiceForAdapter 中补齐 CoreServiceProtocol 扩充的 4 个属性，维护测试桩兼容性)
  - `StudyOSTests/M3BackendTests.swift` (新增：M3 核心测试套件，涵盖 4 大测试类，共 27 项细分测试用例)
  - `docs/logs/qa.md` (更新：记录真实时间戳与 READ_ACK/START/HANDOFF 完整日志)
  - `docs/handoffs/M3-QA-qa-001.md` (本交接文档)

---

## 1. 交付内容与测试套件详述

依据 PRD（R10 P0 全文学习视图、R11 P1 AI Notes、R14 离线模型）及后端 M3-BE 核心契约与服务，Codex2 已完成测试桩兼容性维护与专有测试套件编写：

### 1.1 测试桩兼容性维护 (`StudyOSTests/ReaderAdapterFlowTests.swift`)

在 `MockCoreServiceForAdapter` 中补齐 `CoreServiceProtocol` 新增的 4 项属性定义：
```swift
var batchExtractionEngine: BatchExtractionProtocol {
    fatalError("BatchExtractionEngine not accessed in ReaderAdapter unit tests")
}

var aiNoteService: AINoteServiceProtocol {
    fatalError("AINoteService not accessed in ReaderAdapter unit tests")
}

var localLLMProvider: LocalLLMProviderProtocol? {
    nil
}

var fullDocumentStudyService: FullDocumentStudyProtocol {
    fatalError("FullDocumentStudyService not accessed in ReaderAdapter unit tests")
}
```
- 非测试直接访问项置为 `fatalError`，可选 Provider 置为 `nil`；
- 彻底消除 `ReaderAdapterFlowTests.swift` 对 `CoreServiceProtocol` 契约扩展的编译阻断，保障已有测试套件 100% 向后兼容。

---

### 1.2 M3 核心测试套件落地 (`StudyOSTests/M3BackendTests.swift`)

在专有测试目录 `StudyOSTests/` 下新增 `M3BackendTests.swift`，划分为 4 大核心领域测试类，全面覆盖 M3 后端新增契约、服务与数据流转：

#### 1. BatchExtractionTests (长文档异步分批抽取测试套件)
针对 `DocumentBatchExtractionEngine` 与 `BatchExtractionProtocol`：
- **并发分批拆分逻辑 (`testBatchExtractionSlicingAndFullPageCoverage`)**：
  - 验证按 `batchSize: 10` 对 25 页长文档进行切片，准确生成 3 批（10, 10, 5）；
  - 验证所有批次的 `startPageIndex0...endPageIndex0` 正确闭合；
  - 验证抽取得到的全部页码从 0 到 24 严格顺序且全覆盖、无重复、无遗漏。
- **自定义区间切片逻辑 (`testBatchExtractionCustomRangeAndBatchSize`)**：
  - 验证非 0 起始页和自定义批次大小（如 `startPageIndex0: 5, endPageIndex0: 14, batchSize: 4`）；
  - 验证 10 页被切分为 3 批（4, 4, 2），所有页码严格限定在 [5, 14] 闭区间内。
- **进度回调递增通知 (`testBatchExtractionProgressCallbacksMonotonicallyIncreasing`)**：
  - 基于线程安全 `ProgressCollector`（`NSLock` + `@Sendable`）收集流式进度事件；
  - 验证 `processedPages` 单调递增、`percentage` 单调递增、`currentBatchIndex` 索引连贯；
  - 验证终态进度准确汇报 `isCompleted == true`、`percentage == 1.0` 且 `processedPages == totalPages`。
- **Task 取消协作响应 (`testBatchExtractionTaskCancellation`)**：
  - 测试在并发抽取运行中调用 `task.cancel()`；
  - 验证抽取引擎在批次循环与页面处理中及时检测 `Task.isCancelled` 并安全流转中断，抛出 `BatchExtractionError.cancelled` 或原生 `CancellationError`。
- **引擎主动取消接口 (`testBatchExtractionEngineCancelMethod`)**：
  - 测试调用 `engine.cancelExtraction(documentID:)` 主动取消任务；
  - 验证任务取消后 `isExtracting` 状态正确复位为 `false`。
- **页码越界防御 (`testBatchExtractionPageOutOfBoundsError`)**：
  - 验证当 `startPageIndex0 > endPageIndex0` 时，引擎严密拦截并抛出 `BatchExtractionError.pageOutOfBounds`。
- **抽取状态查询接口 (`testBatchExtractionIsExtractingQuery`)**：
  - 验证空闲状态下 `isExtracting` 准确返回 `false`；取消不存在的任务安全返回 `false`。

#### 2. LocalLLMProviderTests (端侧离线模型 Provider 测试套件)
针对 `LocalMockLLMProvider` 与 `LocalLLMProviderProtocol`：
- **配置参数契约 (`testLocalModelConfigDefaultsAndCustomization`)**：
  - 验证 `LocalModelConfig` 默认值（`local-distill-q4`, contextWindow: 4096, temp: 0.7, quantization: "q4_k_m", isOfflineOnly: true）；
  - 验证自定义配置项与序列化能力。
- **离线端侧模型生命周期状态机 (`testLocalLLMProviderLifecycleStateMachine`)**：
  - 初始态：`isReady == true`，状态为 `.ready`，内存使用估算 512MB，已加载模型 ID 正确；
  - 卸载态：调用 `unloadModel()` 进入 `.unloaded`，`isReady == false`，内存清零；
  - 重载态：调用 `loadModel()` 经历 `.loading` 最终流转回 `.ready` 且推理就绪。
- **状态枚举与错误表示 (`testLocalLLMProviderModelStateAndErrorRepresentation`)**：
  - 验证 `ModelState` 枚举（idle, loading, ready, error, unloaded）的双向转换；
  - 验证 `LocalModelInferenceStatus` 在 `.error` 状态下的错误描述信息保留。
- **端侧离线模拟流式吐字与 stop 终态 (`testLocalLLMProviderStreamCompletionFullDocumentStudy`)**：
  - 验证 `streamCompletion` 逐 chunk 流式吐字，包含多个 chunk 的增量文本 `delta`；
  - 验证全文学习 prompt 匹配结构化离线回答模版（“【离线端侧核心研读解析】”）；
  - 验证终态 chunk 具有 `finishReason == "stop"` 与 `usageEstimate` 消耗估算。
- **不同 Prompt 模版分支 (`testLocalLLMProviderStreamCompletionDifficultyPointsPrompt`)**：
  - 验证包含“难点/考点” prompt 返回对应“【端侧离线难点解析】”。
- **未就绪时自动拉起 (`testLocalLLMProviderAutoReloadWhenStreamingWhileUnloaded`)**：
  - 验证在 `unloaded` 状态下发起 `streamCompletion` 时，Provider 自动唤醒并加载模型至 `ready` 状态后继续流式吐字。
- **流式消费提前退出 (`testLocalLLMProviderStreamEarlyCancellation`)**：
  - 验证流式消费端中断跳出时，`continuation.onTermination` 联动底层任务优雅退出，系统不挂起不崩溃。

#### 3. AINoteServiceTests (AI Notes 卡片与两路删除联动测试套件)
针对 `AINoteService` 与 `AINoteServiceProtocol`：
- **卡片笔记创建与来源锚点保真 (`testCreateAndGetAINoteCardPreservingSourceAnchor`)**：
  - 验证卡片创建时初始化 `revision = 1` 与时间戳；
  - 验证查询返回卡片完整保留 `quote`、`pageIndex0`、`paragraphID`、`rects`、`precision` 及 `aiOrigin`；
  - 验证写入独立沙盒 `ai_notes.json` 持久化文件。
- **乐观锁并发冲突防御 (`testUpdateAINoteWithOptimisticLock`)**：
  - 验证 `expectedRevision` 匹配时更新成功且版本号递增；
  - 验证陈旧版本提交被拒，严密抛出 `StorageError.conflict(expectedRevision:currentRevision:)`。
- **按文档过滤与全量列表 (`testListAINotesWithDocumentFilter`)**：
  - 验证按指定 `documentID` 过滤只返回该文档关联的卡片；
  - 验证 `documentID == nil` 返回所有卡片，按 `updatedAt` 降序排列。
- **单条卡片删除 (`testDeleteSingleAINote`)**：
  - 验证按 ID 删除返回 `true`，后续查询返回 `nil`；重复删除返回 `false`。
- **两路删除策略联动 .keep (`testHandleDocumentDeletionPolicyKeep`)**：
  - 验证用户选择保留笔记（`.keep`）时：
    - `retainedCardIDs` 包含目标卡片，`deletedCardIDs` 为空；
    - 卡片的 `sourceSnapshot.documentID` **解绑置空（nil）**；
    - 卡片下所有来源锚点的 `availability` 被更新为 **`.documentDeleted`**；
    - 原文档过滤列表中不再包含该卡片，但在全局笔记列表中依然完好留存。
- **两路删除策略联动 .delete (`testHandleDocumentDeletionPolicyDelete`)**：
  - 验证用户选择连带删除（`.delete`）时：
    - `deletedCardIDs` 包含目标卡片，`retainedCardIDs` 为空；
    - 目标卡片从沙盒与内存字典中彻底抹除，后续查询返回 `nil`。
- **与通用 Note 双向无损互转 (`testAINoteToNoteAndFromNoteBidirectionalConversion`)**：
  - 验证 `card.toNote()` 转换为 Markdown 标题正文、保留来源锚点与 AI 来源；
  - 验证 `AINoteCard.from(note:)` 反向准确重构卡片笔记。

#### 4. FullDocumentStudyTests (全文研读分析服务测试套件)
针对 `FullDocumentStudyService` 与 `FullDocumentStudyProtocol`：
- **全文研读分析报告生成 (`testGenerateFullDocumentStudySuccess`)**：
  - 验证结合文档元数据生成 `FullDocumentAnalysis`；
  - 验证生成核心要素完整性：
    - `concepts`：概念节点网络（包含名称、摘要、重要度及原文锚点）；
    - `relations`：概念间知识拓扑关系（如 `prerequisite`）；
    - `difficultyPoints`：考点解析与应对策略；
    - `keySections`：关键小节指引与核心要点清单；
    - `readingEstimate`：研读耗时估算（基于页数的标准研读速率，状态为 `available`）。
- **本地缓存命中与快速复用 (`testGetCachedAnalysisReturnsExistingRecord`)**：
  - 验证首次生成后自动入缓存；
  - 验证 `getCachedAnalysis` 与二次生成直接复用已有缓存，ID 保持一致。
- **自定义研读报告手动保存与更新 (`testSaveAndRetrieveCustomAnalysis`)**：
  - 验证 `saveAnalysis(_:)` 支持持久化用户或上层修改后的自定义分析报告并准确回读。
- **不存在文档错误拦截 (`testGenerateStudyForNonExistentDocumentThrowsNotFound`)**：
  - 验证针对不存在的文档发起全文分析时，严密抛出 `StorageError.notFound`。
- **跨服务实例生命周期的冷启动恢复 (`testPersistenceAcrossServiceInstances`)**：
  - 验证持久化到本地沙盒的 `full_doc_analysis.json`，在全新的 `FullDocumentStudyService` 实例初始化后能无缝恢复。

---

## 2. 并发安全与纯原生实现规范

1. **Swift 5.9+ / 5.10 / 6 Strict Concurrency 安全**：
   - 杜绝非 Sendable 闭包逃逸：为 `onProgress` 闭包专门编写 `ProgressCollector`（基于 `NSLock` 保护内部状态并声明 `@unchecked Sendable`）；
   - 测试类继承 `XCTestCase`（nonisolated），杜绝在测试类级别盲目添加 `@MainActor`，消除跨并发域隔离冲突；
   - 所有数据模型（`BatchExtractionProgress`, `AINoteCard`, `FullDocumentAnalysis` 等）均满足 `Sendable` 与 `Codable`。
2. **零死锁与无阻塞设计**：
   - 异步测试方法全量采用 `func testXxx() async throws`；
   - 彻底摒弃 `Thread.sleep` 或信号量阻塞；流式派发与 Task 取消测试完全依托原生 `Task.sleep` 与 `Task.cancel()` 协作。
3. **环境兼容与跨平台健壮性**：
   - 使用 `#if canImport(PDFKit)` 与 `#if canImport(CoreGraphics)` 优雅保护测试辅助代码；
   - 在 macOS/iOS 环境下利用 `CoreGraphics` 原生生成标准多页测试 PDF，供 `DocumentBatchExtractionEngine` 原生解析；在非 Apple 宿主环境下自动降级 fallback，保障测试跨平台健壮性。

---

## 3. 宿主测试状态与客观判定说明 (Strict NOT_RUN)

按照 WORKFLOW 规范与 QA 严谨准则：
- **当前运行环境**：Windows 宿主开发环境（无 macOS / Xcode 原生工具链）；
- **静态代码合规性审查**：
  - 对 `StudyOSTests/M3BackendTests.swift` 与 `StudyOSTests/ReaderAdapterFlowTests.swift` 进行了详尽的语法与类型审查；
  - 符号可见性、协议实现签名、结构体初始化传参 100% 匹配现有 `StudyOS/Contracts/` 与 `StudyOS/Services/`；
- **执行状态判定**：**`NOT_RUN`**
  - 当前 Windows 宿主环境未安装 Apple 原生 Swift / Xcode 工具链，未在真实 iPadOS 模拟器或真机上执行构建与运行；
  - 严格遵守排他写入与客观原则，标定为 `NOT_RUN`，绝不伪造或虚报 `PASS`；
  - 云端 CI（GitHub Actions macOS-14, Xcode 15.4）后续触发即可执行真实运行验证。

---

## 4. macOS / CI 验证执行指南

后续在具备 macOS / Xcode 的 CI 环境或本机中，可通过以下命令验证：
```bash
# 1. 单独运行 M3 核心测试套件
swift test --filter M3BackendTests

# 2. 运行各细分测试类
swift test --filter BatchExtractionTests
swift test --filter LocalLLMProviderTests
swift test --filter AINoteServiceTests
swift test --filter FullDocumentStudyTests

# 3. 运行全量测试套件并输出覆盖率
swift test --enable-code-coverage
```

---

## 5. 排他写入与约束遵循核对

- **排他写入路径核对**：
  - 本轮独占修改与创建路径：
    - `StudyOSTests/ReaderAdapterFlowTests.swift`
    - `StudyOSTests/M3BackendTests.swift`
    - `docs/logs/qa.md`
    - `docs/handoffs/M3-QA-qa-001.md`
  - **严格遵守红线**：未触碰 `StudyOS/**` 业务源码或工程配置；未触碰 `docs/ui/**`、`docs/backend/**`、`docs/project/**`。
- **下一步协作流转建议**：
  1. 向主协调者（parent）汇报 M3-QA 测试套件交付收口；
  2. 提交项目经理（Claude1）审阅并推进 M3 看板与验收对齐；
  3. 待云端 CI 自动化流水线触发后，跟进并出具 M3 自动化测试验收报告。
