# M0-UI-REV3 原生 UI 方案 v0.3 定向对齐交接

时间：2026-09-07T15:36:15+08:00。发送：外部 UI 总监与前端负责人 Claude2；接收：项目经理 Claude1、项目测试 Codex2、项目后端 Codex1、主协调者。

基线：
- `docs/product/PRD-v0.1-source.md`
- `docs/project/PLAN.md`
- `docs/project/UI-V03-HANDOFF.md`
- `docs/qa/M0-UI-RECHECK-002.md`
- `docs/backend/CONTRACT-v0.1-draft.md` (修订标识：`0.1-draft / M0-BE-REV2`)
- `docs/qa/M0-BE-REV2-RECHECK.md`
- `docs/handoffs/M0-BE-REV2-backend-001.md`

变更路径：
- `docs/ui/ARCHITECTURE-AND-FLOWS.md` (版本：`v0.3-aligned-be-rev2`)
- `docs/ui/COMPONENTS-AND-STATES.md` (版本：`v0.3-aligned-be-rev2`)
- `docs/ui/READER-ADAPTER-SPEC.md` (版本：`v0.3-aligned-be-rev2`)
- `docs/logs/ui.md`
- `docs/handoffs/M0-UI-ui-003.md`

---

## 1. 四组关键差异与关联文案修订对应清单

| 修订项 (ID) | v0.3 定向对齐核心内容 | 规范修改具体位置 (docs/ui/) | 对应验收场景/用例 | 详细契约映射与设计对齐说明 |
|---|---|---|---|---|
| **UIREV-03**<br/>(保存归属与快照) | 入参引用契约 `InkSaveSnapshot`；明确 `PageKey`（`documentID/documentRevision/pageIndex0`）、`readerSessionID`、`snapshotID`、快照和 `expectedRevision` 排队前固化；返回 `InkSaveReceipt`；批量结果以 `PageKey` 与 `snapshotID` 标识；仅合并未排队旧快照；已提交确认推进原页 `persistedRevision`；较新笔画保持 `dirty`；旧会话结果不改新画布；`dirty` 标记不作笔迹恢复数据；错误映射契约 | • `READER-ADAPTER-SPEC.md` §3.1–3.2, §5<br/>• `ARCHITECTURE-AND-FLOWS.md` §3.4<br/>• `COMPONENTS-AND-STATES.md` §2 状态 14 | UI-T05, R03, R17<br/>(A文档第0页保存中切B第0页；同页连续笔画保存确认乱序；后台预算不足；删除原文后迟到保存) | 1. 彻底废除仅以 `Int` 页号作为键的 flush 接口，采用契约 `PageKey` 与不可变 `InkSaveSnapshot`；<br/>2. 串行提交中仅合并未开始的旧快照，已确认 Receipt 必须更新原页 `persistedRevision`，杜绝后续版本冲突；<br/>3. 确认只清当前快照范围 dirty，新笔画继续 dirty 并用新版本排队；<br/>4. 会话变更时旧结果仅更新底层服务账本，绝不反写新画布；<br/>5. 明确声明 dirty 仅为指示状态，不冒充为未落盘笔迹的恢复数据；错误类型映射契约 `SaveInkError`。 |
| **UIREV-04**<br/>(会话核对与安全导航) | 解析前捕获 `readerSessionID` 及文档版本；`await resolveSource` 后在主执行域核对当前会话仍打开、文档版本匹配、`NavigationTarget` 匹配与页号有效，在同一执行段导航；失配返回 `ignoredStaleSession`，不导航不高亮；示例与协议统一返回 `NavigationResult`；全文重点跳转复用同一安全入口；PDF 页面 rect 传原生 API，屏幕 rect 用于覆盖层 | • `READER-ADAPTER-SPEC.md` §2.1–2.2, §4.1, §5<br/>• `ARCHITECTURE-AND-FLOWS.md` §3.6, §3.7<br/>• `COMPONENTS-AND-STATES.md` §1, §2 状态 12 | UI-T04, UI-T07, R09<br/>(A引用解析中切B、关闭A、替换版本；全文重点点击使用相同规则) | 1. `navigateTo` 在主执行域严格执行跨会话三重核对：会话一致性、文档ID/版本一致性、页号有效性；<br/>2. 会话关闭或切换返回 `ignoredStaleSession`，静默丢弃迟到导航，不跳页不闪烁；<br/>3. 全文学习视图重点项跳转（`FocusSectionRankCard`）明确复用 `navigateTo` 会话校验，杜绝后门盲跳；<br/>4. 严格将 PDF 页面 points 传入 `pdfView.go(to: targetPdfRect, on: page)`，屏幕 points 仅用于动画覆盖层。 |
| **UIREV-05**<br/>(终态互斥拆分与重试) | `failed` 保留具体错误及未完成部分内容，不发送 `cancelAI`；用户对运行中 attempt 主动取消才发 `cancelAI`，确认后进入 `cancelled`；服务串行裁决互斥终态，已终态返回 `alreadyTerminal` 不覆写；迟到事件丢弃；重试/继续生成均创建新 attemptID 并重验 Manifest，不承诺流续传 | • `COMPONENTS-AND-STATES.md` §2 状态 10.1, 10.2<br/>• `ARCHITECTURE-AND-FLOWS.md` §3.5 | UI-T06, UI-T08, R05–R08<br/>(失败后点击取消、完成与取消竞争、旧attempt晚到、新尝试失败) | 1. 拆分为独立的 `10.1 cancelled` 与 `10.2 failed` 两个互斥终态；<br/>2. 仅用户主动终止调用 `cancelAI`；服务端 failed 时前端绝对不自动触发 cancelAI，保留具体错误与未完成文本；<br/>3. 服务端串行裁决终态，`alreadyTerminal` 不覆写原结果，终态后事件丢弃；<br/>4. 重试与“继续生成”均派发新 `attemptID` 并重新校验 Manifest，明确标明非流续传。 |
| **UIREV-06**<br/>(外发清单与两路删除) | 显示值由 `outboundItems` 及四类 Inclusion 聚合，区分全文提取文本与原始 PDF、图像类型与 embedding 用途，字符数/图数严格依据清单字段；确认弹窗绑定 Manifest 摘要与 `providerSnapshot`，覆盖索引与全文全部分批，变更需重确认；删除提供 `previewDeleteDocument` 与强制二选一 `notePolicy(keep/delete)`，展示 `cleanupPending`，保留笔记标 `documentDeleted` 不可跳 | • `ARCHITECTURE-AND-FLOWS.md` §3.1, §3.9<br/>• `COMPONENTS-AND-STATES.md` §1, §2 状态 16 | UI-T11, R16, R17<br/>(含笔迹合成图；首次embedding/全文分析；Provider改变；保留与删除笔记两路；预览后数据变化导致conflict) | 1. 隐私面板直接聚合 `outboundItems`：区分 `documentText` 与 `originalPDF`，呈现 `purpose(generation/embedding/vision)`，针对混合图依据 `containsHandwriting` 明确披露含手写，字符数/图数严格依据清单；<br/>2. 首次外发确认覆盖索引与全文全部分批，Provider/范围变更重新确认；<br/>3. 删除弹窗强制二选一选择 `notePolicy`：`keep` 保留文字/图片/时间并将来源标为 `documentDeleted`（不可导航），`delete` 彻底删除关联笔记；真实展示 `cleanupPending`，不虚报物理清理完成。 |
| **关联文案与字段同步** | 1. Notes 实体补齐 `createdAt`、`updatedAt`、可空 `documentID?`、`chapterID?`；<br/>2. 局部学习视图显式调用 `scope(.pageRange)`，全文调用 `scope(.document)`；<br/>3. 移除组件状态“100%正常”措辞；30s 超时标候选；长文档改为“不设 25 页硬上限，在系统资源与 Provider 能力内分批，失败与部分覆盖明确呈现”；<br/>4. 540pt 明确为启用分栏的舒适门槛，更窄窗口仍可全宽单页阅读；70/30 为受侧栏约束的近似比例；<br/>5. 读者默认主标题呈现阅读范围，`requestID/attemptID` 收敛在诊断抽屉中。 | • `ARCHITECTURE-AND-FLOWS.md` §1, §2.1, §3.5, §3.7, §3.8<br/>• `COMPONENTS-AND-STATES.md` §1, §2 状态 9.1, 9.2, 13, 15 | UI-T01, UI-T10, R02, R10, R11 | 消除所有残留歧义，与后端契约 `M0-BE-REV2` 语义与 QA 复核报告逐字对齐。 |

