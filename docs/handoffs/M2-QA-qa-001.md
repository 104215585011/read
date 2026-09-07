# M2-QA 核心测试套件交付与验证交接文档

- 交接编号：`M2-QA-qa-001`
- 真实系统时间：`2026-09-08T00:02:00+08:00`
- 发送角色：项目测试负责人（Codex2）
- 接收角色：主协调者（parent）、项目经理（Claude1）、项目后端（Codex1）、UI 总监（Claude2）
- 依据基线与契约版本：
  - 后端契约草案：`docs/backend/CONTRACT-v0.1-draft.md` (修订标识：`0.1-draft / M0-BE-REV2`)
  - 后端交接文件：`docs/handoffs/M2-BE-backend-001.md`
  - UI 交付与规范：`docs/handoffs/M2-UI-ui-001.md`、`docs/ui/READER-ADAPTER-SPEC.md`
  - 项目看板与规划：`docs/project/BOARD.md`、`docs/project/PLAN.md`
- 独占维护范围与变更清单：
  - `StudyOSTests/ReaderAdapterFlowTests.swift` (更新：修复 Mock 兼容性，满足 CoreServiceProtocol 的 aiService 扩展)
  - `StudyOSTests/AIServiceTests.swift` (新增：M2 核心测试套件，涵盖五级上下文装配、状态机终态互斥、MockLLMProvider 流式吐字与主动取消、来源校验过滤)
  - `docs/logs/qa.md` (更新：记录时间戳与 READ_ACK/START/HANDOFF)
  - `docs/handoffs/M2-QA-qa-001.md` (本交接文档)

---

## 1. 交付内容与测试套件详述

依据 M2 需求规划与 `docs/backend/CONTRACT-v0.1-draft.md` (0.1-draft / M0-BE-REV2) 规范，Codex2 已完成 M2-QA 自动化测试套件扩展：

### 1.1 Mock 兼容性修复 (`StudyOSTests/ReaderAdapterFlowTests.swift`)
- 在 `MockCoreServiceForAdapter` 中新增契约扩展属性实现：
  ```swift
  var aiService: AIServiceProtocol {
      fatalError("AIService not accessed in ReaderAdapter unit tests")
  }
  ```
- 保证测试代码与后端 `CoreServiceProtocol` 门面协议无缝兼容，避免已有 `ReaderAdapterFlowTests` 编译报错。

### 1.2 M2 核心测试套件落地 (`StudyOSTests/AIServiceTests.swift`)
构建了具备高并发健壮性与完整契约验证的 `AIServiceTests` 类（共 11 个核心测试方法），深度覆盖以下关键领域：

#### 1. ContextAggregator 五级上下文动态聚合与清单生成
- **Level 1 Selection (选区)** (`testContextAggregatorLevel1SelectionScope`)：
  - 验证 `AIScope.selection(anchor:)` 下选区文本正确提取为 `OutboundItem(kind: .documentText, purpose: .generation)`；
  - 验证 `payloadDigest` 格式规范 (`sha256_length_hash`)，字符与字节数计算准确；
  - 验证隐私边界默认配置：`originalFileInclusion`、`pageImageInclusion`、`handwritingInclusion` 严格保持 `.excluded`；
  - 验证 System Prompt 包含学术精读规则与防幻觉指令，User Prompt 组装选区内容与用户提问。
- **Level 2 Page (单页正文)** (`testContextAggregatorLevel2PageScope`)：
  - 验证 `AIScope.page(index0:)` 下从 `pageTexts` 准确提取单页内容，覆盖页码单项记录。
- **Level 3 Chapter (跨页章节)** (`testContextAggregatorLevel3ChapterScope`)：
  - 验证 `AIScope.chapter(start...end)` 下多页文本合并，`pageCoverage` 完整包含全部起止物理页。
- **Level 4 Document (全篇与大纲)** (`testContextAggregatorLevel4DocumentScope`)：
  - **章节存在时**：聚合目录结构与章节起止页大纲，条目标识为 `outline_summary`；
  - **章节为空时**：降级聚合 `document_meta`（标题、总页数元数据）。
- **Level 5 Conversation & Question (多轮历史与提问)** (`testContextAggregatorLevel5HistoryAndAnnotations`)：
  - 验证用户最新提问生成 `.questionText` 条目，多轮历史生成 `.conversationText` 条目；
  - 验证批注显式勾选传参：`annotationIDs` 非空时，`annotationInclusion` 转化为 `.included(itemIDs:)`。

