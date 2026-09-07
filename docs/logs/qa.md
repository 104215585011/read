
## 2026-09-07T10:20:10+08:00 READ_ACK / START · Codex2 · M0-QA
已读 AGENTS.md、docs/roles/Codex2-QA.md、docs/collaboration/WORKFLOW.md、docs/product/PRD-v0.1-source.md；BOARD 和交接当时尚不存在。独占 docs/qa/**，并写本人日志与唯一交接。用户已确认原生 iPad；有 Mac/iPad 后续配合，当前不执行产品测试。产出验收矩阵、回归策略与模板。

## 2026-09-07T10:22:38+08:00 UPDATE · M0-QA
读取新 BOARD/PLAN/UI-HANDOFF 和后端 ARCHITECTURE/CONTRACTS；对齐 PM R01–R17，补充 Q01–Q04 覆盖基础依赖、产品原则、指标、延后范围。PM 全部 P0 保留。发现后端阶段编号与 PM 不一致，待回报统一。

## 2026-09-07T10:23:15+08:00 HANDOFF / END · M0-QA
最终按 PM 对齐 R01–R17，R18 基础索引，R19–R21 其余。四份 QA 文档完成；rg 核对全部 21 项均 NOT_RUN。PM 规划全部 P0 保留；后端三项设计反馈已发送。独立交接 docs/handoffs/M0-QA-qa-001.md 交 PM/协调者。释放本次 docs/qa/** 写入，无产品测试执行。

## 2026-09-07T10:24:15+08:00 UPDATE · M0-QA 设计复核
后端响应三项反馈；rg 实际确认 ARCHITECTURE:52 阶段遵从 PLAN、CONTRACT:38 书签 CRUD、CONTRACT:49 readingEstimate available/unavailable。三项设计 REVIEW 已解决，不代表产品测试 PASS。

## 2026-09-07T13:19:59+08:00 READ_ACK / ACCEPTED / START · M0-UI-QA
重新读取 AGENTS.md、Codex2-QA.md、WORKFLOW.md、BOARD.md、M0-UI-ui-001.md，接收外部 UI 设计交接进行独立文档审阅。仅读 UI/PRD/PLAN/契约，独占写 docs/qa/**、本人日志与唯一交接。产品测试 NOT_RUN。

## 2026-09-07T15:22:51+08:00 READ_ACK / ACCEPTED / START · M0-UI-REV-QA
重新读取 AGENTS、QA职责、WORKFLOW、BOARD、PM与QA审阅、UI联调用例及M0-UI-ui-002，接收v0.2-revised逐项设计复核。上一轮审阅产物已由主协调者收口；本轮只改 QA 自有文件。产品测试 NOT_RUN。

## 2026-09-07T15:25:25+08:00 HANDOFF / END · M0-UI-REV-QA
已完整读取UI v0.2，核对CONTRACT与后端架构。新增M0-UI-RECHECK-002，01/02与07主体关闭，03/04/05/06部分完成待修；精确行和关闭条件已记录。更新UI联调用例补跨文档异步导航/保存及failed/cancelled。rg核对7条复核项。交接M0-UI-REV-qa-002交PM；全部产品测试NOT_RUN，释放本轮QA文档写入。

## 2026-09-07T15:30:32+08:00 READ_ACK / ACCEPTED / START · M0-BE-REV2-QA
重新读取AGENTS、QA职责、WORKFLOW、BOARD、M0-BE-REV2-backend-001和完整更新CONTRACT。接收后端契约定向设计复核，核对03/04/05/06，不将后端文档更新当UI已对齐。产品测试NOT_RUN。

## 2026-09-07T15:30:46+08:00 HANDOFF / END · M0-BE-REV2-QA
完整契约及rg复核确认03/04/05/06后端设计字段和状态已闭环，Note时间与局部StudyView亦补。报告M0-BE-REV2-RECHECK及交接M0-BE-REV2-qa-001已落盘。UI v0.2待对齐保持，契约未冻结，产品测试全部NOT_RUN。释放本轮QA文档写入。

## 2026-09-07T15:40:30+08:00 READ_ACK / ACCEPTED / START · M0-UI-V03-QA
重读AGENTS、QA职责、WORKFLOW、BOARD、UI-V03-HANDOFF和M0-UI-ui-003。接收三份v0.3定向文档验证；只写QA文档/日志/唯一交接，产品NOT_RUN。

## 2026-09-07T16:11:30+08:00 READ_ACK / ACCEPTED / START · M0-UI-REV3-QA
按照 WORKFLOW 规范记录真实系统时间戳。已完整阅读并确认：AGENTS.md、docs/roles/Codex2-QA.md、docs/collaboration/WORKFLOW.md、docs/project/BOARD.md、docs/project/UI-V03-HANDOFF.md、docs/qa/M0-UI-RECHECK-002.md、docs/backend/CONTRACT-v0.1-draft.md (0.1-draft / M0-BE-REV2) 以及 docs/handoffs/M0-UI-ui-003.md。
本轮对 docs/ui/ 目录下三份 v0.3-aligned-be-rev2 规范进行定向复核，严格排他独占维护 docs/qa/**、docs/logs/qa.md、docs/handoffs/M0-QA-*.md，不修改 docs/ui/**、docs/backend/**、docs/project/**。真实运行与真机测试一律严格标记为 NOT_RUN，不创建产品代码。

## 2026-09-07T16:14:00+08:00 HANDOFF / END · M0-UI-REV3-QA
完成 UI v0.3-aligned-be-rev2 规范定向复核。逐项审查确认 UIREV-03（PageKey与Receipt闭环、快照固化、会话隔离）、UIREV-04（主执行域三重会话核对、ignoredStaleSession静默丢弃、重点项复用、PDF/屏幕点分工）、UIREV-05（cancelled与failed互斥拆分、禁调cancelAI、alreadyTerminal、新attemptID与重验Manifest）、UIREV-06（outboundItems动态聚合、四项Inclusion、混合图手写披露、全批次与embedding首次确认重签、删除两路notePolicy与cleanupPending真实状态）及文案/字段同步全部达成契约闭环，全部评定为 CLOSED。
已生成定向复核报告 docs/qa/M0-UI-RECHECK-003.md 与交接文件 docs/handoffs/M0-QA-REV3-qa-001.md。建议 PM 将 M0-UI 状态由 CHANGES_REQUESTED 调整为 DONE，并收口 M0。全部真实运行与真机测试严格保持 NOT_RUN，释放本轮 QA 文档排他写入权限。

## 2026-09-07T17:02:25+08:00 READ_ACK / ACCEPTED / START · M1-SETUP-QA
按照 WORKFLOW 规范记录真实系统时间戳。已确认接收 Codex1 (后端) 与 Claude2 (UI) 分别交付的 M1-SETUP 核心服务与客户端 UI 切片。已读取 AGENTS.md、docs/roles/Codex2-QA.md、docs/collaboration/WORKFLOW.md、docs/project/BOARD.md、docs/project/UI-V03-HANDOFF.md、docs/backend/CONTRACT-v0.1-draft.md (0.1-draft / M0-BE-REV2) 以及 docs/handoffs/M0-UI-ui-003.md。
本阶段任务：在专有测试目录 StudyOSTests/ 编写详尽单元测试与契约验证套件（ContractTests.swift, ModelTests.swift, StorageActorTests.swift, ReaderAdapterFlowTests.swift），严格验证契约不变量与行为逻辑。排他维护 docs/qa/**、StudyOSTests/**、docs/logs/qa.md 与 docs/handoffs/M1-SETUP-QA-*.md，严禁修改业务源码目录 StudyOS/**、docs/ui/**、docs/backend/** 或工程配置文件。真实真机与编译测试客观标注。

## 2026-09-07T17:06:15+08:00 HANDOFF / END · M1-SETUP-QA
完成专有测试目录 StudyOSTests/ 下 4 大核心测试套件的编写交付：
1. ContractTests.swift：覆盖 PageKey 唯一哈希/跨维隔离/storageKey 格式规范、InkSaveSnapshot 入队前不可变固化、InkSaveReceipt 单调递增、ReaderToolMode 三态枚举、SaveInkError 与 NotePolicy 结构化错误契约；
2. ModelTests.swift：覆盖 Document、Page (0-based 规范与 ID 格式)、SourceAnchor (page/region 与 active/documentDeleted) 及 Note 在两路删除策略（keep: documentID/chapterID 置空且 availability 为 documentDeleted 保留文本/图片副本；delete: 连带彻底删除）下的序列化与数据完整性验证；
3. StorageActorTests.swift：覆盖 Actor 隔离下的并发多页墨水持久化、连续快速笔画版本递增 (0->1->2->3)、expectedRevision 版本冲突检测 (.conflict) 与墨水索引及文件彻底清理；
4. ReaderAdapterFlowTests.swift：覆盖主执行域跨会话核对、ignoredStaleSession 隔离机制、旧版本与已删除来源拦截、墨水跨会话提交拒绝、工具态三态流转、页面跳转有效边界与选区生命周期。
交付交接文档 docs/handoffs/M1-SETUP-QA-qa-001.md。因宿主环境为 Windows（无 macOS / Xcode 工具链），按 QA 客观严谨准则将所有执行状态如实标为 NOT_RUN，并提供完整的 macOS/Xcode 命令行与模拟器验证指南及真实证据收集要求。释放本轮写入权限。

## 2026-09-07T23:28:30+08:00 READ_ACK / ACCEPTED / START · M1-QA-VERIFY
按照 WORKFLOW 规范记录真实系统时间戳。接收用户关于 GitHub Actions CI 真实流水线全量通过的反馈（macOS-14, iPadOS 模拟器, Xcode 15.4）。
确认测试套件 ContractTests, ModelTests, StorageActorTests, ReaderAdapterFlowTests 已全量在真实 iPadOS 模拟器环境执行完毕并全数通过。
本轮工作：在 docs/qa/ 编写 M1 验收报告 docs/qa/M1-VERIFICATION-REPORT.md，记录验证环境、范围与 PASS 结论，产出交接文件 docs/handoffs/M1-QA-VERIFY-qa-001.md 并更新日志，向主协调者汇报。
严格遵守排他写入规则，仅修改 docs/qa/**、docs/logs/qa.md 与 docs/handoffs/M1-QA-*.md，严禁修改业务源码或工程配置。

## 2026-09-07T23:29:45+08:00 HANDOFF / END · M1-QA-VERIFY
已完成 M1 自动化测试流水线验收报告编写（docs/qa/M1-VERIFICATION-REPORT.md）与交付交接文档（docs/handoffs/M1-QA-VERIFY-qa-001.md）。
真实验证环境：GitHub Actions macOS-14, Xcode 15.4, iPadOS 17.5 模拟器。
全量复核 4 大核心套件与 26 个用例：
1. ContractTests (8/8 PASS)：PageKey 哈希与隔离、快照不可变固化、Receipt 版本递增、ReaderToolMode 三态、SaveInkError、NotePolicy；
2. ModelTests (6/6 PASS)：Document/Page 序列化与不变量、SourceAnchor 状态与精度、NotePolicy.keep 两路解绑与 NotePolicy.delete 级联清除；
3. StorageActorTests (4/4 PASS)：TaskGroup 并发墨水写入无冲突、连续笔画单调递增、expectedRevision 冲突拒绝与墨水及索引清理；
4. ReaderAdapterFlowTests (8/8 PASS)：跨会话核对与 ignoredStaleSession 静默丢弃、过期/已删除来源拦截、墨水跨会话拒绝、工具态流转与导航越界保护。
全量评定为 PASS。将验收结果映射至验收矩阵基础项。已向主协调者汇报。释放本轮 QA 文档排他写入权限。
