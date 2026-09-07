# StudyOS 项目看板

更新：2026-09-07T16:15:00+08:00。M0 文档阶段正式完成收口，M1-SETUP 规划 READY；平台为 iPad 原生；全量交付物无代码、无真实回归结果（NOT_RUN）。

| 任务 | 负责人 | 依赖 | 排他可写路径 | 验收条件 | 状态 |
|---|---|---|---|---|---|
| M0-PM 需求及协作编排 | 项目经理 Claude1 | 原始 PRD、平台选择 | docs/project/**、docs/logs/pm.md | P0 完整映射、阶段依赖、外部 UI 交接和风险记录 | DONE |
| M0-BE 架构/契约草案 | 项目后端 Codex1 | 原始 PRD、平台选择 | docs/backend/**、docs/logs/backend.md | 本地数据、五级上下文、来源锚点、Provider 与失败边界清楚 | DONE |
| M0-QA 验收准备 | 项目测试 Codex2 | 原始 PRD；契约草案供后续审阅 | docs/qa/**、docs/logs/qa.md | 全 P0 覆盖，后端回归/外部 UI 联调闭环，未执行如实记录 | DONE |
| M0-UI 原生 UI 方案 | 外部 UI 总监 Claude2 | 用户外部安排、UI-HANDOFF.md | docs/ui/**、docs/logs/ui.md | UIREV-01–07 修订完成，QA 复核，PM 关闭设计审阅 | DONE |
| M0-UI-REVIEW 方案审阅与联调补充 | PM Claude1 / QA Codex2；主协调者临时收口 | M0-UI-ui-001 | docs/project/**、docs/qa/**、对应个人日志 | PM 一致性报告与 QA 独立审阅/联调用例落盘，状态真实 | DONE |
| M0-BE-REV2 契约定向补充 | Codex1；QA复核；PM接收 | UI002复核 | docs/backend/**、backend日志；QA/PM各自范围 | 四组契约映射补齐并经QA设计复核 | DONE |
| M1-SETUP 原生工程与阅读切片 | Codex1(工程/服务) + Claude2(UI/适配)；QA验收 | M0 全部文档收口，真实 Mac 构建环境就绪 | 工程配置独占写者 Codex1；UI/服务目录严格隔离 | 可在用户 Mac 构建的 PDF 导入/阅读/手写最小切片，编译通过 | READY |

每个角色可新增自身任务的唯一交接文件。个人文件更新时间见各自日志；只有 PM 更新本表。M1-SETUP 规划已就绪，待真实 Mac 环境就绪与实施授权后开工。

## M0 收口记录

2026-09-07T10:24:36.6375515+08:00：PM 接收并审阅 BE/QA 交接，QA 亦审阅 PM 规划。M0-PM、M0-BE、M0-QA 的 DONE 仅表示本轮文档产物完成；契约仍为 0.1-draft。阶段编号、需求编号、书签写入及估计时间缺失状态的审阅反馈已解决。全部产品测试 NOT_RUN。

2026-09-07T15:16:01+08:00：已接收 M0-UI-ui-001。PM 与 QA 的设计审阅文件已落盘；主协调者在两名子 agent 返回最终消息时遇到额度限制后依据文件证据临时收口。UI 覆盖 R01–R10，但存在 UIREV-01–07 契约冲突，状态为 CHANGES_REQUESTED。QA 新增 UI-T01–UI-T11，全部 NOT_RUN。外部 UI 修订并由 QA/PM 复核前，M1 保持 TODO，不授权产品代码。

2026-09-07T15:26:22.6312622+08:00：接收 M0-UI-ui-002 并完成 PM/QA 文档复核（QA: docs/qa/M0-UI-RECHECK-002.md）。UIREV-01/02/07 主要设计问题关闭；03/04/05/06 尚有会话与保存接口、失败终态、Manifest/删除策略契约映射缺口，M0-UI 继续 CHANGES_REQUESTED。M0 尚未完全关闭；M1-SETUP TODO，全部产品测试 NOT_RUN。下一步 BE 先补最小契约映射，UI 对齐，QA 定向复核，不重做整套设计。

2026-09-07T15:32:39.5785319+08:00：PM/QA 接收 BE-REV2 契约补充，后端设计缺口闭环。Claude2 按 docs/project/UI-V03-HANDOFF.md 对齐 v0.3；UI仍 CHANGES_REQUESTED，契约未冻结，M1 TODO，产品测试NOT_RUN。

2026-09-07T16:15:00+08:00：PM 审阅 QA 复核报告（`docs/qa/M0-UI-RECHECK-003.md`）及交接文件（`docs/handoffs/M0-QA-REV3-qa-001.md`、`docs/handoffs/M0-UI-ui-003.md`）。确认 UIREV-03~06 及关联文案已全量 CLOSED，UI v0.3（`ARCHITECTURE-AND-FLOWS.md`、`COMPONENTS-AND-STATES.md`、`READER-ADAPTER-SPEC.md`）与后端契约（`0.1-draft / M0-BE-REV2`）完全互洽闭环，QA 结论为 PASS（设计闭环）。PM 将 M0-UI 状态更新为 DONE。至此，M0-PM、M0-BE、M0-QA、M0-UI 全部交付物设计评审通过，M0 阶段正式完整收口。M1-SETUP 规划状态置为 READY，明确单一工程配置写者（Codex1）、技术栈基线（SwiftUI + PDFKit + PencilKit）及源码目录隔离分工。严禁提前编写产品代码，当前全量产品测试继续保持 NOT_RUN。


