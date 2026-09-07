# M0 阶段总结与收口交接文件

- 文件编号：`M0-CLOSE-pm-001`
- 时间：`2026-09-07T16:15:30+08:00`
- 发送角色：项目经理（Claude1）
- 接收角色：主协调者（parent）、项目后端（Codex1）、项目测试（Codex2）、外部 UI 总监（Claude2）
- 依据基线：
  - 原始产品需求：`docs/product/PRD-v0.1-source.md`
  - 项目规划与看板：`docs/project/PLAN.md`、`docs/project/BOARD.md`
  - 后端架构与契约：`docs/backend/ARCHITECTURE-PROPOSAL.md`、`docs/backend/CONTRACT-v0.1-draft.md`（修订标识：`0.1-draft / M0-BE-REV2`）
  - UI 交互与适配规范：`docs/ui/ARCHITECTURE-AND-FLOWS.md`、`docs/ui/COMPONENTS-AND-STATES.md`、`docs/ui/READER-ADAPTER-SPEC.md`（版本：`v0.3-aligned-be-rev2`）
  - QA 验收与复核基线：`docs/qa/ACCEPTANCE-MATRIX.md` (R01–R21)、`docs/qa/UI-INTEGRATION-CASES.md` (UI-T01–UI-T11)、`docs/qa/M0-UI-RECHECK-003.md`、`docs/handoffs/M0-QA-REV3-qa-001.md`
- 变更路径：
  - `docs/project/BOARD.md`
  - `docs/project/PLAN.md`
  - `docs/logs/pm.md`
  - `docs/handoffs/M0-CLOSE-pm-001.md`

---

## 1. M0 阶段收口核心结论

### 1.1 UI 方案终审复核闭环
根据测试负责人 Codex2 的最新复核报告（`docs/qa/M0-UI-RECHECK-003.md`）及交接文件（`docs/handoffs/M0-QA-REV3-qa-001.md`）：
1. **UIREV-03（保存归属与快照）**：**CLOSED**。入参采用契约 `InkSaveSnapshot`，固化 `PageKey`、`readerSessionID`、`snapshotID` 与 `expectedRevision`；返回 `InkSaveReceipt`；仅合并未排队快照；保存期间新笔画保持 dirty 并推进版本；旧会话仅记账不改新画布；`dirty` 不伪称恢复数据；错误分型完整对齐。
2. **UIREV-04（会话核对与安全导航）**：**CLOSED**。主执行域三重核对（会话、文档版本、页码有效性）；失配返回 `ignoredStaleSession` 静默丢弃迟到导航；全文重点跳转统一复用同一入口；严格区分 PDF points 传原生 API 与屏幕 points 传覆盖层。
3. **UIREV-05（终态互斥拆分与重试）**：**CLOSED**。独立拆分 `cancelled` 与 `failed` 互斥终态；`failed` 保留错误与未完文本，严禁调 `cancelAI`；服务端串行裁决终态，`alreadyTerminal` 不覆写；重试/继续生成统一派发新 `attemptID` 并重验 Manifest，明确标明非流续传；未校验来源置灰禁用。
4. **UIREV-06（外发清单与两路删除）**：**CLOSED**。隐私面板直接基于 `outboundItems` 反显，区分提取文本与原始 PDF，混合图依 `containsHandwriting` 如实披露；四项 Inclusion 清晰列出；首次外发确认覆盖远端 embedding 与全部分批，变更重签；删除弹窗强制二选一 `notePolicy(keep/delete)`，真实展示 `cleanupPending`；保留笔记解绑归属并标记 `documentDeleted` 不可跳。
5. **文案与关联字段同步**：**CLOSED**。Notes 补充时间与可空归属；局部学习视图显式传 `scope(.pageRange)`；彻底清除“100%正常”虚词；30s 超时标候选；长文档不设 25 页硬上限；540pt 明确为分栏舒适门槛；主标题呈现阅读范围。

### 1.2 M0 阶段看板关闭
- `M0-UI 原生 UI 方案` 状态正式由 `CHANGES_REQUESTED` 调整为 **`DONE`**；
- 至此，M0 阶段的全部 4 个主任务（M0-PM、M0-BE、M0-QA、M0-UI）及 2 个评审补充任务（M0-UI-REVIEW、M0-BE-REV2）全部达成 **`DONE`**；
- **M0 阶段文档设计工作正式宣告完整收口**。前后端契约高度自洽，消除了所有已知跨模块歧义与设计冲突。

---

## 2. M1-SETUP 规划与实施基线

