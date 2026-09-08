# M4-BE-FIX 本地模型包调度器并发 Autoclosure 编译修复交接文件

- 文件编号：`M4-BE-FIX-backend-001`
- 时间：`2026-09-08T13:55:00+08:00`
- 发送角色：项目后端负责人（Codex1）
- 接收角色：主协调者（parent）、项目经理（Claude1）、UI 总监（Claude2）、项目测试（Codex2）
- 依据基线与契约版本：
  - PRD 规范：`docs/product/PRD-v0.1-source.md`（R12 网络弹性与高可用、R14 端侧离线模型架构）
  - 前序交接文件：`docs/handoffs/M4-BE-backend-001.md`
  - 故障反馈：CI 编译提示 `'async' call in an autoclosure that does not support concurrency`
- 本轮排他维护变更路径：
  - `StudyOS/Services/LocalModelPackageManager.swift`（修复 `executeWithHotFallback` 中的异步短路求值）
  - `docs/logs/backend.md`（记录真实系统时间戳与 READ_ACK/START/END 日志）
  - `docs/handoffs/M4-BE-FIX-backend-001.md`（本交接文件）

---

## 1. 故障根因与修复详述

### 1.1 根因分析
在 `StudyOS/Services/LocalModelPackageManager.swift` 的 `executeWithHotFallback` 方法中：
```swift
// 修复前：
if retryPolicy.canRetry(error: error) && (await localProvider.isReady()) {
    return try await localProvider.streamCompletion(messages: messages, options: options)
}
```
- Swift 标准库中逻辑与操作符 `func && (lhs: Bool, rhs: @autoclosure () throws -> Bool) rethrows -> Bool` 其右操作数为 `@autoclosure`；
- 该非异步闭包签名不支持在其上下文内执行 `await` 异步挂起调用，导致 Swift 编译器报错：`'async' call in an autoclosure that does not support concurrency`。

### 1.2 修复方案
将复合逻辑判断解构为嵌套安全条件分支，并在异步作用域中显式求值：
```swift
// 修复后：
if retryPolicy.canRetry(error: error) {
    let isLocalReady = await localProvider.isReady()
    if isLocalReady {
        return try await localProvider.streamCompletion(messages: messages, options: options)
    }
}
```
- 保持原有的短路求值语义（仅当 `canRetry` 为真时才发起 `isReady()` 检查）；
- 消除 `@autoclosure` 跨异步调用边界的语法约束；
- 完全契合 Swift 5.9+ / Swift 6 Strict Concurrency 规范。

---

## 2. 规范与排他规则合规自查

| 检查项 | 状态 | 详细说明 |
| :--- | :--- | :--- |
| **独占写入路径** | **完全合规** | 仅修改 `StudyOS/Services/LocalModelPackageManager.swift`、`docs/logs/backend.md` 并新增 `docs/handoffs/M4-BE-FIX-backend-001.md` |
| **严禁触碰路径** | **完全遵守** | 未触碰 UI、Views、Adapters 目录，未触碰 Tests 测试目录及 PM/UI 文档 |
| **严格并发安全** | **完全合规** | 遵循 Actor 隔离与异步调用规则，消除编译告警与错误 |
| **测试状态记录** | **完全合规** | Windows 宿主无 Swift 编译器，如实记录为 `NOT_RUN`，静态语法审查通过 |

---

## 3. 下一步建议

1. 请 CI 重新触发验证流水线；
2. 修复已就绪，交接主协调者（parent）、项目经理（Claude1）与测试负责人（Codex2）。
