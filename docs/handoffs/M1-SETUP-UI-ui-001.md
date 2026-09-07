# M1-SETUP 原生 UI 切片与适配器交付交接文档

- 交接编号：`M1-SETUP-UI-ui-001`
- 真实时间：`2026-09-07T17:02:10+08:00`
- 发送角色：UI 总监与外部前端负责人（Claude2）
- 接收角色：项目经理（Claude1）、项目测试（Codex2）、项目后端（Codex1）、主协调者
- 遵循契约与规范：
  - 后端契约：`0.1-draft / M0-BE-REV2` (`StudyOS/Contracts/` & `StudyOS/Models/`)
  - UI 架构规范：`docs/ui/ARCHITECTURE-AND-FLOWS.md` (v0.3)
  - 组件与状态机：`docs/ui/COMPONENTS-AND-STATES.md` (v0.3)
  - 适配器规范：`docs/ui/READER-ADAPTER-SPEC.md` (v0.3)
- 关联看板任务：`M1-SETUP` (IN_PROGRESS)

---

## 1. 变更文件与专有目录清单

所有新建代码严格位于 Claude2 独占写入目录，零修改后端源码，零修改 `Package.swift`：

| 模块目录 | 文件路径 | 职责说明 |
|---|---|---|
| **StudyOS/UI/** | `StudyOS/UI/Theme.swift` | 统一设计系统令牌：学术蓝主色调、温润纸张底衬、间距、圆角与 540pt 布局约束 |
| **StudyOS/UI/** | `StudyOS/UI/StudyOSApp.swift` | App 启动主入口，装配 `CoreService.makeDefault()` 门面与根工作流 |
| **StudyOS/Adapters/** | `StudyOS/Adapters/ReaderAdapter.swift` | 严格实现 `ReaderAdapterProtocol`，处理 0-based 物理页码映射、跨会话核对、排队前不可变 `InkSaveSnapshot` 固化与 `persistedRevision` 回执推进 |
| **StudyOS/Adapters/** | `StudyOS/Adapters/PDFKitPlatformBridge.swift` | `UIViewRepresentable` 包装原生 `PDFView`，监听页码变动与选区变动，支持 macOS 降级 |
| **StudyOS/Adapters/** | `StudyOS/Adapters/PencilKitOverlayCanvas.swift` | 按 `PageKey` 独立挂载 `PKCanvasView`，2 秒防抖定时器，抬笔固化墨水快照与三态交互管理 |
| **StudyOS/ViewModels/** | `StudyOS/ViewModels/LibraryViewModel.swift` | 资料库响应式状态机，管理最近阅读、全部文档、PDF 导入与两路笔记删除影响评估 |
| **StudyOS/ViewModels/** | `StudyOS/ViewModels/ReaderViewModel.swift` | 阅读器主状态机，协调 ReaderAdapter、AI 侧栏、选区菜单、来源发光高亮与笔记书签 |
| **StudyOS/Views/** | `StudyOS/Views/LibraryView.swift` | 资料库主界面：最近阅读横向滚动卡片、全部资料列表、导入按钮、两路笔记删除弹窗 (强制 `NotePolicy` 二选一) |
| **StudyOS/Views/` | `StudyOS/Views/ReaderContainerView.swift` | 阅读器主工作区：沉浸式顶栏、70/30 自适应分栏 SplitView (≥540pt 保护)、底栏物理页码滑块 |
| **StudyOS/Views/** | `StudyOS/Views/SelectionCalloutMenu.swift` | 选区浮动菜单：高亮、下划线、复制、✨助学解释、存笔记 |
| **StudyOS/Views/** | `StudyOS/Views/AISidebarView.swift` | AI 助学侧栏：三级范围选择器、六段式核心卡片、自由问答对话流、来源依据胶囊 |
| **StudyOS/Views/** | `StudyOS/Views/SourceAnchorFocusRing.swift` | 来源回跳发光边框动画层，支持呼吸脉冲缩放及 Reduce Motion 静态半透明降级 |
| **StudyOS/Views/** | `StudyOS/Views/NoteCardView.swift` | 笔记卡片组件：支持富文本、AI 派生标签、关联来源以及原文档已删除标记 |
| **StudyOS/Views/** | `StudyOS/Views/FullDocumentStudyView.swift` | 全文学习大模态：宏观大纲、核心概念云、五星重难点篇章排行榜与分批任务覆盖率呈现 |

---

## 2. 核心架构与契约对齐要点

1. **零强制解包与 Strict Concurrency**：
   - 适配器与 ViewModel 全量标注 `@MainActor`，完全遵循 Swift 5.9+ 并发模型；
   - 核心生命周期中无任何强制解包 (`!`)，空值均有严谨的 `guard let` 或安全降级。
2. **坐标体系严格隔离 (UIREV-04)**：
   - `pdfView.go(to:rect, on:page)` 严格接收 PDF Page 空间坐标 (`CodableRect`)；
   - 浮动选区菜单与 `SourceAnchorFocusRing` 统一通过 `pdfView.convert(rect, from: page)` 获取屏幕视口坐标，并在图层上设置 `allowsHitTesting(false)` 杜绝阻断阅读手写触控。
3. **主执行域跨会话核对 (UIREV-01, UIREV-04, UI-T07)**：
   - `ReaderAdapter.navigateTo(source:)` 在 `await coreService.resolveSource(source)` 挂起返回后，严格在主执行域比对 `readerSessionID`、`currentDocumentID`、`currentDocumentRevision`；
   - 失配安全返回 `.ignoredStaleSession`，杜绝迟到乱跳。
4. **两路笔记删除策略弹窗闭环 (UIREV-06, UI-T11)**：
   - `LibraryView` 删除弹窗展示真实 `DeleteImpact` 影响项（文件、索引、批注、笔迹、笔记）；
   - 强制用户二选一选择 `NotePolicy` (`.keep` 保留解绑 vs `.delete` 连带删除)，未选择前禁用删除确认按钮；支持 `cleanupPending` 非阻塞进度展示。

---

## 3. 验证情况与命令记录

- **执行环境**：Windows 本地环境，无 Apple 原生 Xcode / Swift 工具链；
- **验证命令**：`git status`、代码人工排查与静态逻辑比对；
- **验证结果**：
  - 文件结构完整，接口签名与 Codex1 交付的 `ReaderAdapterProtocol` 及 `CoreServiceProtocol` 100% 吻合；
  - 原生编译与真机运行结果如实标记为：`NOT_RUN`。

---

## 4. 未测项与已知限制

1. **未测项**：
   - iPadOS 真机上 Apple Pencil 实笔低延迟测试（需等 Mac 构建机环境）；
   - PDFView 多页面滚动时内存瞬时开销；
2. **已知限制**：
   - 当前在非 iOS/macOS 宿主无法通过 `swift build` 编译，需由具备 macOS 环境的 QA (Codex2) 或主协调者在 Mac 环境下拉取构建。

---

## 5. 下一步建议

1. 提请测试负责人 Codex2 在 Mac 真实构建环境中执行 `StudyOS` 与 `StudyOSTests` 编译和单元测试验证；
2. 提请项目经理 Claude1 审阅本次客户端切片并跟进 M1-SETUP 状态更新；
3. 本轮释放所有排他编辑权。
