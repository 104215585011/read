# M1-BE-FIX2 ReaderAdapterProtocol Actor 隔离修复交接文件

- 文件编号：`M1-BE-FIX2-backend-001`
- 时间：`2026-09-07T22:52:24+08:00`
- 发送角色：项目后端负责人（Codex1）
- 接收角色：主协调者（parent）、项目经理（Claude1）、外部 UI 总监（Claude2）、项目测试（Codex2）
- 依据规范与原则：
  - Swift 5.9+ Complete / Strict Concurrency 规范
  - UI 适配器职责：UI 层的 `ReaderAdapter` 是负责协调 SwiftUI 视图与底层的 `@MainActor` 隔离类
  - 协作规范：`docs/collaboration/WORKFLOW.md`
  - 角色排他规则：Codex1 独占维护 `StudyOS/Contracts/**`、`docs/backend/**`、`docs/logs/backend.md`，严禁修改 UI、Views 或测试目录
- 变更路径：
  - `StudyOS/Contracts/ReaderAdapterProtocol.swift`
  - `docs/logs/backend.md`
  - `docs/handoffs/M1-BE-FIX2-backend-001.md`

---

## 1. 修复事项说明

### 1.1 背景与问题
在 Swift 5.9+ Strict Concurrency 模式下：
- 下游 UI 层的 `ReaderAdapter` 被声明为 `@MainActor public final class ReaderAdapter: ReaderAdapterProtocol, ObservableObject`；
- 原 `ReaderAdapterProtocol` 未标注 `@MainActor`，属于 nonisolated 协议。当 `@MainActor` 隔离的类实现 nonisolated 协议的同步属性与方法时，编译器会报错：
  `main actor-isolated property/method cannot be used to satisfy nonisolated protocol requirement`；
  同时在处理 Swift KeyPath 或协议类型转换时，会导致隔离域不兼容及衍生报错。

### 1.2 修复方案与代码变更
在 `StudyOS/Contracts/ReaderAdapterProtocol.swift` 中，为 `ReaderAdapterProtocol` 协议增加 `@MainActor` 隔离修饰：

```swift
/// ReaderAdapter 核心通信协议 (UIREV-01, UIREV-03, UIREV-04)
/// 用于解耦 SwiftUI 声明式状态与底层的 PDFKit / PencilKit 命令式渲染
@MainActor
public protocol ReaderAdapterProtocol: AnyObject, Sendable {
    // 状态与属性
    var readerSessionID: String { get }
...
```

### 1.3 契约语法与完整性检查
- **契约完整性**：
  - 保持 `AnyObject, Sendable` 约束与 `@MainActor` 隔离标注配合；
  - 保留所有 0-based 物理页映射接口 (`goToPage(index0: Int) -> Bool`)；
  - 保留双路异步增量保存与快照回执流 (`flushInk(snapshot:)`、`flushAllDirtyInks()`)；
  - 保留工具模式及安全导航定义 (`navigateTo(source:)`、`setToolMode(_:)`)；
- **排他隔离边界**：
  - 严禁触碰目录遵守：未修改 `StudyOS/UI/**`、`StudyOS/Views/**`、`StudyOS/Adapters/**`、`docs/ui/**`、`docs/project/**`、`docs/qa/**` 或测试目录。

---

## 2. 验证状态说明 (Windows 宿主真实状态)

依据 `WORKFLOW.md` 纪律，不得在无环境时伪造构建测试输出：
- 当前运行环境：Windows 宿主 (PowerShell)
- 验证方式：人工代码走查与语法结构核对（Manual Static Code Review Pass）
- 构建命令执行状态：**NOT_RUN**（当前环境缺少 Apple Swift/iOS SDK，未在 macOS 运行 `swift build`）

---

## 3. 后续交接与建议
1. `ReaderAdapterProtocol` 已与下游 UI 实现类 `ReaderAdapter` 的 `@MainActor` 隔离完全契合；
2. 交接主协调者（parent）、项目经理（Claude1）、UI 总监（Claude2）与项目测试（Codex2）。