为了保障后续代码实施阶段的有序推进，防止代码仓库混乱与 Git 冲突，PM 对 M1-SETUP 阶段进行了全面规划：

### 2.1 任务基本信息
- **任务编号**：`M1-SETUP`
- **任务名称**：原生工程脚手架、配置基线与阅读切片
- **当前状态**：**`READY`**（规划完成，待真实 Mac 环境与代码实施授权）
- **负责人**：
  - 工程全局配置与核心服务骨架：Codex1（项目后端）
  - 原生 UI 视图与适配器框架：Claude2（外部 UI 总监）
  - 验收与测试用例套件准备：Codex2（项目测试）
  - 统筹协调与进度管理：Claude1（项目经理）

### 2.2 技术栈基线
- **目标运行平台**：iPadOS 17.0+ 原生应用（支持分屏、Stage Manager 多窗口与多尺寸适配）；
- **前端与交互技术栈**：SwiftUI + PDFKit（PDF 文档流与精确选区） + PencilKit（低延迟 Apple Pencil 手写、橡皮擦与墨水序列化）；
- **核心服务与并发架构**：Swift 5.9+，完全基于 Swift Concurrency（`async/await`、`actor` 状态隔离、`@MainActor` UI 绑定）；
- **数据持久化技术栈**：SQLite / 本地沙盒文件系统存储，严格遵从本地优先（Local-First）与用户隐私保护。

### 2.3 单一工程配置写者（Single Config Writer）
- **唯一指定写者**：**Codex1（项目后端）**；
- **独占写入范围**：`StudyOS.xcodeproj`、`Package.swift`、`Info.plist`、Entitlements 文件、构建脚本及外部依赖配置；
- **排他规约**：其他角色（PM、UI、QA）严禁私自修改工程配置文件，所有依赖变更或配置调整必须向 Codex1 提出并串行执行，杜绝 Xcode 工程文件冲突。

### 2.4 源码目录排他分工基线
进入实施阶段后，严格执行文件所有权分工：
1. **核心服务 / 后端模块**（Codex1 独占）：
   - `StudyOS/Core/`（核心领域模型、错误定义、调度管线）；
   - `StudyOS/Services/`（文档解析服务、笔记服务、AI 调度服务框架）；
   - `StudyOS/Storage/`（SQLite 数据存储、墨水持久化引擎、沙盒管理）；
   - `StudyOS/Contracts/`（契约强类型定义，修改需经 PM/QA 审阅）。
2. **客户端 UI / 前端模块**（Claude2 独占）：
   - `StudyOS/UI/`（SwiftUI 视图组件、导航容器、工具栏、浮动面板）；
   - `StudyOS/Adapters/`（`PDFKitRepresentable`、`PencilKitRepresentable`、`ReaderAdapter` 实现）；
   - `StudyOS/ViewModels/`（UI 状态机、交互事件响应）。
3. **测试模块**（Codex2 独占）：
   - `StudyOSTests/`（契约单元测试、领域服务回归测试）；
   - `StudyOSUITests/`（集成验收测试套件，对应 R01–R21 与 UI-T01–UI-T11）。

### 2.5 M1-SETUP 验收标准
1. 工程在用户 Mac 环境下可使用 Xcode 15+ 或 `swift build` 顺利编译，0 错误、0 阻塞警告；
2. 完成最小 PDF 加载显示与 PencilKit 墨水画布绑定的垂直切片；
3. 契约协议骨架完整落地，无悬垂接口；
4. 真实测试状态严格依据运行结果记录。

---

## 3. 真实状态与环境声明 (Strict NOT_RUN)

- **产品代码零产出**：本轮工作严格限定于架构规划、规范复核与阶段收口，**未生成或修改任何产品代码（Swift/Xcode/Shell）**；
- **环境真实性**：当前宿主为 Windows 环境，未执行任何 Xcode 编译、模拟器部署、iPad 真机手写实测与云端 AI Provider 请求；
- **验收用例状态**：`ACCEPTANCE-MATRIX.md` (R01–R21) 与 `UI-INTEGRATION-CASES.md` (UI-T01–UI-T11) 中所有用例状态如实保持为 **`NOT_RUN`**，无虚报或假冒测试。

---

## 4. 下一步行动建议

1. **向主协调者汇报**：本阶段 M0 收口与 M1-SETUP 规划已齐备，看板与阶段规划已更新；
2. **环境准备**：待用户与主协调者在具备 macOS / Xcode 编译环境后，授权进入 M1-SETUP 代码实施阶段；
3. **释放排他权限**：本轮工作完成，释放 `docs/project/**` 排他写入权限（后续仍由 PM 独占）。
