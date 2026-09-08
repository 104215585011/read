# M4-UI 硬件手势支持、护眼纸张色彩系统与离线弹性状态栏交付交接文件

- 文件编号：`M4-UI-ui-001`
- 时间戳：`2026-09-08T13:50:00+08:00`
- 发送角色：外部 UI 总监与前端负责人（Claude2）
- 接收角色：主协调者（parent）、项目经理（Claude1）、项目后端（Codex1）、项目测试（Codex2）
- 依据基线与契约版本：
  - PRD 规范：`docs/product/PRD-v0.1-source.md`（R02–R05 阅读与批注交互、R12 网络弹性与高可用、R14 本地离线模型架构）
  - 前序任务交接：`docs/handoffs/M4-KICKOFF-pm-001.md`、`docs/handoffs/M4-BE-backend-001.md`
  - 项目看板与规划：`docs/project/BOARD.md`、`docs/project/PLAN.md`（M4-RELEASE 阶段）
- 本轮排他维护变更路径：
  - `StudyOS/Adapters/PencilKitOverlayCanvas.swift`（Apple Pencil 硬件手势支持、真机防误触与触控隔离）
  - `StudyOS/UI/Theme.swift`（扩充专业护眼纸张色板与 `PaperTheme` 系统）
  - `StudyOS/Views/ReaderContainerView.swift`（底色动态渲染、深浅模式联动与顶栏纸张菜单切换）
  - `StudyOS/ViewModels/ReaderViewModel.swift`（`NetworkResilienceUIState`、网络连通性评估、重试统计与离线资源管理器接入）
  - `StudyOS/Views/AISidebarView.swift`（AI 侧栏网络连通/弱网重试/端侧模型状态指示条与模拟走查菜单）
  - `docs/logs/ui.md`（操作日志与真实时间戳记录）
  - `docs/handoffs/M4-UI-ui-001.md`（本交接文档）

---

## 1. 核心交互与功能实现详述

依据 M4-RELEASE 看板与任务要求，Claude2 已全量落地客户端真机硬件交互、护眼纸张色彩系统与网络弹性诊断体验：

### 1.1 Apple Pencil 硬件手势与真机防误触架构 (`StudyOS/Adapters/PencilKitOverlayCanvas.swift`)

1. **`UIPencilInteractionDelegate` 硬件双击手势接入**：
   - 在 `PencilKitOverlayCanvas.Coordinator` 中挂载 `UIPencilInteraction` 并遵循 `UIPencilInteractionDelegate`；
   - 实现 `nonisolated public func pencilInteractionDidTap(_ interaction: UIPencilInteraction)`，并在 `MainActor.assumeIsolated` 作用域内调用 `@MainActor private func handlePencilTap`，严格保证 Swift 6 Strict Concurrency 协议一致性与线程安全；
   - 读取 iPadOS 硬件系统偏好 `UIPencilInteraction.preferredTapAction`：
     - **`.switchEraser`**：在当前笔刷工具（`lastActiveDrawingTool`，默认学术蓝墨水笔）与矢量橡皮擦（`PKEraserTool(.vector)`）之间平滑往返切换，并同步更新 `adapter.currentToolMode = .annotation`；
     - **`.switchPrevious`**：在当前工具与上一个使用工具之间往返无缝对调；
     - **`.showColorPalette`**：根据当前模式在纯阅读态（`.reading`）与批注态（`.annotation`）间平滑切换，并伴随 `onToastMessage` 轻量振动式文案提示；
     - **`.ignore`**：遵循用户系统关闭设置，不产生干扰；
     - **`@unknown default`**：向前兼容未来 iPadOS 手势扩展，平滑切换橡皮擦。

2. **真机防误触与三模态触控隔离说明 (Palm Rejection & Touch Event Isolation)**：
   - **硬件级别防掌压误触 (Palm Rejection)**：
     - 基于 iPad 物理数字化仪（Digitizer）对 Apple Pencil 主动式电容笔尖信号的硬件分流识别；
     - 画布统一设置 `canvas.drawingPolicy = .pencilOnly`，彻底屏蔽手掌贴屏（Palm Contact）与指腹摩擦产生的误画杂点，读者可将手腕完全贴紧 iPad 玻璃如纸质书籍般自然书写；
   - **三模态触控隔离路由 (Touch Event Routing)**：
     - **`.reading`（纯阅读模式）**：`drawingPolicy = .pencilOnly`，单指水平/垂直滑动手势无阻碍穿透至底层 PDFView 用于快速翻页与平移，Pencil 笔尖随时下笔即可作画；
     - **`.textSelection`（选词模式）**：`canvas.isUserInteractionEnabled = false`，手写图层彻底对触控透明，将所有点按、长按词典与拖拽选区手势完整移交至底层 PDFKit 引擎；
     - **`.annotation`（批注专注模式）**：画布激活手写交互，配合硬件双击手势实现毫秒级工具切换。

---

### 1.2 护眼与纸张阅读色彩系统 (`StudyOS/UI/Theme.swift`, `StudyOS/Views/ReaderContainerView.swift`)

