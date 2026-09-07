# UI v0.2-revised 独立复核

后续：`M0-BE-REV2-RECHECK.md` 已确认后端契约缺口补齐；本报告的 UI v0.2 待修项仍须外部 UI 对齐，不能用后端更新替代 UI 复核。

时间：2026-09-07T15:24:02+08:00；QA Codex2；输入：M0-UI-ui-002、三份 v0.2-revised、PM UIREV-01–07、CONTRACT-v0.1-draft 及后端 ARCHITECTURE。

结论：**建议保留 CHANGES_REQUESTED（设计）**。首轮主要方向已修订，但不能确认“字段与状态完全闭环”。下表 CLOSED 仅为该设计问题已解决；所有产品测试仍 **NOT_RUN**。

| 修订 ID | 复核结论 | 证据与剩余关闭条件 |
|---|---|---|
| UIREV-01 | CLOSED（旧引用处理） | ARCHITECTURE §3.6、COMPONENTS:100、READER-ADAPTER:149–158 均明确 staleReference/unavailable 原地提示，页级有效引用才跳，invalidCitation 禁用；写冲突已分离。异步切文档问题另列 UIREV-04，不重复计数。 |
| UIREV-02 | CLOSED（全文 P0） | ARCHITECTURE:190–206、COMPONENTS:103 明确长文档分批、覆盖/遗漏、取消重试、主动局部标识与 readingEstimate 双态；不再默认截25页。将“任意长度”改成“不设25页硬限，受资源约束并明确失败/部分覆盖”可随修订清理。局部scope参数见下方契约待对齐项。 |
| UIREV-03 | PARTIAL | 异步状态、expectedRevision、复用快照已补。但 READER-ADAPTER:212–213 对外 flush 仅 pageIndex0，批量结果亦仅 Int 页号，未明确调用时固化文档/revision/session；与后端 CONTRACT:39 的 pageKey 不充分对应。关闭：API 使用 PageKey+绘图快照或显式声明 adapter 生命周期固定绑定文档revision，排队任务捕获完整pageKey，批量结果不可跨文档碰撞。:104 “丢弃旧在途写盘结果”需区分未开始旧快照与已提交确认，不能忽略已提交savedRevision令后续expectedRevision冲突。:105 dirty标志仅提示未保存，不能凭标志恢复尚未落盘的笔迹。 |
| UIREV-04 | PARTIAL | 页面坐标已纠正，非负页检查与工具态已补。READER-ADAPTER:118 在 await 前捕获 document，:121 后未再核对当前阅读器 documentID/revision/session；有效 source 属 A，不表示返回时阅读器仍显示 A。关闭：resolve后在UI执行域再次比对会话、文档和revision，变更则丢弃结果，不导航/高亮；示例与protocol返回 NavigationResult 对齐。把全文重点项 ARCHITECTURE:204、COMPONENTS:64 的“直接跳转”明确复用同一安全路径。 |
| UIREV-05 | PARTIAL（小修） | scope快照、attemptID、终态校验与错误分型已补。COMPONENTS:98 仍把用户cancelled与服务failed统一发cancelAI并显示已终止；与契约分开的终态冲突。关闭：只有用户取消发cancelAI；failed保留具体错误/部分输出并按失败重试，终态后旧事件丢弃。明确“继续生成”为新尝试而非未经实现的流续传。 |
| UIREV-06 | PARTIAL（需BE先补契约映射） | 动态Manifest与首次确认已补，但 ARCHITECTURE:227–228 承诺字数/图像/内容类型，CONTRACT:55 仅有范围、evidenceIDs、pageCoverage、annotationInclusion、tokens等，无对应类型/图像/原件字段或推导规则。关闭：BE明确传输清单字段或可验证映射（文本/全文文本/原始文件/扫描图/笔迹图/embedding），UI按冻结契约展示。ARCHITECTURE:99、COMPONENTS:23 将笔记固定级联删除，而后端ARCHITECTURE:34要求显式保留/删除参数；补用户可选保留笔记和对应删除操作参数，不能只询问是否全删。 |
| UIREV-07 | CLOSED（主要范围），文案待清理 | 三份标题均把17+标候选，Notes editableText+图片/引用基线已恢复，硬件增强可选。COMPONENTS:94 残留“100%正常”；:95 30秒超时还未标候选。ARCHITECTURE:34 的540pt应解释为启用分栏的舒适门槛，窄于540pt窗口仍可全宽阅读；70/30为近似比例，受320–400pt侧栏约束。这些不另新增功能门槛。 |

## 契约冻结前的字段对齐清单

只列已有交互所需映射，不要求扩充产品：

- CONTRACT:45 buildStudyView 目前仅 documentID/revision/providerProfileID；UI允许主动选局部，需明确scope入参或标为待契约接入，不用整文接口假装局部调用。
- Note 在 CONTRACT:17 缺创建时间而 UI:215 显示创建时间；补字段或明确来源。
- NavigationTarget 的 documentID/revision/session校验来源、PageKey、SaveInkError 映射由BE/UI共同确定，不能UI单方面把新类型视为已冻结契约。
- 首次外发确认必须覆盖 buildStudyView/buildIndex 实際发送路径，不只 generateGuide/ask；Manifest变更或Provider变化时旧确认不能代表新的实际发送范围。

## 验证范围

读取全部三份规范并对照原契约，`rg -n` 核对字段及矛盾位置；无代码构建/运行。尚未进行 Apple SDK 编译、真机几何/保存、真实Provider或mock执行。本次以本地语义一致性为证据，不把SDK API示例视为已编译。

建议顺序：PM路由契约映射给BE串行修订 → UI对齐剩余文本与示例 → QA针对以上差异复核 → PM判设计收口。无需重新扩充整套设计。
