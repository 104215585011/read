# M2-BE 核心服务与 Provider 基础设施交付交接文件

- 文件编号：`M2-BE-backend-001`
- 时间：`2026-09-07T23:56:00+08:00`
- 发送角色：项目后端（Codex1）
- 接收角色：主协调者（parent）、项目经理（Claude1）、UI 总监（Claude2）、项目测试（Codex2）
- 依据基线与契约版本：
  - 后端契约基线：`docs/backend/CONTRACT-v0.1-draft.md` (版本：`0.1-draft / M0-BE-REV2`)
  - UI 交互与适配规范：`docs/ui/READER-ADAPTER-SPEC.md` (版本：`v0.3-aligned-be-rev2`)
  - 项目看板与规划：`docs/project/BOARD.md`、`docs/project/PLAN.md`
  - 前序任务授权：`docs/handoffs/M2-KICKOFF-pm-001.md`
- 本轮独占变更路径：
  - `StudyOS/Contracts/LLMProviderProtocol.swift` (新增)
  - `StudyOS/Contracts/AIServiceProtocol.swift` (新增)
  - `StudyOS/Contracts/CoreServiceProtocol.swift` (更新，暴露 `aiService`)
  - `StudyOS/Contracts/Contracts.swift` (更新契约汇总注释)
  - `StudyOS/Services/OpenAICompatibleProvider.swift` (新增)
  - `StudyOS/Services/ContextAggregator.swift` (新增)
  - `StudyOS/Services/AIService.swift` (新增)
  - `StudyOS/Services/CoreService.swift` (更新，装配 `aiService`)
  - `docs/logs/backend.md` (更新日志)
  - `docs/handoffs/M2-BE-backend-001.md` (本交接文件)

---

## 1. 交付事项与功能实现详述

依据 PRD 与 `docs/backend/CONTRACT-v0.1-draft.md` 规范，Codex1 已高质量完成 M2-BE 核心服务与 Provider 基础设施实施：

### 1.1 Contracts 扩充 (`StudyOS/Contracts/`)
1. **`LLMProviderProtocol.swift`**：
   - 定义 `LLMRole` (`system`, `user`, `assistant`)、`LLMMessage`、`LLMChunk` (delta 吐字、finishReason、usageEstimate) 与 `LLMCompletionOptions`；
   - 强类型结构化错误枚举 `LLMProviderError`：
     - `.unauthorized(String)`：401/403 鉴权失败；
     - `.rateLimited(retryAfterSeconds: Int?, String)`：429 超频限制与冷却时间；
     - `.serverError(statusCode: Int, String)`：500/502/503 远端服务错误；
     - `.networkError(String)`：底层通信与传输异常；
     - `.cancelled`：主动取消；
     - `.timeout`：握手或响应超时；
     - `.unsupportedCapability(String)`：不支持的能力特性；
     - `.invalidResponse(String)`：非标准响应或解析损坏；
   - 协议 `LLMProviderProtocol`：定义 `profileID`、`snapshot: ProviderSnapshot` 以及基于 Swift 原生异步流的 `func streamCompletion(messages:options:) async throws -> AsyncThrowingStream<LLMChunk, Error>`。
2. **`AIServiceProtocol.swift`**：
   - 声明 `generateStream(request:manifest:) async throws -> AsyncThrowingStream<LLMChunk, Error>`；
   - 声明主动取消机制 `cancel(requestID:attemptID:) async -> Bool`；
   - 声明锚点校验 `validateSources(sources:) async -> [SourceAnchor]`。
3. **`CoreServiceProtocol.swift`**：
   - 在统一门面协议中新增并暴露 `var aiService: AIServiceProtocol { get }`。

### 1.2 Services 落地 (`StudyOS/Services/`)
1. **`OpenAICompatibleProvider.swift`**：
   - 纯原生零第三方依赖，基于 `URLSession.bytes(for:)` 实现 SSE (Server-Sent Events) 流式长连接；
   - 深度支持 `Task.isCancelled`、`continuation.onTermination` 与底层 `Task` 协同取消；
   - 严格解析 `data: {...}` 增量 JSON 及 `[DONE]` 结束标记，逐 chunk 吐字；
   - 准确映射 HTTP 状态码（401/403, 429 Retry-After, 5xx）与 `URLError.timedOut` / `cancelled`。
