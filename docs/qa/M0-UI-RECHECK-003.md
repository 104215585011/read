# M0-UI-REV3 原生 UI 方案 v0.3 定向复核报告

- 报告编号：`M0-UI-RECHECK-003`
- 复核时间：`2026-09-07T16:13:00+08:00`
- 复核角色：项目测试负责人（Codex2）
- 依据基线：
  - `docs/product/PRD-v0.1-source.md`
  - `docs/project/PLAN.md`
  - `docs/project/BOARD.md`
  - `docs/project/UI-V03-HANDOFF.md`
  - `docs/qa/M0-UI-RECHECK-002.md`
  - `docs/backend/CONTRACT-v0.1-draft.md` (修订标识：`0.1-draft / M0-BE-REV2`)
  - `docs/handoffs/M0-BE-REV2-backend-001.md`
  - `docs/handoffs/M0-UI-ui-003.md`
- 审查对象：
  - `docs/ui/ARCHITECTURE-AND-FLOWS.md` (版本：`v0.3-aligned-be-rev2`)
  - `docs/ui/COMPONENTS-AND-STATES.md` (版本：`v0.3-aligned-be-rev2`)
  - `docs/ui/READER-ADAPTER-SPEC.md` (版本：`v0.3-aligned-be-rev2`)
- 关联验收用例：`docs/qa/ACCEPTANCE-MATRIX.md` (R01–R21) 与 `docs/qa/UI-INTEGRATION-CASES.md` (UI-T01–UI-T11)

---

## 1. 逐项复核矩阵 (UIREV-03 ~ UIREV-06 及关联同步项)

