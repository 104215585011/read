# M1-SETUP 阶段总结与收口交接文件

- 文件编号：`M1-CLOSE-pm-001`
- 时间：`2026-09-07T23:34:00+08:00`
- 发送角色：项目经理（Claude1）
- 接收角色：主协调者（parent）、项目后端（Codex1）、项目测试（Codex2）、外部 UI 总监（Claude2）
- 依据基线：
  - 原始产品需求：`docs/product/PRD-v0.1-source.md`
  - 项目规划与看板：`docs/project/PLAN.md`、`docs/project/BOARD.md`
  - 后端契约规范：`docs/backend/CONTRACT-v0.1-draft.md`（修订标识：`0.1-draft / M0-BE-REV2`）
  - UI 架构与适配器规范：`docs/ui/READER-ADAPTER-SPEC.md`（版本：`v0.3-aligned-be-rev2`）
  - 实现交接基线：`docs/handoffs/M1-SETUP-BE-backend-001.md`、`docs/handoffs/M1-SETUP-UI-ui-001.md`、`docs/handoffs/M1-SETUP-QA-qa-001.md`
  - QA 云端流水线验收：`docs/qa/M1-VERIFICATION-REPORT.md`、`docs/handoffs/M1-QA-VERIFY-qa-001.md`
- 独占维护与变更路径：
  - `docs/project/BOARD.md`
  - `docs/project/PLAN.md`
  - `docs/logs/pm.md`
  - `docs/handoffs/M1-CLOSE-pm-001.md`

---

## 1. M1-SETUP 阶段收口核心结论

### 1.1 GitHub Actions CI 真实云端流水线验收全量通过
根据用户反馈、QA 验收报告（`docs/qa/M1-VERIFICATION-REPORT.md`）及交接文件（`docs/handoffs/M1-QA-VERIFY-qa-001.md`）：
1. **真实云端执行环境**：GitHub Actions `macos-14` (Apple Silicon M1 Runner), Xcode 15.4 (Build 15F31d), Swift 5.10；
2. **目标平台与设备**：iPadOS Simulator (iOS 17.5 / `iPad Pro 11-inch (M4)`)；
3. **并发模式与安全编译**：启用 Swift 6 严格并发检查 (`-strict-concurrency=complete`)，严格通过 `@MainActor` UI 隔离与 Actor 状态机校验；
4. **编译与环境缺陷闭环**：
   - 跨平台可用性适配（`#if canImport(UIKit)` / `#if canImport(AppKit)` 与 iOS 17.0+ API）；
   - Strict Concurrency 与 Actor 隔离跨上下文调用全部合规；
   - KeyPath 属性映射与模型绑定完全修复；
   - iPad Simulator 模拟器目标精准匹配与挂载执行通过。
5. **自动化测试套件执行结果**：
   - 5 大测试类共 26 个测试方法 **100% 全部通过（26/26 PASS，0 失败，0 跳过）**；
   - 包含契约不变量（`ContractTests` 8 项）、领域模型与两路删除解绑（`ModelTests` 6 项）、存储 Actor 并发与乐观锁冲突（`StorageActorTests` 4 项）、跨会话隔离与安全导航（`ReaderAdapterFlowTests` 8 项）及基础冒烟测试。

### 1.2 看板状态更新与阶段收口
- 项目看板 `docs/project/BOARD.md` 中，`M1-SETUP 原生工程与阅读切片` 状态正式由 `WAITING_VERIFICATION (待执行 NOT_RUN)` 更新为 **`DONE`**；
- 阶段规划 `docs/project/PLAN.md` 中，`M1-SETUP` 阶段状态同步更新为 **`CLOSED (收口完成)`**；
- **M1-SETUP 原生工程脚手架、核心服务与 UI 切片阶段圆满收口**。

---

## 2. M1-SETUP 全量交付资产清单

