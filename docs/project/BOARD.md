# StudyOS 项目看板

更新：2026-09-07T17:07:30+08:00。M0 文档阶段已完成收口；M1-SETUP 源码、UI 适配器与自动化测试套件均已编写就绪，状态更新为等待用户 Mac 构建与设备验证（WAITING_VERIFICATION / 待执行 NOT_RUN）；平台为 iPad 原生。

| 任务 | 负责人 | 依赖 | 排他可写路径 | 验收条件 | 状态 |
|---|---|---|---|---|---|
| M0-PM 需求及协作编排 | 项目经理 Claude1 | 原始 PRD、平台选择 | docs/project/**、docs/logs/pm.md | P0 完整映射、阶段依赖、外部 UI 交接和风险记录 | DONE |
| M0-BE 架构/契约草案 | 项目后端 Codex1 | 原始 PRD、平台选择 | docs/backend/**、docs/logs/backend.md | 本地数据、五级上下文、来源锚点、Provider 与失败边界清楚 | DONE |
| M0-QA 验收准备 | 项目测试 Codex2 | 原始 PRD；契约草案供后续审阅 | docs/qa/**、docs/logs/qa.md | 全 P0 覆盖，后端回归/外部 UI 联调闭环，未执行如实记录 | DONE |
| M0-UI 原生 UI 方案 | 外部 UI 总监 Claude2 | 用户外部安排、UI-HANDOFF.md | docs/ui/**、docs/logs/ui.md | UIREV-01–07 修订完成，QA 复核，PM 关闭设计审阅 | DONE |
| M0-UI-REVIEW 方案审阅与联调补充 | PM Claude1 / QA Codex2；主协调者临时收口 | M0-UI-ui-001 | docs/project/**、docs/qa/**、对应个人日志 | PM 一致性报告与 QA 独立审阅/联调用例落盘，状态真实 | DONE |
| M0-BE-REV2 契约定向补充 | Codex1；QA复核；PM接收 | UI002复核 | docs/backend/**、backend日志；QA/PM各自范围 | 四组契约映射补齐并经QA设计复核 | DONE |
| M1-SETUP 原生工程与阅读切片 | Codex1(工程/服务) + Claude2(UI/适配) + Codex2(测试套件) | M0 全部文档收口，真实 Mac 构建环境就绪 | 工程配置独占写者 Codex1；UI/服务/测试目录严格隔离 | 源码/UI/测试套件均就绪，待 Mac 环境执行构建、单元测试与设备验证 | WAITING_VERIFICATION (待执行 NOT_RUN) |

每个角色可新增自身任务的唯一交接文件。个人文件更新时间见各自日志；只有 PM 更新本表。M1-SETUP 源码、UI 与测试套件已就绪，等待 Mac 构建与设备验证。

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

#### 步骤四：归档测试证据与关闭任务
1. 将 macOS 上的构建日志、`swift test` 输出或 `TestResults.xcresult` 归档至 `docs/qa/evidence/`；
2. Codex2 (QA) 审阅真实证据后，在 `docs/qa/ACCEPTANCE-MATRIX.md` 中将相应条目由 `NOT_RUN` 调整为 `PASS`；
3. Claude1 (PM) 复核通过后更新看板将 `M1-SETUP` 标记为 `DONE`，并开启 M2 规划。




