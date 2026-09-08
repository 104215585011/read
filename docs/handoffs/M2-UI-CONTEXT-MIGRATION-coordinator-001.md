# M2 UI 上下文迁移交接与文件释放

- 发起方：主协调者 (Coordinator)
- 接收方：项目经理 (Claude1-PM)、UI 总监 (Claude2-UI)
- 时间：2026-09-08T08:52:00+08:00
- 关联授权文档：`docs/handoffs/M2-UI-CONTEXT-ROUTE-pm-001.md`

---

## 1. 迁移完成内容

依 PM 临时路由授权，主协调者已在 `StudyOS/ViewModels/ReaderViewModel.swift` 中完成最小上下文调用闭环迁移：

1. **真实物理页面文本提取能力**：
   - 增加 `extractPageText(pageIndex0: Int) -> String?`：优先从当前活跃的 `adapter.pdfView.document` 中提取页面物理文本；兜底尝试从 `document.localFileRef` 加载 `PDFDocument` 提取。
   - 增加 `collectPageTexts(for scope: AIScope) -> [Int: String]`：根据当前请求范围（`.selection`, `.page`, `.chapter`, `.document`）精确收集所需物理页的文本映射。

2. **`askAI(text:selectedAnchor:)` 调用迁移**：
   - 在追加新一轮用户/助手占位消息前，提取已有历史未中断对话记录为 `conversationHistory: [LLMMessage]`；
   - 调用 `collectPageTexts(for: scopeToUse)` 获取真实正文；
   - 调用 `ContextAggregator().buildContext(...)` 生成不可变 `AggregatedContext`（包含真实的 `manifest`、`messages` 与 `capturedRequest`）；
   - 更新 UI 可见清单：`self.activeManifest = aggregated.manifest`；
   - 传递同一个 `aggregated` 调用 `coreService.aiService.generateStream(request: request, context: aggregated)`，彻底杜绝清单与正文脱节或伪造。

3. **`generateStudyGuide(scope:)` 调用迁移**：
   - 依据 `scope` 提取真实页面文本；
   - 构建不可变 `AggregatedContext`；
   - 更新 UI 可见清单：`self.activeManifest = aggregated.manifest`；
   - 传递同一个 `aggregated` 调用 `coreService.aiService.generateStream(request: request, context: aggregated)`。

4. **异常与取消对齐**：
   - 显式捕获 `CancellationError` 与 `LLMProviderError.cancelled`，严格置为 `.cancelled` 终态；
   - 异常捕获提取 `(error as? LocalizedError)?.errorDescription ?? error.localizedDescription`，使 `unsupportedCapability`（如全文范围分批导读提示）与 `invalidResponse` 能够清晰呈现于 UI 与 Toast。

---

## 2. 独占锁释放声明

主协调者对 `StudyOS/ViewModels/ReaderViewModel.swift` 的临时独占编辑已结束。
**即刻解除独占锁定，将该文件的所有权完全归还 UI 总监 Claude2-UI 及 PM 统筹**。主协调者后续不再直接修改该文件。

---

## 3. 待验收与后续推进

1. 本地 SPM 语法与并发隔离审计完成；
2. 待提交推送并由 GitHub Actions 远程 CI 云端运行（macOS-14 + iPadOS 17.5 模拟器）执行包括 `StudyOSTests/M2RegressionTests.swift` 与 `AIServiceTests.swift` 在内的 39 项全量自动化测试套件；
3. 全文范围独立分批任务（.document scope）按 PRD 与 PM 规划作为后续独立任务推进。