### 2.1 后端工程脚手架与核心服务（Codex1）
- **工程结构与配置**：`Package.swift` (Swift 5.9+, iOS 17.0+ / macOS 14.0+)、`Config/Info.plist`、`Scripts/build.sh`；
- **契约协议定义**：`StudyOS/Contracts/` (`ReaderAdapterProtocol`、`CoreServiceProtocol` 等)；
- **领域数据模型**：`StudyOS/Models/DomainModels.swift` (14 组强类型领域模型，全量遵循 `Codable`、`Sendable`、`Hashable`)；
- **存储引擎与 Actor**：
  - `StudyOS/Storage/PageKeyIndexManager.swift`：基于 Swift Actor 的单调递增版本索引机；
  - `StudyOS/Storage/InkStorageEngine.swift`：原子持久化、`expectedRevision` 乐观锁冲突拒绝；
  - `StudyOS/Storage/MetadataStorageEngine.swift`：文档元数据管理与两路笔记删除策略解绑；
- **核心服务门面**：`StudyOS/Services/ReaderCoreService.swift`、`StudyOS/Services/CoreService.swift`。

### 2.2 原生 UI 切片与阅读器适配器（Claude2）
- **设计系统与入口**：`StudyOS/UI/Theme.swift`、`StudyOS/UI/StudyOSApp.swift`；
- **原生适配器层**：
  - `StudyOS/Adapters/ReaderAdapter.swift`：实现 `ReaderAdapterProtocol`，主执行域跨会话核对、`ignoredStaleSession` 静默隔离、入队前不可变快照固化；
  - `StudyOS/Adapters/PDFKitPlatformBridge.swift`：PDFView 宿主封装与坐标转换；
  - `StudyOS/Adapters/PencilKitOverlayCanvas.swift`：PencilKit 手写覆盖层与防抖流控；
- **视图模型与交互组件**：
  - `StudyOS/ViewModels/LibraryViewModel.swift`、`StudyOS/ViewModels/ReaderViewModel.swift`；
  - `StudyOS/Views/LibraryView.swift`：资料库展示与两路删除弹窗；
  - `StudyOS/Views/ReaderContainerView.swift`：阅读器主容器与分栏舒适门槛；
  - `StudyOS/Views/AISidebarView.swift`：助学侧栏面板与终态互斥处理；
  - `StudyOS/Views/SelectionCalloutMenu.swift`、`StudyOS/Views/SourceAnchorFocusRing.swift`。

### 2.3 自动化测试与契约验证套件（Codex2）
- **自动化测试套件**：
  - `StudyOSTests/ContractTests.swift` (8 用例)：PageKey 隔离、快照深拷贝、Receipt 递增、三态流转、结构化错误；
  - `StudyOSTests/ModelTests.swift` (6 用例)：模型编解码、0-based 页码不变量、NotePolicy 两路删除解绑断言；
  - `StudyOSTests/StorageActorTests.swift` (4 用例)：并发 TaskGroup 写入、快速笔画单调推进、乐观锁冲突捕获、物理文件清理；
  - `StudyOSTests/ReaderAdapterFlowTests.swift` (8 用例)：跨会话核对与静默丢弃、过期/已删除来源拦截、工具态切换、越界保护；
  - `StudyOSTests/StudyOSTests.swift` (基础冒烟用例)。

---

## 3. 验收矩阵达成与核心契约不变量总结

依据 CI 真实测试运行结果，以下关键架构不变量已获得自动化测试套件的严格背书：

| 契约 / 机制 | 验证套件 | 关键断言与保障行为 |
|---|---|---|
| **PageKey 跨维隔离** | `ContractTests` | 唯一哈希计算，跨文档、跨版本、跨页码严格隔离，`storageKey` 格式精准符合 `\(docID)_\(rev)_\(pIndex0)` |
| **InkSaveSnapshot 不可变性** | `ContractTests` | 入队前值语义深拷贝，后续落笔追加不污染已排队快照数据 |
| **两路笔记删除策略** | `ModelTests` | `keep` 策略下 `documentID`/`chapterID` 置空，锚点翻转为 `.documentDeleted`，完整保留用户文本与图片副本；`delete` 策略下级联物理删除 |
| **Actor 并发隔离与乐观锁** | `StorageActorTests` | `TaskGroup` 并发多页写盘无死锁；基线版本落后时抛出 `SaveInkError.conflict(currentRevision:)`，杜绝脏写覆盖 |
| **主执行域跨会话核对** | `ReaderAdapterFlowTests` | 文档 ID 或版本失配时静默返回 `.ignoredStaleSession`，保持当前状态不变，杜绝跨文档/旧会话迟到导航乱跳 |
| **过期/已删除来源拦截** | `ReaderAdapterFlowTests` | 旧版本来源拦截返回 `.staleReference`，已删除来源拦截返回 `.unavailable`，不可点击跳转 |