---

## 2. 验证与产品状态声明

1. **规范文档核查**：
   - 确认 `docs/ui/` 目录下全部三份规范版本均升级为 `v0.3-aligned-be-rev2`；
   - 确认核心结构体与方法签名（`PageKey`、`InkSaveSnapshot`、`InkSaveReceipt`、`SaveInkError`、`NavigationResult`、`ReaderToolMode`、`ReaderAdapterProtocol`）在三份规范间 100% 互洽，且与后端契约 `CONTRACT-v0.1-draft.md` 完全一致；
2. **产品代码与测试状态**：
   - **本轮严格执行“不创建产品代码”要求，未创建或修改任何 Swift/Xcode 客户端代码**；
   - 当前宿主为 Windows 环境，Xcode 原生构建、模拟器运行、真机 Apple Pencil 手写实测及真实 Provider 调用均如实记录为 **`NOT_RUN`**；
   - 验收矩阵 R01–R21 与联调用例 UI-T01–UI-T11 保持为可测性设计，等待后续 M1 授权后在真实 Mac/iPad 上执行。

---

## 3. 释放范围与下一步建议

- 本轮 v0.3 定向修订已全部完成，释放 `docs/ui/**` 排他写入权限；
- 提请测试 Codex2 对本交接及三份 v0.3 规范进行定向复核；
- 提请项目经理 Claude1 审阅复核结果，评估关闭 M0-UI 并收口 M0 阶段。