| 修订项 ID | 关注核心点与契约对齐要求 | 审查证据与具体落实位置 | 复核结论 | 说明与关闭判定 |
|---|---|---|---|---|
| **UIREV-03**<br/>(保存归属与快照) | 1. 废除仅 `Int` 页号的 flush，入参引用契约 `InkSaveSnapshot`，含 `PageKey`（`documentID/documentRevision/pageIndex0`）、`readerSessionID`、`snapshotID`、快照和 `expectedRevision` 在排队前固化；<br/>2. 返回 `InkSaveReceipt`；批量结果以 `PageKey` 与 `snapshotID` 标识；<br/>3. 串行提交中仅合并未排队旧快照；已提交确认推进原页 `persistedRevision`；<br/>4. 较新笔画保持 `dirty`；<br/>5. 会话隔离（旧会话不改新画布）；<br/>6. `dirty` 标记不作笔迹恢复数据；<br/>7. 错误映射遵从契约 `SaveInkError`。 | • `READER-ADAPTER-SPEC.md` §3.1–3.2 (L81–134), §5 (L218–227, L265–266)<br/>• `ARCHITECTURE-AND-FLOWS.md` §3.4 (L118–128)<br/>• `COMPONENTS-AND-STATES.md` §2 状态 14 (L103)<br/>**核验证据**：<br/>- `PageKey`、`InkSaveSnapshot`、`InkSaveReceipt` 定义与契约完全一致；<br/>- 明确“仅合并尚未开始排队的旧快照”，“收到已提交快照的 InkSaveReceipt 必须推进对应页面的 persistedRevision，绝不可盲目丢弃已确认版本导致后续 expectedRevision 冲突”；<br/>- 明确“收到保存成功确认仅清除对应 snapshotID 范围的 dirty 状态；保存期间产生的较新笔画保持 dirty，并用刚确认的 savedRevision 作为下一次排队的 expectedRevision”；<br/>- 明确“旧会话的写盘确认仅更新底层服务账本，绝对不反写或污染新会话的画布与保存指示状态”；<br/>- 明确“dirty 标记仅用于指示有未提交修改，绝不宣称 dirty 标记本身能恢复未落盘的墨水笔画”；<br/>- 协议 `flushInk` 与 `flushAllDirtyInks` 均以 `PageKey` 与 `Result<InkSaveReceipt, SaveInkError>` 标识；<br/>- `SaveInkError` 完整对齐契约错误分型。 | **CLOSED**<br/>(设计通过) | 彻底消除跨文档跨页脏写与乱序版本冲突风险。设计完全闭环。 |
| **UIREV-04**<br/>(会话核对与安全导航) | 1. 解析前捕获 `readerSessionID` 及文档/版本；<br/>2. `await resolveSource` 后在主执行域（Main Actor）进行跨会话三重核对：当前会话仍打开、当前文档与版本匹配、页码有效性；<br/>3. 失配返回 `ignoredStaleSession`，静默丢弃迟到导航，不跳页不高亮；<br/>4. 示例返回值与协议统一为 `NavigationResult`；<br/>5. 全文重点项跳转复用同一安全入口；<br/>6. 区分 PDF 页面 points 传原生 API，屏幕 points 用于视觉高亮覆盖层。 | • `READER-ADAPTER-SPEC.md` §2.1–2.2, §4.1 (L144–205), §5 (L236–244, L257)<br/>• `ARCHITECTURE-AND-FLOWS.md` §3.6 (L161–175), §3.7 (L195)<br/>• `COMPONENTS-AND-STATES.md` §1 (L51, L64), §2 状态 12 (L101)<br/>**核验证据**：<br/>- `navigateTo` 在主执行域严格比对 `readerSessionID == capturedSessionID` 及 `target.documentID/documentRevision == capturedDocID/DocRevision`；<br/>- 会话改变直接返回 `.ignoredStaleSession`，静默丢弃迟到导航；<br/>- 示例与协议统一返回 `NavigationResult`；<br/>- 全文学习视图 `FocusSectionRankCard` 明确标注“点击跳转严格复用 ReaderAdapter.navigateTo 会话校验路径，绝不绕过会话检查走后门盲跳”；<br/>- 明确区分：`pdfView.go(to: targetPdfRect, on: page)` 传 PDF 页面坐标；`pdfView.convert(targetPdfRect, from: page)` 换算为屏幕坐标传给 `SourceAnchorFocusRing`。 | **CLOSED**<br/>(设计通过) | 彻底杜绝异步解析返回后的跨文档/跨会话盲跳与闪烁。设计完全闭环。 |
| **UIREV-05**<br/>(终态互斥拆分与重试) | 1. 拆分独立的 `cancelled` 与 `failed` 互斥终态；<br/>2. `failed` 保留具体错误及未完成部分内容，前端严禁向服务调用 `cancelAI`；<br/>3. 仅用户主动点击终止时调用 `cancelAI`，确认后进入 `cancelled`；<br/>4. 服务端串行裁决终态，已处于终态返回 `alreadyTerminal`，前端不覆写；迟到事件丢弃；<br/>5. 重试与“继续生成”均派发新 `attemptID` 并重新校验 Manifest，明确标明非流续传；<br/>6. 未校验来源（`invalidCitation`）置灰禁用交互。 | • `COMPONENTS-AND-STATES.md` §2 状态 10.1 (L98), 状态 10.2 (L99)<br/>• `ARCHITECTURE-AND-FLOWS.md` §3.5 (L145–153)<br/>**核验证据**：<br/>- COMPONENTS 状态 10 明确拆分为独立的「10.1 用户主动终止 (cancelled)」与「10.2 服务执行失败 (failed)」；<br/>- 明确规约：“当遭遇网络断开、超时或服务端异常时，进入 failed 状态，保留具体结构化错误描述及已输出的部分文本。前端严禁在 failed 发生时自动触发 cancelAI”；<br/>- 明确规约：“已处于终态的请求若收到迟到的取消动作，服务端返回 alreadyTerminal，前端不覆写原状态；终态之后到达的迟到事件一概丢弃”；<br/>- 明确规约：“重试或继续生成均触发 retryAI 生成全新的 attemptID，并重新核验当前 ContextManifest 是否依然有效。前端明确标明：继续生成属于发起新尝试，绝不承诺未经实现的底层流续传”；<br/>- 未完成与未经验证来源置灰禁用。 | **CLOSED**<br/>(设计通过) | 彻底消除前端与服务端终态裁决冲突、流状态污染与伪续传隐患。设计完全闭环。 |
| **UIREV-06**<br/>(外发清单与两路删除) | 1. 隐私面板动态聚合 `ContextManifest.outboundItems`，区分正文提取文本（`documentText`）与原始 PDF 二进制（`originalPDF`）、图像类型与 embedding 用途；<br/>2. 针对混合页截图若含手写依据 `containsHandwriting: true` 明确披露，严禁声称未发手写；<br/>3. 显式呈现四项 Inclusion（原件、页图、手写、批注）；字符数/图数严格依据清单；<br/>4. 首次外发确认（`FirstTimeConsentModal`）覆盖 `buildIndex` 远端 embedding 与 `buildStudyView` 全部分批，变更/扩充需重确认；<br/>5. 文档删除（`previewDeleteDocument`）强制二选一选择 `notePolicy(keep/delete)`，展示真实 `cleanupPending`；保留笔记解除归属，标 `documentDeleted` 不可导航。 | • `ARCHITECTURE-AND-FLOWS.md` §3.1 (L83–89), §3.9 (L211–229)<br/>• `COMPONENTS-AND-STATES.md` §1 (L23, L41, L75), §2 状态 16 (L105)<br/>**核验证据**：<br/>- 隐私面板直接基于契约 `ContextManifest.outboundItems` 聚合，清晰区分 `documentText`（提取文本、字符数、全量标识）与 `originalPDF`，注明 `purpose(generation/embedding/vision)`；<br/>- 针对混合图明确：“若底层标记 containsHandwriting: true，UI 明确披露包含页面上的手写笔迹图像，严禁将包含笔迹的截图虚假声称为未发手写”；<br/>- 显式列出四类 Inclusion（`originalFileInclusion`、`pageImageInclusion`、`handwritingInclusion`、`annotationInclusion`）；<br/>- 首次外发确认覆盖全部批次与远端 embedding，范围变更与 Provider 变动触发重确认；<br/>- 删除弹窗强制二选一 `notePolicy(keep/delete)`；保留笔记保留文字/图片/时间，解除外键归属，引用标 `documentDeleted` 且不可跳；提交后展示 `cleanupPending`，不虚报物理清理完成。 | **CLOSED**<br/>(设计通过) | 彻底消除隐私外发清单与删除生命周期歧义，完全对齐后端 M0-BE-REV2 契约。设计完全闭环。 |
| **关联文案与字段同步** | 1. Notes 实体补齐 `createdAt`、`updatedAt`、可空 `documentID?`、`chapterID?`；<br/>2. 局部学习视图显式调用 `scope(.pageRange)`，全文调用 `scope(.document)`；<br/>3. 彻底移除组件状态“100%正常”措辞；30s 超时标候选；长文档改为“不设 25 页硬上限，在系统资源与 Provider 能力内分批，失败与部分覆盖明确呈现”；<br/>4. 540pt 明确为启用分栏的舒适门槛，更窄窗口仍可全宽阅读；70/30 为受侧栏约束的近似比例；<br/>5. 读者主标题展示阅读范围，`requestID/attemptID` 收敛在诊断抽屉中。 | • `ARCHITECTURE-AND-FLOWS.md` §2.1 (L34), §3.5 (L134–136), §3.7 (L180–188), §3.8 (L203–208)<br/>• `COMPONENTS-AND-STATES.md` §1 (L32–33, L40, L60–61, L69), §2 状态 9.1 (L94), 状态 9.2 (L95), 状态 13 (L102), 状态 15 (L104)<br/>**核验证据**：<br/>- `Note` 实体字段与契约完全对齐，支持独立笔记与失效来源；<br/>- `buildStudyView` 明确传递 `scope(.document)` 与 `scope(.pageRange)`；<br/>- 全文检索确认无“100%正常”残留；超时标记“候选：30s”；长文档分批逻辑与非硬上限描述对齐；<br/>- 540pt 明确为左右分栏的阅读区舒适门槛；<br/>- 界面主标题面向读者呈现阅读范围，诊断标识移入副标题/抽屉。 | **CLOSED**<br/>(设计通过) | 文案与字段所有残留歧义均已清理，与前后端契约保持高度互洽。 |

