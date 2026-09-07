# M2-BE-FIX OpenAICompatibleProvider 并发捕获修复交接文件

- 文件编号：`M2-BE-FIX-backend-001`
- 时间：`2026-09-08T00:20:30+08:00`
- 发送角色：项目后端负责人（Codex1）
- 接收角色：主协调者（parent）、项目经理（Claude1）、外部 UI 总监（Claude2）、项目测试（Codex2）
- 依据规范与原则：
  - Swift 5.9+ Complete / Strict Concurrency 规范
  - 协作规范：`docs/collaboration/WORKFLOW.md`
  - 角色排他规则：Codex1 独占维护 `StudyOS/Contracts/**`、`StudyOS/Services/**`、`StudyOS/Models/**`、`StudyOS/Storage/**`、`docs/backend/**`、`docs/logs/backend.md`，严禁修改 UI、Views 或测试目录
- 变更路径：
  - `StudyOS/Services/OpenAICompatibleProvider.swift`
  - `docs/logs/backend.md`
  - `docs/handoffs/M2-BE-FIX-backend-001.md`

---

## 1. 修复事项说明

### 1.1 背景与报错
在编译或并发检查时抛出：
`error: reference to captured var 'request' in concurrently-executing code: let (asyncBytes, response) = try await session.bytes(for: request)`

### 1.2 根因分析
在 `OpenAICompatibleProvider.streamCompletion(messages:options:)` 方法中：
- 构造阶段使用了可变变量 `var request = URLRequest(url: endpointURL)` 组装 Header 与 Body；
- 在返回 `AsyncThrowingStream<LLMChunk, Error>` 内部创建了并发闭包与 `Task { ... }`；
- 在并发执行的 `Task` 闭包中直接引用了外层的可变变量 `request`，这违反了 Swift Strict Concurrency 规则（并发执行代码中不可安全捕获外层可变 `var`）。

### 1.3 修复方案与代码变更
在组装完请求内容并准备进入 `AsyncThrowingStream` 前，将可变的 `request` 赋予不可变常量 `let finalRequest = request`（`URLRequest` 具备值语义并符合 `Sendable`），在闭包内使用 `finalRequest`：

```swift
        // 4. 返回异步流，由 URLSession.bytes 处理
        let session = self.urlSession
        let finalRequest = request
        return AsyncThrowingStream<LLMChunk, Error> { continuation in
            let task = Task {
                do {
                    // 支持 Task 级主动取消
                    if Task.isCancelled {
                        continuation.finish(throwing: LLMProviderError.cancelled)
                        return
                    }

                    let (asyncBytes, response) = try await session.bytes(for: finalRequest)
```

### 1.4 并发安全性与语法检查
- **类型安全**：`finalRequest` 为不可变局部常量，满足 `@Sendable` 闭包跨执行域访问安全；
- **生命周期与取消控制**：保持了 `task.cancel()` 与 `continuation.onTermination` 联动；
- **排他隔离边界**：本次变更仅局限于 `StudyOS/Services/OpenAICompatibleProvider.swift`，完全未修改 `StudyOS/UI/**`、`StudyOS/Views/**`、`Tests/**` 或测试目录。

---

## 2. 验证状态说明 (Windows 宿主真实状态)

依据 `WORKFLOW.md` 纪律，如实汇报环境与测试状态：
- 当前运行环境：Windows 宿主 (PowerShell)
- 验证方式：人工静态代码走查与 Swift Concurrency 语义核验（Manual Static Review Pass）
- 构建命令执行状态：**NOT_RUN**（当前环境缺少 Apple Swift/iOS SDK，未在 macOS 运行 `swift build`）

---

## 3. 后续交接与建议
1. 修复已完成并提交工作区；
2. 建议协调者通知 Xcode/macOS 构建环境重跑编译，以验证消除 `reference to captured var 'request'` 报错；
3. 交接主协调者（parent）、项目经理（Claude1）、UI 总监（Claude2）与项目测试（Codex2）。
