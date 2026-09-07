# M0-QA-REV3 定向复核交接文件

- 发送角色：项目测试负责人（Codex2）
- 接收角色：项目经理（Claude1）、主协调者、项目后端（Codex1）、外部 UI 总监（Claude2）
- 报告时间：`2026-09-07T16:13:30+08:00`
- 交付物：
  - 定向复核报告：`docs/qa/M0-UI-RECHECK-003.md`
  - 测试日志更新：`docs/logs/qa.md`
  - 独立交接文件：`docs/handoffs/M0-QA-REV3-qa-001.md`

---

## 1. 核心复核结论

经对 `docs/ui/` 目录下三份 `v0.3-aligned-be-rev2` 规范（`ARCHITECTURE-AND-FLOWS.md`、`COMPONENTS-AND-STATES.md`、`READER-ADAPTER-SPEC.md`）进行严格的逐项语义审查与契约交叉验证：

1. **UIREV-03 (保存归属与快照)**：**CLOSED（设计通过）**。入参引用不可变 `InkSaveSnapshot`，固化 `PageKey`、`readerSessionID`、`snapshotID` 与 `expectedRevision`；返回 `InkSaveReceipt` 推进原页 `persistedRevision`；仅合并未排队旧快照；新笔画保持 dirty；旧会话结果不改新画布；`dirty` 不作为笔迹恢复数据；`SaveInkError` 完整对齐。
2. **UIREV-04 (会话核对与安全导航)**：**CLOSED（设计通过）**。主执行域严格执行跨会话三重核对；会话失配返回 `ignoredStaleSession` 静默丢弃；全文重点项复用安全入口；严格区分 PDF 页面 points 传原生 API 与屏幕 points 用于覆盖高亮。
3. **UIREV-05 (终态互斥拆分与重试)**：**CLOSED（设计通过）**。拆分为独立的 `cancelled` 与 `failed` 互斥终态；`failed` 严禁调 `cancelAI`；服务端串行裁决终态，`alreadyTerminal` 不覆写；迟到事件丢弃；重试/继续生成派发新 `attemptID` 并重验 Manifest，明确标明非流续传；未校验来源置灰禁用。
4. **UIREV-06 (外发清单与两路删除)**：**CLOSED（设计通过）**。隐私面板直接聚合反显 `ContextManifest.outboundItems`，区分提取正文与原始 PDF，注明用途；混合图含手写明确披露；四项 Inclusion 显式展示；首次确认覆盖远端 embedding 与全部分批，变更触发重签；删除弹窗强制二选一 `notePolicy(keep/delete)`，真实展示 `cleanupPending`；保留笔记解绑归属标 `documentDeleted` 不可跳。
5. **文案与关联字段同步**：**CLOSED（设计通过）**。Note 补齐时间与可空归属；局部学习视图显式传 `scope(.pageRange)`；彻底去除“100%正常”；30s 超时标候选；长文档不设 25 页硬限；540pt 明确为分栏舒适门槛；读者主标题呈现阅读范围。

**总体结论**：UI v0.3 设计规范与核心服务契约（`0.1-draft / M0-BE-REV2`）达成 100% 互洽与闭环，所有前序设计待修项均已关闭。评估结论为 **`PASS（设计闭环）`**。

---

## 2. 真实状态与环境声明 (NOT_RUN)

- 本轮严格遵守 WORKFLOW，**未编写或修改任何客户端与服务端产品代码**；
- 当前处于 Windows 工作区环境，所有 Apple SDK / Xcode 编译、模拟器运行、iPadOS 真机 Apple Pencil 手写实测及真实 Provider 网络调用均如实保持为 **`NOT_RUN`**；
- 验收矩阵 `ACCEPTANCE-MATRIX.md` (R01–R21) 与 `UI-INTEGRATION-CASES.md` (UI-T01–UI-T11) 具备高度可测性，等待 M1 阶段真机就绪后执行。

---

## 3. 下一步建议

1. 请项目经理 Claude1 查阅本交接与 `docs/qa/M0-UI-RECHECK-003.md`，在 `BOARD.md` 中将 `M0-UI 原生 UI 方案` 的状态从 `CHANGES_REQUESTED` 调整为 **`DONE`**；
2. 正式收口 M0 阶段各方设计交接，准备向 M1-SETUP 规划过渡。
