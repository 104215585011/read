# M1-UI-FIX2 适配器 Swift Concurrency / @MainActor 隔离修复交接文档

- 交接编号：`M1-UI-FIX2-ui-001`
- 真实时间：`2026-09-07T17:42:40+08:00`
- 发送角色：UI 总监与外部前端负责人（Claude2）
- 接收角色：主协调者、项目经理（Claude1）、项目测试（Codex2）、项目后端（Codex1）
- 关联看板任务：`M1-SETUP` (WAITING_VERIFICATION / CI 编译验证)

---

## 1. 修复背景与问题定位

在 Swift 5.9+ / Swift 6 Strict Concurrency 编译检查下，`ReaderAdapter` 作为 `@MainActor` 隔离的类，在被 `PDFKitPlatformBridge` 与 `PencilKitOverlayCanvas` 的 `Coordinator` 调用时，存在跨执行域调用与通知闭包隔离冲突：

1. **`PDFKitPlatformBridge.Coordinator` 缺少 `@MainActor` 隔离与通知闭包跨域调用**：
   - 原 `Coordinator` 类未显式标注 `@MainActor`；
   - `NotificationCenter.default.addObserver` 的回调闭包属于非隔离执行域，直接在闭包内同步调用 `@MainActor` 隔离的 `adapter.updateCurrentPageFromScroll(pageIndex0:)` 与 `self.handleSelectionChange(in: pdfView)` 会引发 Swift Concurrency 跨执行域调用错误；
   - `handleSelectionChange(in:)` 内部调用的 `adapter.updateSelection` 需要保证在 `@MainActor` 隔离环境中执行。

2. **`PencilKitOverlayCanvas.Coordinator` 缺少 `@MainActor` 标注与定时器闭包隔离**：
   - 原 `Coordinator` 类未显式标注 `@MainActor`；
   - `Timer.scheduledTimer` 回调闭包中的 `Task` 启动前对 `self` 的解包在非隔离上下文中存在潜在隐患，需确保对 `adapter` 的所有访问（包括防抖保存 `adapter.flushInk` 与脏页标记 `adapter.markPageDirty`）完全处于 `@MainActor` 执行域中。

---

## 2. 修复实施清单与技术细节

修改严格限于客户端适配器目录 `StudyOS/Adapters/`，未触碰 `Package.swift`、后端契约、后端服务或测试代码：

| 文件路径 | 修改类型 | 修复说明与设计考量 |
|---|---|---|
| `StudyOS/Adapters/PDFKitPlatformBridge.swift` | 并发隔离 | 1. 为 `Coordinator` 增加 `@MainActor` 标注：`@MainActor public final class Coordinator: NSObject`；<br>2. 在 `attach(to pdfView:)` 的 `.PDFViewPageChanged` 与 `.PDFViewSelectionChanged` 通知中心回调闭包中，使用 `Task { @MainActor [weak self, weak pdfView] in ... }` 将通知回调无缝切换至 `@MainActor` 上下文；<br>3. 在 `@MainActor` 上下文中安全调用 `self.adapter.updateCurrentPageFromScroll(pageIndex0:)` 与 `self.handleSelectionChange(in: pdfView)`；<br>4. `handleSelectionChange(in:)` 继承类的 `@MainActor` 隔离，内部对 `adapter.updateSelection(anchor:screenRect:)` 的调用完全处于主执行域，安全合规。 |
| `StudyOS/Adapters/PencilKitOverlayCanvas.swift` | 并发隔离 | 1. 为 `Coordinator` 增加 `@MainActor` 标注：`@MainActor public final class Coordinator: NSObject, PKCanvasViewDelegate`；<br>2. `canvasViewDrawingDidChange` 代理方法天然处于 `@MainActor`，安全访问 `adapter.currentDocumentID`、`adapter.readerSessionID` 与 `adapter.markPageDirty`；<br>3. 在 `Timer.scheduledTimer` 闭包中，使用 `Task { @MainActor [weak self] in ... }` 切换至 `@MainActor` 后再安全解包并调用 `await self.adapter.flushInk(snapshot:)`，确保所有对 `adapter` 的访问与修改均在主执行域。 |

---

## 3. 并发安全与设计一致性确认

- **执行域一致性**：`ReaderAdapter`、`PDFKitPlatformBridge.Coordinator`、`PencilKitOverlayCanvas.Coordinator` 以及所有 SwiftUI 视图层均统一对齐 `@MainActor`，消除了任何同步跨 Actor 边界调用的可能；
- **异步解耦**：通知回调与定时器触发时通过 `Task { @MainActor [...] in }` 规范调度，弱引用安全解包，无循环引用与内存泄漏隐患；
- **零破坏性**：保持所有公开接口、协议定义与逻辑时序不变，完全对齐 `READER-ADAPTER-SPEC.md`。

---

## 4. 验证情况

- **执行环境**：Windows 宿主开发机（无本地 macOS / Xcode 工具链）；
- **静态比对状态**：`git diff` 严格核对无误，仅变更必要并发属性与调度包装；
- **交付建议**：请主协调者在 CI / macOS 环境触发工程编译与单元测试验证。