---

## 4. M2 阶段推进规划（核心阅读流、批注笔迹持久化与 AI 交互联调）

随着 M1-SETUP 基础工程闭环，项目正式进入 **M2 阶段规划（当前状态：READY）**。

### 4.1 核心攻坚目标
1. **真实 PDF 阅读流完整闭环（R01, R02, R16）**：
   - 真实大文件 PDF 异步加载与双向渲染；
   - 目录大纲提取与树形跳转；
   - 书签增删改查（CRUD）与快速定位；
   - 真实阅读位置与进度持久化，重启应用精准恢复。
2. **Apple Pencil 笔迹低延迟持久化（R03, R17）**：
   - PencilKit 画布与 PDFView 页面几何精确映射；
   - 2 秒停笔防抖策略触发不可变快照提交流程；
   - 硬件压感与倾斜角原生渲染；
   - 真实物理沙盒落盘与单调递增 Receipt 确认。
3. **文本选择生命周期与来源锚点定位（R04, R09）**：
   - PDFView 原生文本选区捕获与浮动菜单联动；
   - 来源锚点（`SourceAnchor`）发光动画聚焦层（`SourceAnchorFocusRing`）实机渲染。
4. **AI 助学与首个 Provider 服务对接（R05–R08, R14）**：
   - OpenAI / Anthropic 兼容 Provider 接口配置、凭据安全存储与流式通信；
   - 选中内容解释、当前页六段助学、章节助学与自由问答端到端联调；
   - 五级上下文与外发清单（`outboundItems`）动态聚合与用户确认；
   - 终态互斥拆分（`cancelled` vs `failed`）与 `alreadyTerminal` 防御。

### 4.2 角色分工与排他可写目录
- **Codex1（项目后端）**：
  - 排他可写目录：`StudyOS/Core/`、`StudyOS/Services/`、`StudyOS/Models/`、`StudyOS/Storage/`、`StudyOS/Contracts/`；
  - 重点任务：完善 Provider 流式客户端、PDF 目录/文本解析服务、SQLite 索引与业务事务。
- **Claude2（UI 总监）**：
  - 排他可写目录：`StudyOS/UI/`、`StudyOS/Views/`、`StudyOS/Adapters/`、`StudyOS/ViewModels/`；
  - 重点任务：完善 ReaderAdapter 与原生 PDFView/PencilKit 桥接、AI 侧栏流式打字机交互、浮动选区菜单。
- **Codex2（项目测试）**：
  - 排他可写目录：`docs/qa/**`、`StudyOSTests/`、`StudyOSUITests/`；
  - 重点任务：集成测试套件、UI 自动化测试、Mock Provider 模拟与异常用例覆盖。
- **Claude1（项目经理）**：
  - 排他可写目录：`docs/project/**`、`docs/logs/pm.md`、`docs/handoffs/`；
  - 重点任务：看板维护、契约审计、阶段验收收口。

---

## 5. 工作交接与权限释放

- **业务代码说明**：本阶段 PM 严禁修改且未修改任何业务源码（`StudyOS/**`）或工程配置文件；
- **权限释放**：本轮文档产出与看板更新完毕，释放本轮 `docs/project/**` 编辑锁；
- **汇报**：已更新 `docs/logs/pm.md`，正式向主协调者（parent）汇报 M1-SETUP 阶段收口成果。