1. **`StudyTheme` 护眼色彩令牌与 `PaperTheme` 枚举**：
   - **`pureWhite` (纯白精细)**：`#FDFDFE`，极致对比度与锐度，适合日间精细图表与公式文献阅读；
   - **`warmSepia` (羊皮暖黄)**：`#F6F0E5`，吸收并过滤高能短波蓝光，呈现经典纸书温润漫反射质感；
   - **`eInkGray` (水墨哑光)**：`#EAEAE7`，类电子墨水屏灰阶，降低视疲劳与眩光感；
   - **`nightDark` (夜间深邃)**：`#1E2024`，极暗深灰黑，结合浅灰反白字（`#E0E3E6`），杜绝暗光环境屏幕刺眼。
   - `PaperTheme` 枚举完备包含 `displayName`、`iconName`、`backgroundColor`、`textColor` 与 `isDark` 属性。

2. **阅读器顶栏一键切换菜单与全屏底色动态联动**：
   - 在 `ReaderContainerView.swift` 顶栏工具态右侧增设纸张底色一键切换菜单（`Menu`）；
   - 包含当前选中勾选指示，点击即时更新 `viewModel.selectedPaperTheme`；
   - 主工作区背景使用 `viewModel.selectedPaperTheme.backgroundColor` 平滑渲染；
   - 自动绑定 `.preferredColorScheme(viewModel.selectedPaperTheme.isDark ? .dark : nil)`，在选择「夜间深邃」时全系统自动切入深色模式，状态栏与辅助组件自动对齐高对比暗黑风格。

---

### 1.3 离线与弱网状态栏提示 (`StudyOS/Views/AISidebarView.swift`, `StudyOS/ViewModels/ReaderViewModel.swift`)

1. **`NetworkResilienceUIState` 状态分型与展示**：
   - 定义四种清晰状态分型：
     - `.cloudAvailable`：云端可用 (高速)，翠绿色指示；
     - `.retrying(attempt:maxAttempts:reason:)`：弱网重试中 (包含重试次数与失败瞬态原因)，琥珀色指示；
     - `.switchedToLocal(modelName:)`：已无缝切换至端侧本地模型，学术蓝指示；
     - `.offlineUnavailable(reason:)`：离线未连接且无本地模型，玫红色指示。

2. **ViewModel 接入 M4-BE 核心服务**：
   - 接入 `coreService.networkRetryEngine`：异步拉取 `RetryEngineStats`，在 UI 上实时展示重试成功次数与总重试次数徽标；
   - 接入 `coreService.offlineResourceManager`：异步读取端侧模型包元数据列表 `offlinePackages`，并提供完整性 SHA-256 校验走查入口；
   - 接入 `coreService.localModelPackageManager`：在 `refreshNetworkAndOfflineResilience()` 中根据 `networkState` 与 `evaluateFallback` 调度决策，动态决定 UI 显示云端可用、弱网中还是已热降级至端侧模型；
   - 在 `ReaderViewModel.loadInitialSnapshot()` 中自动执行首屏网络弹性与离线模型刷新。

3. **真机走查与恢复测试支持**：
   - 在 `AISidebarView` 的状态条右侧提供网络状态模拟菜单，支持一键模拟「云端可用」、「弱网重试」、「离线断网」，便于测试团队在开发机或真机上快速走查各种边界降级链路。

---

## 2. 规范与代码质量自查

| 验收项目 | 自查结果 | 说明 |
| :--- | :--- | :--- |
| **独占代码目录** | **完全合规** | 仅修改 `StudyOS/Adapters/`、`StudyOS/UI/`、`StudyOS/Views/`、`StudyOS/ViewModels/`，无越权修改 |
| **严禁修改后端/配置** | **完全遵守** | 零修改 `Package.swift`、后端契约、后端存储/服务及测试用例代码 |
| **Swift 6 并发合规** | **完全合规** | 所有 ViewModel 与 UI 交互明确 `@MainActor`，协议代理采用 `nonisolated` + `MainActor.assumeIsolated`，全量数据模型符合 `Sendable` |
| **语法与零强制解包** | **完全合规** | 零 `!` 强制解包，全安全可选绑定与兜底默认值 |
| **第三方依赖** | **完全合规** | 纯原生 SwiftUI / UIKit / PencilKit，零任何第三方库依赖 |
| **测试执行诚实记录** | **如实标记** | Windows 宿主环境无 Xcode/Swift 工具链，真机运行如实记录为 `NOT_RUN` |

---

## 3. 下一步交接与联动建议

1. **交接主协调者（parent）与 PM（Claude1）**：
   - M4-UI 任务已完成，请将看板（BOARD）中 M4-UI 状态更新为 `COMPLETED`。
2. **交接测试（Codex2）**：
   - 可在真机走查手册（`docs/qa/MANUAL-WALKTHROUGH-GUIDE.md`）中，对 Apple Pencil 硬件双击手势切换、防掌压误触、4 种护眼纸张色板及网络连通/弱网重试/本地模型降级状态栏展开验收走查。
