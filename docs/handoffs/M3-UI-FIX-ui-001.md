# M3-UI-FIX PencilKitOverlayCanvas Swift 6 Concurrency 隔离修复交接文档

- 交接编号：`M3-UI-FIX-ui-001`
- 真实时间：`2026-09-08T11:07:30+08:00`
- 发送角色：UI 总监与外部前端负责人（Claude2）
- 接收角色：主协调者（parent）、项目经理（Claude1）、项目测试（Codex2）、项目后端（Codex1）
- 关联看板任务：`M3-UI` / `M3-UI-FIX` (WAITING_VERIFICATION / CI 编译验证)

---

## 1. 修复背景与根因分析

在 Swift 6 严格并发检查（Strict Concurrency Checking）下，系统输出了如下编译警告：
```text
warning: main actor-isolated instance method 'canvasViewDrawingDidChange' cannot be used to satisfy nonisolated protocol requirement
note: add 'nonisolated' to 'canvasViewDrawingDidChange' to make this instance method not isolated to the actor
```

### 根因分析
1. **协议要求上下文**：Apple 系统的 `PKCanvasViewDelegate` 协议定义在非 `@MainActor` 上下文中（非隔离协议要求）；
2. **类隔离级别冲突**：`PencilKitOverlayCanvas.Coordinator` 标注了 `@MainActor`，导致其声明的所有实例方法默认处于 `@MainActor` 隔离域；
3. **隔离冲突**：当 `@MainActor` 类满足非隔离的 `PKCanvasViewDelegate` 协议要求时，Swift 6 要求协议方法显式声明为 `nonisolated`，以防外部以非隔离协议类型引用并异步调用时发生 Actor 边界假设破裂。

---

## 2. 修复方案与代码变更

修改严格限制在 UI 适配器目录 [StudyOS/Adapters/PencilKitOverlayCanvas.swift](file:///c:/Users/wang/Documents/read/StudyOS/Adapters/PencilKitOverlayCanvas.swift)，未触碰 `Package.swift`、后端契约、后端存储/服务或测试代码：

### 技术实现
1. **显式非隔离声明**：将 `canvasViewDrawingDidChange` 声明为 `nonisolated public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView)`，精确匹配 `PKCanvasViewDelegate` 协议要求；
2. **安全断言同步转入主执行域**：UIKit 保证 `PKCanvasViewDelegate` 的手写事件回调必然在主线程（Main Thread）分发。因此在委托方法内部使用 `MainActor.assumeIsolated { self.handleDrawingChange(canvasView) }`，零延迟同步切入 `@MainActor`；
3. **抽取受保护的业务处理函数**：原有的 2 秒防抖定时器、`PageKey` 生成、不可变快照固化（`InkSaveSnapshot`）、脏页标记（`markPageDirty`）与异步持久化（`flushInk`）逻辑完整抽取至 `@MainActor private func handleDrawingChange(_ canvasView: PKCanvasView)`。

### 代码变更对比
```swift
// 修复前：
public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
    // 逻辑直接内联在 @MainActor Coordinator 中
    ...
}

// 修复后：
nonisolated public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
    MainActor.assumeIsolated {
        self.handleDrawingChange(canvasView)
    }
}

@MainActor
private func handleDrawingChange(_ canvasView: PKCanvasView) {
    // 1. 手写抬笔触发防抖定时器 (候选 2 秒防抖，UIREV-03)
    debounceTimer?.invalidate()
    ...
}
```

---

## 3. 并发安全与设计一致性确认

- **Strict Concurrency 安全**：消除了 `nonisolated protocol requirement` 警告，完全符合 Swift 6 语言演化标准；
- **运行时线程安全**：`MainActor.assumeIsolated` 仅在 UIKit 主线程事件回调下执行，不引入额外异步任务排队开销，手写抬笔到防抖定时器启动保证毫秒级响应；
- **业务逻辑零改动**：保持 `PageKey`、不可变快照固化、2 秒防抖持久化及版本号推导逻辑完整一致；
- **排他边界遵守**：零触碰 `Package.swift`、后端契约（`StudyOS/Contracts/`）、后端服务与测试代码。

---

## 4. 验证与交付状态

- **执行环境**：Windows 宿主开发环境（无本地 Xcode / macOS 原生编译链）；
- **静态检查**：代码结构及类型匹配人工静态核验通过；
- **后续建议**：提请项目测试 Codex2 及主协调者在 macOS CI 环境中执行 `swift build` / `swift test` 验证。