---

## 2. 契约一致性与可测性交叉验证

1. **三份 UI 规范与后端契约 (0.1-draft / M0-BE-REV2) 互洽性**：
   - 核心数据结构（`PageKey`、`InkSaveSnapshot`、`InkSaveReceipt`、`SaveInkError`、`NavigationResult`、`ContextManifest`、`Note`、`DeleteResult`）在 `ARCHITECTURE-AND-FLOWS.md`、`COMPONENTS-AND-STATES.md`、`READER-ADAPTER-SPEC.md` 与 `CONTRACT-v0.1-draft.md` 中命名、字段、可选性及生命周期语义 100% 互洽；
   - 之前复核报告（`M0-UI-RECHECK-002.md`）中提出的全部 PARTIAL 待修项（UIREV-03、UIREV-04、UIREV-05、UIREV-06 及文案）已逐一得到圆满解决。
2. **测试用例与验收矩阵对应性**：
   - 本次修订的各项设计严格支撑验收矩阵 `R01–R21`，并与联调用例 `UI-T01–UI-T11` 精确契合（如 UI-T05 跨会话保存、UI-T04 会话安全导航、UI-T06 终态互斥、UI-T11 隐私与两路删除）；
   - 边界异常处理（`ignoredStaleSession`、`alreadyTerminal`、`cleanupPending`、`documentDeleted`）已具备清晰的可观察断言与验证逻辑。

---

## 3. 产品测试状态声明 (Strict NOT_RUN)

根据项目原则与 WORKFLOW 规定，本轮复核严格限定于**架构设计与接口契约的静态语义审查**：
- **未编写、未生成、未修改任何客户端或服务端产品代码**；
- 当前运行宿主为 Windows 环境，未执行 Xcode 编译、iOS 模拟器构建、iPadOS 真机 Apple Pencil 手写实测及真实 AI Provider 网络通信；
- 验收矩阵 `ACCEPTANCE-MATRIX.md` 中的所有用例与 `UI-INTEGRATION-CASES.md` 中的全部测试，状态统一保持为 **`NOT_RUN`**，绝无虚报通过。

---

## 4. 复核结论与推进建议

### 4.1 复核结论
- **M0-UI 设计方案（v0.3-aligned-be-rev2）复核结论：`PASS（设计闭环）`**。
- 建议项目经理（Claude1）在看板 `BOARD.md` 中将 `M0-UI 原生 UI 方案` 的状态从 `CHANGES_REQUESTED` 调整为 **`DONE`**（表示设计文档闭环收口）。

### 4.2 下一步建议
1. **收口 M0 阶段**：UI 与 BE 契约已达到高度互洽闭环，M0 阶段的文档、契约及架构设计工作已完备；
2. **推进 M1-SETUP 规划**：在真实 Mac 构建环境就绪后，由 PM 协调推进 M1-SETUP 任务，明确单一工程配置写者、Swift/Xcode 工程脚手架及前后端代码实现分工。
