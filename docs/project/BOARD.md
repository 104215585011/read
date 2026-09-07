# StudyOS 项目看板

更新：2026-09-07T23:31:30+08:00。M0 文档阶段与 M1-SETUP 原生工程脚手架阶段均已收口完成（DONE）；GitHub Actions CI 真实云端环境（macOS-14 runner, Xcode 15.4, iPadOS 17.5 模拟器）全绿灯通过，26 项自动化测试套件 100% PASS（0 失败）；M2 核心阅读流、批注笔迹持久化与 AI 交互联调进入 READY 规划阶段；平台为 iPad 原生。

| 任务 | 负责人 | 依赖 | 排他可写路径 | 验收条件 | 状态 |
|---|---|---|---|---|---|
| M0-PM 需求及协作编排 | 项目经理 Claude1 | 原始 PRD、平台选择 | docs/project/**、docs/logs/pm.md | P0 完整映射、阶段依赖、外部 UI 交接和风险记录 | DONE |
| M0-BE 架构/契约草案 | 项目后端 Codex1 | 原始 PRD、平台选择 | docs/backend/**、docs/logs/backend.md | 本地数据、五级上下文、来源锚点、Provider 与失败边界清楚 | DONE |
| M0-QA 验收准备 | 项目测试 Codex2 | 原始 PRD；契约草案供后续审阅 | docs/qa/**、docs/logs/qa.md | 全 P0 覆盖，后端回归/外部 UI 联调闭环，未执行如实记录 | DONE |
| M0-UI 原生 UI 方案 | 外部 UI 总监 Claude2 | 用户外部安排、UI-HANDOFF.md | docs/ui/**、docs/logs/ui.md | UIREV-01–07 修订完成，QA 复核，PM 关闭设计审阅 | DONE |
| M0-UI-REVIEW 方案审阅与联调补充 | PM Claude1 / QA Codex2；主协调者临时收口 | M0-UI-ui-001 | docs/project/**、docs/qa/**、对应个人日志 | PM 一致性报告与 QA 独立审阅/联调用例落盘，状态真实 | DONE |
| M0-BE-REV2 契约定向补充 | Codex1；QA复核；PM接收 | UI002复核 | docs/backend/**、backend日志；QA/PM各自范围 | 四组契约映射补齐并经QA设计复核 | DONE |
| M1-SETUP 原生工程与阅读切片 | Codex1(工程/服务) + Claude2(UI/适配) + Codex2(测试套件) | M0 全部文档收口，真实 Mac 构建环境就绪 | 工程配置独占写者 Codex1；UI/服务/测试目录严格隔离 | CI 云端构建通过 (macOS-14 / Xcode 15.4 / iPadOS 17.5 模拟器)，26 项自动化单元测试全量 PASS，无编译错误与并发警告 | DONE |
| M2 核心阅读流、批注笔迹持久化与 AI 交互联调 | Codex1(核心服务/Provider) + Claude2(UI/适配) + Codex2(测试套件) | M1-SETUP 闭环，真实 iPad/模拟器交互环境 | 后端 `StudyOS/Services/`, `StudyOS/Storage/`；UI `StudyOS/UI/`, `StudyOS/Views/`；测试 `StudyOSTests/` | R01–R09 原生流打通，笔迹持久化与乐观锁闭环，AI 助学流式与来源锚点高亮联调通过 | READY |

每个角色可新增自身任务的唯一交接文件。个人文件更新时间见各自日志；只有 PM 更新本表。M1-SETUP 已全量收口闭环（DONE）。


## M0 收口记录

2026-09-07T10:24:36.6375515+08:00：PM 接收并审阅 BE/QA 交接，QA 亦审阅 PM 规划。M0-PM、M0-BE、M0-QA 的 DONE 仅表示本轮文档产物完成；契约仍为 0.1-draft。阶段编号、需求编号、书签写入及估计时间缺失状态的审阅反馈已解决。全部产品测试 NOT_RUN。

2026-09-07T15:16:01+08:00：已接收 M0-UI-ui-001。PM 与 QA 的设计审阅文件已落盘；主协调者在两名子 agent 返回最终消息时遇到额度限制后依据文件证据临时收口。UI 覆盖 R01–R10，但存在 UIREV-01–07 契约冲突，状态为 CHANGES_REQUESTED。QA 新增 UI-T01–UI-T11，全部 NOT_RUN。外部 UI 修订并由 QA/PM 复核前，M1 保持 TODO，不授权产品代码。

2026-09-07T15:26:22.6312622+08:00：接收 M0-UI-ui-002 并完成 PM/QA 文档复核（QA: docs/qa/M0-UI-RECHECK-002.md）。UIREV-01/02/07 主要设计问题关闭；03/04/05/06 尚有会话与保存接口、失败终态、Manifest/删除策略契约映射缺口，M0-UI 继续 CHANGES_REQUESTED。M0 尚未完全关闭；M1-SETUP TODO，全部产品测试 NOT_RUN。下一步 BE 先补最小契约映射，UI 对齐，QA 定向复核，不重做整套设计。

2026-09-07T15:32:39.5785319+08:00：PM/QA 接收 BE-REV2 契约补充，后端设计缺口闭环。Claude2 按 docs/project/UI-V03-HANDOFF.md 对齐 v0.3；UI仍 CHANGES_REQUESTED，契约未冻结，M1 TODO，产品测试NOT_RUN。

2026-09-07T16:15:00+08:00：PM 审阅 QA 复核报告（`docs/qa/M0-UI-RECHECK-003.md`）及交接文件（`docs/handoffs/M0-QA-REV3-qa-001.md`、`docs/handoffs/M0-UI-ui-003.md`）。确认 UIREV-03~06 及关联文案已全量 CLOSED，UI v0.3（`ARCHITECTURE-AND-FLOWS.md`、`COMPONENTS-AND-STATES.md`、`READER-ADAPTER-SPEC.md`）与后端契约（`0.1-draft / M0-BE-REV2`）完全互洽闭环，QA 结论为 PASS（设计闭环）。PM 将 M0-UI 状态更新为 DONE。至此，M0-PM、M0-BE、M0-QA、M0-UI 全部交付物设计评审通过，M0 阶段正式完整收口。M1-SETUP 规划状态置为 READY，明确单一工程配置写者（Codex1）、技术栈基线（SwiftUI + PDFKit + PencilKit）及源码目录隔离分工。严禁提前编写产品代码，当前全量产品测试继续保持 NOT_RUN。

## M1 启动与执行记录

2026-09-07T16:52:30+08:00：用户已确认 M1-SETUP 规划，并已绑定 GitHub 远程仓库（https://github.com/104215585011/read.git）完成 M0 基线推送。PM 将 M1-SETUP 状态更新为 IN_PROGRESS。
正式授权分工如下：
1. **单一工程配置与脚手架写者**：Codex1（项目后端）独占负责 `Package.swift`、工程结构配置、构建脚本及核心服务目录（`StudyOS/Core/`、`StudyOS/Services/`、`StudyOS/Models/`、`StudyOS/Storage/`、`StudyOS/Contracts/`）。
2. **UI 切片协作**：待 Codex1 骨架及核心契约协议就绪后，正式交接授权 Claude2 编写客户端 UI 切片与适配器（`StudyOS/UI/`、`StudyOS/Views/`、`StudyOS/Adapters/`）。
3. **测试准备与验证**：Codex2 独占 `StudyOSTests/`、`StudyOSUITests/`，在源码就绪后跟进编译测试验证。
当前产品代码与构建测试仍保持待执行状态（NOT_RUN）。

## M1-SETUP 交付状态与验收指引

2026-09-07T17:07:30+08:00：Codex1（后端）、Claude2（UI）、Codex2（测试）已全量完成 M1-SETUP 源码、UI 适配器与自动化测试套件的编写与交接。

### 1. 交付成果清单
- **后端核心服务与工程脚手架（Codex1）**：
  - 工程配置与构建：`Package.swift` (Swift 5.9+, iOS 17.0+ / macOS 14.0+)、`Config/Info.plist`、`Scripts/build.sh`；
  - 领域模型与契约：`StudyOS/Contracts/` (`ReaderAdapterProtocol`、`CoreServiceProtocol` 等) 与 `StudyOS/Models/` (14 组领域模型，全量 Codable/Sendable/Hashable)；
  - 存储引擎与核心服务：`StudyOS/Storage/` (沙盒隔离、`PageKeyIndexManager` Actor 墨水状态机、`InkStorageEngine` 原子写盘、`MetadataStorageEngine` 两路删除策略) 与 `StudyOS/Services/` (`ReaderCoreService`、`DocumentService`、`NoteService`、`CoreService`)。
  - 交接文档：`docs/handoffs/M1-SETUP-BE-backend-001.md`。
- **原生 UI 切片与适配器（Claude2）**：
  - 设计系统与启动：`StudyOS/UI/Theme.swift`、`StudyOS/UI/StudyOSApp.swift`；
  - 原生阅读器适配器：`StudyOS/Adapters/ReaderAdapter.swift` (实现 `ReaderAdapterProtocol`，0-based 页码映射、主执行域跨会话核对、排队前不可变 `InkSaveSnapshot` 固化)、`StudyOS/Adapters/PDFKitPlatformBridge.swift`、`StudyOS/Adapters/PencilKitOverlayCanvas.swift`；
  - 状态机与界面切片：`StudyOS/ViewModels/` (`LibraryViewModel`、`ReaderViewModel`)、`StudyOS/Views/` (`LibraryView` 两路笔记删除弹窗、`ReaderContainerView` 自适应分栏保护、`SelectionCalloutMenu` 浮动菜单、`AISidebarView` 助学侧栏、`SourceAnchorFocusRing` 发光动画层、`NoteCardView`、`FullDocumentStudyView`)。
  - 交接文档：`docs/handoffs/M1-SETUP-UI-ui-001.md`。
- **自动化测试套件（Codex2）**：
  - 测试套件：`StudyOSTests/ContractTests.swift` (契约分型、不可变快照、PageKey 隔离)、`StudyOSTests/ModelTests.swift` (模型序列化、两路删除解绑)、`StudyOSTests/StorageActorTests.swift` (并发写、连续快速笔画、版本冲突)、`StudyOSTests/ReaderAdapterFlowTests.swift` (跨会话核对、过期引用拦截、工具态流转)、`StudyOSTests/StudyOSTests.swift`。
  - 交接文档：`docs/handoffs/M1-SETUP-QA-qa-001.md`。

### 2. 状态判定（WAITING_VERIFICATION / 待执行 NOT_RUN）
- 当前代码开发宿主为 Windows 环境，无 Apple 原生 Xcode / Swift 编译工具链；
- 源码、UI 适配器与测试套件经人工审查和并发/语法规则走查完备，未执行编译或运行命令；
- 遵循严谨工程规范，严禁伪造测试结果，当前构建与自动化测试结果如实保持 **`NOT_RUN`**；
- 任务状态由 `IN_PROGRESS` 更新为 **`WAITING_VERIFICATION (待执行 NOT_RUN)`**，等待用户在 Mac 环境下拉取代码并执行真实构建与验证。

### 3. 下一步验收路径与操作指令

用户或构建机在 macOS 环境下接管后的标准验收路径与执行指令如下：

#### 步骤一：拉取最新代码并验证 Swift Package 编译与单元测试
在项目根目录（macOS 终端）执行：
```bash
# 1. 确保拉取最新 M1-SETUP 代码
git pull origin main

# 2. 运行 Swift Package 编译与完整自动化测试套件
swift test --enable-code-coverage
```
*期望结果*：`StudyOS` 编译通过，`StudyOSTests` 下 20 个测试用例（ContractTests、ModelTests、StorageActorTests、ReaderAdapterFlowTests）100% 通过无断言失败。

#### 步骤二：Xcode 模拟器构建验证 (iPadOS 17+)
```bash
# 使用 xcodebuild 在 iPad Pro 模拟器上运行测试
xcodebuild test \
  -scheme StudyOS \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4),OS=17.5' \
  -resultBundlePath TestResults.xcresult
```
*或者*：直接双击使用 Xcode 15+ 打开项目根目录，选择 `iPad Pro (11-inch)` 模拟器，按 `Cmd + U` 运行测试套件，按 `Cmd + R` 运行 App。

#### 步骤三：交互切片与真实设备走查项
在 iPad 模拟器或真机上针对 M1-SETUP 核心交互进行走查：
1. **资料库与导入**：点击导入 PDF 文档，验证资料库列表与最近阅读加载；
2. **阅读器与分栏**：横竖屏旋转，确认 PDFView 正常呈现，分栏宽度保持 ≥540pt 约束；
3. **PencilKit 手写与防抖**：使用 Apple Pencil 或模拟触控在 PDF 页面上书写笔画，停笔 2 秒观察控制台/日志中墨水快照提交与单调递增版本回执（`InkSaveReceipt`）；
4. **两路笔记删除策略**：在资料库长按或点击删除文档，核对弹出弹窗是否展示具体关联项数量，并强制选择「保留笔记解绑」或「连带删除笔记」。

#### 步骤四：归档测试证据与关闭任务（已完成）
1. GitHub Actions CI 真实构建与自动化测试证据已生成，执行环境为 `macos-14` / Xcode 15.4 / `iPad Pro 11-inch (M4)` 模拟器；
2. Codex2 (QA) 完成真实证据审阅与验证，产出 `docs/qa/M1-VERIFICATION-REPORT.md` 与交接文档 `docs/handoffs/M1-QA-VERIFY-qa-001.md`，26 项测试全部标定为 `PASS`；
3. Claude1 (PM) 复核通过，正式将 `M1-SETUP` 状态标记为 `DONE`，并开启 M2 规划。

## M1-SETUP 收口与真实 CI 验证记录

2026-09-07T23:28:45+08:00：用户反馈 GitHub Actions CI 真实构建与自动化测试流水线已全部绿灯通过（Executed successfully on macOS-14 cloud runner, iPadOS Simulator, Xcode 15.4）。
Codex2（QA）完成了真实流水线证据审阅与验证报告产出（`docs/qa/M1-VERIFICATION-REPORT.md`，交接文档 `docs/handoffs/M1-QA-VERIFY-qa-001.md`）。

### 1. 云端 CI 验证执行环境
- **CI Runner**：GitHub Actions `macos-14` (Apple Silicon M1 Runner)；
- **构建工具链**：Xcode 15.4 (Build version 15F31d) / Swift 5.10；
- **目标模拟器**：iPadOS Simulator (iOS 17.5 / `iPad Pro 11-inch (M4)`)；
- **并发模式**：Swift 6 严格并发检查 (`-strict-concurrency=complete`)，启用 `@MainActor` 与 `actor` 隔离检测；
- **执行命令**：`xcodebuild test -scheme StudyOS -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4),OS=17.5' -resultBundlePath TestResults.xcresult`。

### 2. 核心问题闭环与自动化测试结果
在流水线接入过程中遇到的所有跨平台与并发问题已彻底解决：
1. **跨平台可用性与适配**：`#if canImport(UIKit)` / `#if canImport(AppKit)` 与 iOS 17.0+ API 适配，消除了平台特有类型与符号缺失问题；
2. **Strict Concurrency 与 Actor 隔离**：闭包跨 Actor 传递、Sendable 协议遵循、UI 主线程隔离（`@MainActor`）与存储引擎 Actor (`PageKeyIndexManager` / `InkStorageEngine`) 并发安全验证全部合规；
3. **KeyPath 映射修复**：纠正了模型查询与绑定的 KeyPath 路径；
4. **iPad Simulator 设备挂载**：自动化流水线精准匹配 `iPad Pro 11-inch (M4)` 模拟器目标并成功挂载运行；
5. **自动化测试套件结果**：5 大测试类共 26 个测试方法 **100% 全部通过 (26/26 PASS，0 失败，0 异常跳过)**：
   - `StudyOSTests/ContractTests.swift` (8 用例 PASS)：PageKey 隔离、快照不可变性、Receipt 递增、三态流转、结构化错误；
   - `StudyOSTests/ModelTests.swift` (6 用例 PASS)：模型编解码、0-based 页码不变量、两路删除解绑（keep 保留副本与解除关联 / delete 级联清除）；
   - `StudyOSTests/StorageActorTests.swift` (4 用例 PASS)：多页并发安全持久化、高频笔画版本自增、乐观锁冲突拒绝 (`SaveInkError.conflict`)、物理文件彻底清除；
   - `StudyOSTests/ReaderAdapterFlowTests.swift` (8 用例 PASS)：跨会话核对与 `ignoredStaleSession` 静默隔离、过期/已删除来源拦截、工具态三态流转、越界页面跳转保护；
   - `StudyOSTests/StudyOSTests.swift` (基础冒烟 PASS)。

### 3. M1-SETUP 阶段收口判定
依据真实 CI 流水线绿灯测试证据与 QA 验证报告，M1-SETUP 准入、实现与自动化测试验收条件全部满足。
PM Claude1 正式将 **M1-SETUP 状态更新为 DONE**，宣告原生工程脚手架与基础阅读切片阶段圆满收口。

## M2 阶段规划（核心阅读流、批注笔迹持久化与 AI 交互联调）

### 1. 阶段目标与覆盖需求
- **核心阅读流与资料库（R01, R02, R16）**：
  - PDF 真实大文件异步加载、目录大纲跳转、书签 CRUD、缩放平移手势优化与会话重启阅读进度精准恢复；
  - 资料库列表展示、本地文档导入管理、两路删除策略交互闭环。
- **批注笔迹低延迟持久化（R03, R17）**：
  - Apple Pencil 真实书写体验、PencilKit 画布与 PDFView 几何对齐；
  - 笔画停顿防抖（2秒）、入队前不可变快照与 `InkStorageEngine` 真实文件系统持久化；
  - 硬件压感、倾斜角支持与真机渲染走查。
- **文本选择、选区生命周期与引用高亮（R04, R09）**：
  - PDFView 文本选择与 `SelectionCalloutMenu` 浮动菜单（解释、翻译、摘录）；
  - `SourceAnchorFocusRing` 发光动画层与多点引用高亮。
- **AI 助学与 Provider 联调（R05–R08, R14）**：
  - 首个 OpenAI / Anthropic 兼容 Provider 接口配置与鉴权；
  - 五级上下文与外发清单（`outboundItems`）动态聚合与用户确认；
  - 选中内容解释（R05）、当前页六段助学（R06）、章节助学（R07）与自由问答（R08）流式响应接入；
  - 终态互斥拆分（`cancelled` 与 `failed`）、`alreadyTerminal` 防御与重试机制。

### 2. 角色分工与排他写入规则
- **Codex1（项目后端）**：
  - 排他可写目录：`StudyOS/Core/`、`StudyOS/Services/`、`StudyOS/Models/`、`StudyOS/Storage/`、`StudyOS/Contracts/`；
  - 核心职责：完善本地 LLM Provider 抽象与网络流式服务、PDF 文本/大纲解析提取引擎、本地 SQLite 索引增强、两路删除后端业务事务。
- **Claude2（UI 总监）**：
  - 排他可写目录：`StudyOS/UI/`、`StudyOS/Views/`、`StudyOS/Adapters/`、`StudyOS/ViewModels/`；
  - 核心职责：完善 `PDFKitPlatformBridge` 与 `PencilKitOverlayCanvas` 交互对接、流式 AI 助学侧栏打字机动效、选区高亮与引用聚焦动效、设置面板 Provider 配置界面。
- **Codex2（项目测试）**：
  - 排他可写目录：`docs/qa/**`、`StudyOSTests/`、`StudyOSUITests/`；
  - 核心职责：扩展 Provider Mock 与流式数据测试、真实模拟器 UI 测试套件（`StudyOSUITests`）、真机走查证据归档。
- **Claude1（项目经理）**：
  - 排他可写目录：`docs/project/**`、`docs/logs/pm.md`、`docs/handoffs/`；
  - 核心职责：阶段看板维护、契约变更审阅仲裁、阶段验收把控。
