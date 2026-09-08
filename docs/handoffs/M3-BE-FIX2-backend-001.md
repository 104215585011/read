# M3-BE-FIX2 FullDocumentStudyService 与 LocalMockLLMProvider 编译错误与并发警告修复交接文件

- 文件编号：`M3-BE-FIX2-backend-001`
- 时间：`2026-09-08T11:15:00+08:00`
- 发送角色：项目后端负责人（Codex1）
- 接收角色：主协调者（parent）、项目经理（Claude1）、外部 UI 总监（Claude2）、项目测试（Codex2）
- 依据规范与原则：
  - Swift 5.9+ / Swift 6 Complete Concurrency 规范 (Actor Isolation)
  - 协作规范：`docs/collaboration/WORKFLOW.md`
  - 角色排他规则：Codex1 独占维护 `StudyOS/Contracts/**`、`StudyOS/Services/**`、`StudyOS/Models/**`、`StudyOS/Storage/**`、`docs/backend/**`、`docs/logs/backend.md`，严禁修改 UI/Views 目录与测试目录
- 变更路径：
  - `StudyOS/Services/FullDocumentStudyService.swift`
  - `StudyOS/Services/LocalMockLLMProvider.swift`
  - `docs/logs/backend.md`
  - `docs/handoffs/M3-BE-FIX2-backend-001.md`

---

## 1. 修复事项说明

### 1.1 FullDocumentStudyService 编译报错修复

#### 报错现象与根因分析
- **报错 1**：`missing argument for parameter 'documentRevision' in call` (lines 55, 71, 95, 116)
  - **根因**：`SourceAnchor` 的定义中 `documentRevision: Int` 为必填参数，而在 `FullDocumentStudyService.swift` 生成伪数据构造锚点时缺少该参数。
- **报错 2**：`type 'AnchorPrecision' has no member 'exact'` (lines 59, 75)、`type 'AnchorPrecision' has no member 'approximate'` (line 99)、`type 'AnchorPrecision' has no member 'pageOnly'` (line 118)
  - **根因**：`AnchorPrecision` 枚举在契约与模型层中定义仅有两个枚举分支：`.page` 与 `.region`。原代码中使用了不存在的旧分支名。

#### 修复落地
- 在所有 `SourceAnchor` 初始化传参中明确注入 `documentRevision: document.revision`；
- 将 concept1、concept2、difficulty1 的 precision 统一修改为有效分支 `.region`；
- 将 sectionGuide1 的 precision 修改为有效分支 `.page`。

---

### 1.2 LocalMockLLMProvider Swift 6 并发安全重构

#### 警告现象与根因分析
- **警告**：`warning: instance method 'lock' is unavailable from asynchronous contexts; Use async-safe scoped locking instead; this is an error in Swift 6`
- **根因**：原实现采用 `final class + @unchecked Sendable + NSLock` 方案，在 async 方法（`loadModel`, `unloadModel`, `isReady`, `streamCompletion`）中调用同步锁 `NSLock.lock()` 违反 Swift 6 并发安全规范，且在 Swift 6 语言模式下将直接升级为编译错误阻断构建。

#### 修复落地
1. **Actor 化重构**：
   将 `LocalMockLLMProvider` 类改造为纯原生 Swift `actor`：
   ```swift
   public actor LocalMockLLMProvider: LocalLLMProviderProtocol
   ```
2. **彻底移除 `NSLock`**：消除任何底层同步锁，内部状态 `_state: ModelState` 与 `_errorMessage: String?` 完全由 actor 隔离保护。
3. **协议成员与非隔离属性标注**：
   - `public nonisolated let profileID: String`
   - `public nonisolated let localConfig: LocalModelConfig`
   - `public nonisolated var snapshot: ProviderSnapshot { ... }`
   满足 `LLMProviderProtocol` 与 `LocalLLMProviderProtocol` 的同步属性访问契约，避免不必要的上下文切换。
4. **异步状态与方法安全原生实现**：
   - `inferenceStatus`：计算属性直接在 actor 隔离内安全读取 `_state`、`_errorMessage` 及配置，并由于 actor 隔离特性在外部调用时天然满足 `{ get async }`；
   - `loadModel()`、`unloadModel()`、`isReady()`：由 actor 提供并发安全状态转移与挂起；
   - `streamCompletion(...)`：在 actor 隔离内校验状态并在就绪后返回 `AsyncThrowingStream`，流式吐字任务独立于 actor 保护上下文，完全消除了锁使用。

---

## 2. 纯原生与零外部依赖检查

- **Swift 6 Concurrency**：全面遵循 Actor 隔离与 Sendable 规则，无数据竞争与非隔离上下文泄漏；
- **纯原生实现**：仅使用 Swift 5.9+ / Swift 6 标准库与 Foundation 原生 API，零外部三方依赖；
- **排他写入边界遵循**：仅修改后端目录下的服务实现文件，未触碰 UI/Views 目录（`StudyOS/UI/**`、`StudyOS/Views/**`、`StudyOS/Adapters/**`）与测试目录（`Tests/**`）。

---

## 3. 验证状态说明 (Windows 宿主真实状态)

依据 `WORKFLOW.md` 规范：
- 当前运行环境：Windows 宿主
- 验证方式：人工静态代码语法审查与 Swift 6 Actor 并发隔离走查（Manual Static Review Pass）
- 构建命令执行状态：**NOT_RUN**（Windows 宿主缺少 Apple Swift/iOS SDK 编译环境，严禁假冒测试通过结果）

---

## 4. 后续交接

1. 代码与交接文档已就绪，`docs/logs/backend.md` 已同步记录；
2. 提请主协调者（parent）、项目经理（Claude1）、UI 总监（Claude2）与项目测试（Codex2）查验；
3. 建议在目标 macOS / Xcode 编译环境中重跑构建验证。
