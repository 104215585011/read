# Claude2：v0.3 定向修订交接

任务：M0-UI-REV3。基线为三份 UI v0.2-revised 与 `docs/backend/CONTRACT-v0.1-draft.md` 修订标识 **0.1-draft / M0-BE-REV2**。不重做设计，不创建产品代码，不扩展功能。

开始前读 AGENTS.md、Claude2-UI 职责、WORKFLOW、BOARD、PM/QA 最新审阅、新后端契约及 `docs/handoffs/M0-BE-REV2-backend-001.md`，在 ui 日志写真实时间 READ_ACK/ACCEPTED。你只可修改 `docs/ui/**`、`docs/logs/ui.md`，并新增自己的唯一交接文件；不修改后端契约、根配置、看板或他人日志。

## 必须完成的四组差异

| ID | 精确位置 | v0.3 应如何对齐 | 复核场景 |
|---|---|---|---|
| UIREV-03 | READER-ADAPTER §3.2、§5；ARCHITECTURE §3.4、COMPONENTS状态14 | 保存入参引用契约 InkSaveSnapshot；明确 PageKey（documentID/documentRevision/pageIndex0）、readerSessionID、snapshotID、绘图快照和expectedRevision排队前固化。返回InkSaveReceipt；批量结果以PageKey/snapshotID区分，去除仅Int页号的返回。仅合并未开始旧快照；已提交确认更新原页persistedRevision，不能清除较新笔画dirty。旧会话结果不改新画布；dirty标记不是笔迹恢复数据；错误映射遵从服务契约 | A文档第0页保存中切B第0页；同页连续笔画保存确认乱序；后台预算不足；删除原文后迟到保存 |
| UIREV-04 | READER-ADAPTER §4.1示例与§5协议；全文重点导航描述 | 解析前捕获readerSessionID及文档/版本；await后在主执行域校验当前会话仍打开、当前文档/版本与NavigationTarget匹配、页号有效，在同一执行段导航。失配返回ignoredStaleSession，不导航不高亮。示例返回值与NavigationResult一致；全文重点也走同一入口。PDF页面rect用于导航，屏幕rect仅用于覆盖UI | A引用解析中切B、关闭A、替换版本；全文重点点击使用相同规则 |
| UIREV-05 | COMPONENTS状态10拆分；ARCHITECTURE §3.5 | failed保留具体错误及未完成部分内容，不发送cancelAI；用户对运行中attempt取消才发cancelAI，确认后cancelled。服务串行裁决互斥终态，alreadyTerminal不覆写原结果，迟到事件丢弃。重试/继续生成都创建新attempt且重新校验Manifest，不承诺流续传 | 失败后点击取消、完成与取消竞争、旧attempt晚到、新尝试失败 |
| UIREV-06 | ARCHITECTURE §3.1/§3.9；COMPONENTS删除弹窗、隐私/首次确认组件 | 显示值由outboundItems及四类Inclusion聚合，区分全文文本/原始PDF/页图/笔迹图/混合图与embedding用途，字数/图数使用清单字段。确认绑定Manifest摘要和providerSnapshot，覆盖buildIndex与buildStudyView全部批次，新增发送项/Provider变更需新确认。删除先previewDeleteDocument，提供必选keep/delete笔记策略及相应影响，再以impactID+expectedRevision+notePolicy提交；展示cleanupPending，不将逻辑删除直接当清理完成。keep笔记失去原文链接时显示documentDeleted不可导航 | 含笔迹合成图；首次embedding/全文分析；Provider改变；保留与删除笔记两路；预览后数据变化导致conflict |

## 同步少量关联字段与文案

- Notes 引用新增 createdAt/updatedAt，并支持删除原文后 documentID/chapterID 空值与失效来源呈现；不丢保留的文字/图片。
- 局部学习视图调用 buildStudyView 的显式 scope(pageRange inclusive)；全文为scope(document)，仍显示真实覆盖。
- 去掉 COMPONENTS 状态9.1“100%正常”；30秒超时标候选。将“任意长度”改成“不设25页硬上限，在资源与Provider能力内分批，失败与部分覆盖明确呈现”。
- 540pt是启用左右分栏的舒适门槛；更窄窗口仍可全宽阅读。70/30是受侧栏宽度约束的近似比例。
- requestID/attemptID用于诊断详情或内部状态；面向读者的默认标题显示阅读范围，避免把实现标识变成阅读必看内容。

UIREV-01/02/07主体已关闭，不重写无关区域。三份文档版本标为v0.3并注明BE-REV2，逐项交接写明修改位置、对应UI-T05/04/06/11等用例与实际检查方法；不得将文档检查写为产品通过。

交付新增 `docs/handoffs/M0-UI-ui-003.md`（如该名已存在则顺延，不能覆盖）。用户通知完成后，由QA定向复核→PM收口。当前M0-UI CHANGES_REQUESTED、M1 TODO；Mac构建、模拟器、真机和Provider全部NOT_RUN。