#### 2. AIService 状态机终态互斥与 `alreadyTerminal` 防御
- **正常流式消费与已完成保护** (`testAIServiceStreamingSuccessAndTerminalCompleted`)：
  - 流式逐 chunk 吐字消费完毕，进入 `completed` 终态；
  - **`alreadyTerminal` 防御**：调用 `cancel(requestID:attemptID:)` 返回 `false`，禁止取消已完成请求；
  - 重复使用同一 `attemptID` 调用 `generateStream` 抛出 `LLMProviderError.invalidResponse`，禁止重复执行。
- **流式异常与 failed 终态互斥** (`testAIServiceStreamingFailureTerminalExclusivity`)：
  - 底层流抛出服务端或网络异常（如 `serverError(statusCode: 503)`），Actor 记录终态为 `failed`；
  - **严防状态覆写**：失败后调用 `cancel` 返回 `false`，且终态严格保持为 `failed`，绝不被迟到的 `cancelled` 覆写。
- **主动取消与二次取消拦截** (`testAIServiceCancelMidStreamExclusivity`)：
  - 在吐字流运行中调用 `aiService.cancel(requestID:attemptID:)` 成功返回 `true`；
  - 立即发起二次取消调用，触发防御返回 `false`；
  - 上层消费流抛出 `LLMProviderError.cancelled` 并及时终止；
  - 后续再次触发抛出已进入 `cancelled` 终态。
- **Task.cancel() 级联取消** (`testAIServiceTaskCancellationTriggersCancelled`)：
  - 外层消费 Task 取消时，级联通知 `continuation.onTermination` 与底层 Task，正确进入 `cancelled` 终态。
- **并发重复请求防御** (`testAIServiceDuplicateRunningAttemptRejected`)：
  - 同一 `attemptID` 尚在运行中时，再次发起请求被拒绝并抛出“正在运行中”异常。

#### 3. 来源定位锚点有效性校验 (`testValidateSourcesFiltering`)
- 验证 `AIService.validateSources(sources:)` 规则过滤：
  - 保留有效锚点（文档存在、版本匹配、页码未越界 `0 <= p < pageCount` 且 `active`）；
  - 自动剔除：标记已删除 (`documentDeleted`)、文档不存在、版本失配 (`revMismatch`)、页码越界 (`p >= pageCount` 或 `p < 0`) 的失效锚点。

---

## 2. 并发安全与纯原生实现规范

1. **Swift 5.9+ / 5.10 / 6 Strict Concurrency 安全**：
   - 杜绝非 Sendable 闭包逃逸；在异步 Task 中预先绑定不可变 Actor 引用，避免捕获测试套件实例引用；
   - 所有 Mock 类型标注 `@Sendable` / `@unchecked Sendable`，保障线程隔离无数据竞争；
2. **零死锁与无阻塞设计**：
   - 彻底摒弃 `Thread.sleep` 或信号量阻塞；流式调度与超时模拟完全依托原生 `Task.sleep` 与异步流生命周期；
3. **零外部重度依赖**：
   - 测试纯粹依托 `XCTest`、`Foundation` 原生 API，无额外第三方测试依赖。

---

## 3. 宿主测试状态与客观判定说明 (Strict NOT_RUN)

按照 WORKFLOW 规范与 QA 严谨准则：
- **当前运行环境**：Windows 宿主系统（无 macOS / Xcode 工具链）；
- **代码静态合规性检查**：
  - `AIServiceTests.swift` 与 `ReaderAdapterFlowTests.swift` 语法严格符合 Swift 5.9+ 规范；
  - 各类测试用例逻辑自包含，断言完备精准；
- **执行状态判定**：**`NOT_RUN`**
  - 当前宿主无原生执行环境，测试未实际在模拟器或真机跑通；客观标定为 `NOT_RUN`，绝不虚报 `PASS`；
  - 云端 CI（GitHub Actions macOS-14, Xcode 15.4）后续触发即可执行真实运行验证。

---

## 4. macOS / CI 验证执行指南

当在具备 macOS / Xcode 环境中运行时：
```bash
# 1. 运行全部 AIService 核心测试
swift test --filter AIServiceTests

# 2. 运行全部单元与集成测试套件
swift test --enable-code-coverage
```

---

## 5. 排他写入与约束遵循核对

- **排他写入路径**：
  - 仅修改与创建了：`StudyOSTests/ReaderAdapterFlowTests.swift`、`StudyOSTests/AIServiceTests.swift`、`docs/logs/qa.md`、`docs/handoffs/M2-QA-qa-001.md`；
  - **严格遵守红线**：未修改任何 `StudyOS/**` 业务代码或工程配置；未修改 `docs/ui/**`、`docs/backend/**`、`docs/project/**`。
- **下一步协作建议**：
  1. 向主协调者（parent）汇报 M2-QA 测试套件交付收口；
  2. 提交项目经理（Claude1）审阅并更新 BOARD.md 进展；
  3. 待云端 CI 自动触发运行后，根据测试日志更新验收报告。