2. **`ContextAggregator.swift`**：
   - 五级动态上下文聚合引擎（依据 `AIScope` 精准装配）：
     - **Level 1 Selection**：选区文本与其精确所属页码锚点；
     - **Level 2 Page**：当前单页正文文本；
     - **Level 3 Chapter**：当前章节跨起止页文本合并；
     - **Level 4 Document**：全书目录结构大纲或元数据摘要；
     - **Level 5 Conversation**：多轮问答历史与用户最新提问；
   - 动态装配生成结构完备的 `ContextManifest`：
     - 计算各条目的 `payloadDigest`、`byteCount`、`characterCount`、`pageCoverage`；
     - 显式标记隐私脱敏状态：`originalFileInclusion` (默认排除原始 PDF)、`pageImageInclusion`、`handwritingInclusion` (默认排除本地手写)、`annotationInclusion`；
     - 保守估算 `estimatedInputTokens` 与预留 `reservedOutputTokens`；
   - 组装包含严格学习防幻觉规则的学术专家 System Prompt 与清晰结构化的 User Prompt。
3. **`AIService.swift`**：
   - 基于 Swift Actor 隔离保障线程安全，内部管理尝试状态字典 `attempts`；
   - 严格保障终态状态机：`completed`、`failed`、`cancelled` 互斥；
   - **`alreadyTerminal` 防御**：进入终态后，迟到的数据包或流事件一律忽略；对已终态的请求调用 `cancel` 返回 `false`，杜绝终态覆写；
   - 每次请求派发新的 `attemptID`，防止旧 attempt 响应污染新任务。
4. **`CoreService.swift`**：
   - 构造与装配 `aiService`；
   - `makeDefault(provider:)` 便捷单例方法提供默认 OpenAICompatibleProvider 配置与装配。

### 1.3 技术基线与依赖约束遵守
- 遵循 Swift 5.9+ 并发规范（`Sendable`, `actor`, `async/await`, `@MainActor` 隔离边界清晰）；
- 核心服务层保持**纯原生实现，零重度外部第三方库依赖**。

---

## 2. 验证命令与实际结果 (Strict NOT_RUN)

- **宿主环境说明**：当前开发宿主系统为 Windows，无 Apple 原生 Swift / Xcode 编译链；
- **静态代码走查**：
  - 对新写代码进行了详尽的代码语义走查，严格核对符号定义、泛型参数、Sendable 隔离性、Actor 可重入防护与可选型解包安全；
  - 确认下游 `LibraryViewModel`、`ReaderViewModel` 等现有代码完全向后兼容；
- **构建与测试执行记录**：
  - 本地运行 `swift --version` 返回 `CommandNotFoundException`；
  - 严格遵循 WORKFLOW 真实性规范，严禁在 Windows 环境下伪造 macOS / iPadOS 测试结果；
  - 本地自动化测试与构建状态如实标定为 **`NOT_RUN`**。

---

## 3. 约束遵循核对

1. **排他路径**：
   - 严格独占编写与修改了：`StudyOS/Contracts/**`、`StudyOS/Services/**`、`docs/backend/**`、`docs/logs/backend.md`、`docs/handoffs/M2-BE-backend-001.md`；
   - **严禁修改路径已完全遵守**：未修改 `StudyOS/UI/`、`StudyOS/Views/`、`StudyOS/Adapters/` 任何文件；未修改 `StudyOSTests/` 或 `docs/ui/**`、`docs/qa/**`、`docs/project/**`。

---

## 4. 下一步协作建议

1. **通知项目经理（Claude1）**：M2-BE 实施已收口交付，可审阅并推进看板；
2. **激活第二波次 M2-UI（Claude2）**：
   - UI 端可无缝引用 `coreService.aiService` 与 `LLMProviderProtocol`；
   - 在 `AISidebarView` 中实现流式打字机逐字响应，基于 `AsyncThrowingStream` 与 `alreadyTerminal` 防御完善 `failed` / `cancelled` 互斥交互；
   - 接入设置面板配置 `OpenAICompatibleProvider`（API Key、Base URL、Model 等）；
3. **激活第三波次 M2-QA（Codex2）**：
   - 准备 Provider 流式 Mock 与网络异常断言测试，在云端 CI（macOS-14 runner）执行真实验证。
