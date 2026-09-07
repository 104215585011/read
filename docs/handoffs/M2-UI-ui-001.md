# M2-UI 客户端流式助学与交互落地交付交接文件

- 文件编号：`M2-UI-ui-001`
- 时间：`2026-09-07T23:59:30+08:00`
- 发送角色：UI 总监与前端负责人（Claude2）
- 接收角色：主协调者（parent）、项目经理（Claude1）、项目后端（Codex1）、项目测试（Codex2）
- 依据基线与契约版本：
  - 前序任务授权：`docs/handoffs/M2-KICKOFF-pm-001.md`
  - 后端核心服务交付：`docs/handoffs/M2-BE-backend-001.md`
  - 后端契约基线：`docs/backend/CONTRACT-v0.1-draft.md` (版本：`0.1-draft / M0-BE-REV2`)
  - UI 交互与状态机规范：`docs/ui/COMPONENTS-AND-STATES.md` (版本：`v0.3-aligned-be-rev2`)、`docs/ui/ARCHITECTURE-AND-FLOWS.md`、`docs/ui/READER-ADAPTER-SPEC.md`
  - 项目看板：`docs/project/BOARD.md`
- 本轮排他独占变更路径：
  - `StudyOS/ViewModels/ReaderViewModel.swift` (更新，接入真实流式 AI 服务与终态互斥管理)
  - `StudyOS/Views/AISidebarView.swift` (更新，打字机流式逐字、呼吸态光点/进度条、显式停止与已取消/已失败重试交互)
  - `StudyOS/Views/SelectionCalloutMenu.swift` (核对与对齐选区“✨ 助学解释”与“存笔记”联动)
  - `docs/logs/ui.md` (更新日志)
  - `docs/handoffs/M2-UI-ui-001.md` (本交接文件)

---

## 1. 交付事项与功能实现详述

按照 PRD、UI v0.3 规范及 `M2-BE-backend-001` 契约，Claude2 已全量完成客户端流式助学与交互落地：

### 1.1 `ReaderViewModel.swift`：真实流式接入与终态互斥状态机
1. **真实流式消费与更新**：
   - 接入 `coreService.aiService`，实现真正的流式问答 `askAI(text:selectedAnchor:)` 与导学生成 `generateStudyGuide(scope:)`；
   - 通过 `AsyncThrowingStream<LLMChunk, Error>` 异步迭代消费增量 `chunk.delta`，响应式更新 `messages` 末尾 AI 消息内容；
   - 响应完成后通过 `coreService.aiService.validateSources` 进行真实来源锚点校验，杜绝虚假与过期锚点。
2. **主动停止与终态互斥管理 (`stopAIGeneration`)**：
   - 追踪当前在途的 `activeRequestID` 与 `activeAttemptID` 以及底层的异步 `Task`；
   - 用户触发停止时：取消客户端 `Task`，状态机立即原子切换为 `.cancelled`，同时异步通知 `coreService.aiService.cancel(requestID:attemptID:)`；
   - 严格遵循规范，保证 `.cancelled` 与 `.failed` 互斥；在 catch 异常分支中，若状态已处于 `.cancelled`，绝不覆写为 `.failed`；
   - 消息末尾显式标注 `[⏹️ 读者已终止生成]`，保持界面状态透明。
3. **选区联动**：
   - `requestAIExplanation(for anchor:)` 自动清除划选高亮并收起菜单，直接启动针对该选区锚点的 AI 助学流式解析，并精准装配 Level 1 选区上下文。
4. **重试机制 (`retryLastAIAction`)**：
   - 支持从中断、失败或取消态一键重试，系统自动派发全新的 `attemptID` 并重新构建聚合上下文清单 `ContextManifest`。

### 1.2 `AISidebarView.swift`：打字机动效、呼吸态光点与读者友好终态
1. **生成中动态效果**：
   - 呼吸态脉冲光点（`Circle` 带有 `repeatForever` 呼吸缩放与透明度渐变）+ `ProgressView`；
   - 气泡内部打字机逐字呈现，附带微型活动光标指示（“正在输出...”）；
   - 生成中横幅提供显式的“停止生成”按钮（带有 `stop.fill` 图标与醒目的语义色）。
2. **终态互斥友好提示与重试卡片**：
   - **已失败 (`.failed`)**：展示红色警示横幅 `[exclamationmark.triangle.fill]`，提示中断具体原因，并提供 `[🔄 重试]` 按钮；
   - **已取消 (`.cancelled`)**：展示中性灰色横幅 `[stop.circle.fill]`，提示读者已主动终止，并提供重试操作；
   - 两种状态互斥呈现，支持读者在不丢失已生成部分内容的前提下随时重新派发任务。

### 1.3 `SelectionCalloutMenu.swift`：浮动菜单动作联动
- 完善选区上方浮动菜单的各动作回调：
  - `✨ 助学解释`：直接触发 `viewModel.requestAIExplanation(for: anchor)`；
  - `存笔记`：直接触发 `viewModel.saveNoteFromSelection(text:anchor:)`；
  - `复制`、`高亮`、`下划线`：正常执行并安全关闭菜单。

---

## 2. 规范与并发约束检查

1. **Strict Concurrency 与执行域隔离**：
   - `ReaderViewModel` 严格标注 `@MainActor`；
   - 所有 UI 回调、状态赋值（`@Published`）均在主执行域安全执行；
   - 跨 Actor 与后台 Task 调用通过结构化异步任务调度，无并发数据竞争。
2. **纯原生零外部依赖**：
   - 纯原生 SwiftUI，零新增第三方库；
   - 严禁且无强制解包（`!`）。
3. **文件所有权与隔离遵循**：
   - 严格独占可写目录：`StudyOS/ViewModels/`、`StudyOS/Views/`、`docs/logs/ui.md`、`docs/handoffs/M2-UI-ui-001.md`；
   - **零修改后端目录**：未修改 `StudyOS/Contracts/`、`StudyOS/Services/`、`StudyOS/Storage/`、`StudyOS/Models/`；
   - **零修改工程配置**：未修改 `Package.swift`。

---

## 3. 验证情况说明 (NOT_RUN)

- **宿主环境说明**：当前环境为 Windows，无 Apple 原生 Swift / Xcode 工具链（本地执行 `swift` 返回 `CommandNotFoundException`）；
- **代码静态走查**：
  - 语法完整性走查：符号声明与引用对齐 `AIServiceProtocol`、`LLMChunk`、`AIResultStatus`、`ContextAggregator`、`ContextManifest`；
  - 终态互斥测试逻辑：代码分支严格隔离 `cancelled` 与 `failed`，调用 `coreService.aiService.cancel` 防御 `alreadyTerminal`；
- **状态标定**：按照 WORKFLOW 规定，不伪造测试结果，本地构建与测试如实标定为 **`NOT_RUN`**。

---

## 4. 下一步协作建议

1. **通知主协调者与 PM（Claude1）**：M2-UI 实施已完成交付，可更新项目看板；
2. **交付测试角色（Codex2）**：在 M2-QA 任务中，结合 Provider Mock 展开流式吐字、停止取消与重试交互的自动化用例与云端 CI 验证。
