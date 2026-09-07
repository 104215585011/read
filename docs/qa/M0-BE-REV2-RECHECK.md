# M0-BE-REV2 契约定向复核

时间：2026-09-07T15:30:46+08:00；Codex2；交接 M0-BE-REV2-backend-001；契约 0.1-draft / M0-BE-REV2。

结论：**此前 UIREV-03/04/05/06 的后端契约缺口已在设计层闭环**。这不关闭 UI v0.2 自身待修项，也不表示契约已由 PM 冻结。产品编译、回归、联调、mock、真实 Provider 和真机测试全部 **NOT_RUN**。

| 项目 | 后端设计复核 | CONTRACT-v0.1-draft.md 证据 |
|---|---|---|
| UIREV-03 保存归属 | 已补 PageKey、排队前不可变快照、完整Receipt及批量结果键；区分源PDF版本与drawing revision；仅合并未开始快照，已提交确认推进persistedRevision，较新笔画仍dirty；失效/删除不重建记录 | :76–78 |
| UIREV-04 导航会话 | NavigationTarget含文档/版本；await后在主执行域核对会话、当前文档/版本、目标和页号，同一执行段导航；ignoredStaleSession不导航；全文重点复用入口 | :80 |
| UIREV-05 AI终态 | 事件带attempt与scope；failed/cancelled互斥；只有用户对运行任务主动取消发cancelAI；已终态返回alreadyTerminal；重试新attempt并复核Manifest，迟到事件不覆盖 | :84–86 |
| UIREV-06 外发清单 | outboundItems含内容类型、用途、字数/图片数、全文文本区别、含笔迹合成图；inclusion由真实清单推导。确认绑定Manifest和Provider，覆盖索引/全文批次，动态变化重新确认 | :62–66 |
| UIREV-06 删除策略 | notePolicy必填keep/delete；预览版本摘要防过期；keep保留笔记/图片且来源失效，delete仅删无其他引用图片；cleanupPending不伪称物理清理完成 | :35,:70–72 |
| 关联字段 | Note已补createdAt/updatedAt与保留笔记所需可空documentID；学习视图显式document/pageRange scope | :19,:48 |

UI后续仅需对齐该契约：替换pageIndex0保存接口、补await后会话检查、分开failed/cancelled、真实Manifest展示及删除策略选择；新ignoredStaleSession/awaitingConfirmation/cleanupPending/alreadyTerminal需正确映射或作为内部状态处理。此前002复核中的剩余UI文案仍按PM反馈收敛。

实际验证：完整读取最新契约和交接，逐条对照002复核，`rg -n`确认上述字段与规则存在。没有运行产品或用模拟结果代替实测。建议PM接收本次BE文档，路由Claude2定向对齐后再安排QA复核UI。
