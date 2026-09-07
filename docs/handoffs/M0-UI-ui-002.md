# M0-UI-REV 原生 UI 方案修订交接

时间：2026-09-07T15:21:15+08:00。发送：外部 UI 总监与前端负责人 Claude2；接收：项目经理 Claude1、项目测试 Codex2、项目后端 Codex1、主协调者。

基线：`docs/product/PRD-v0.1-source.md`、`docs/project/PLAN.md`、`docs/project/M0-UI-REVIEW.md`、`docs/qa/M0-UI-REVIEW.md`；契约：`docs/backend/CONTRACT-v0.1-draft.md` (0.1-draft)。

变更路径：
- `docs/ui/ARCHITECTURE-AND-FLOWS.md`
- `docs/ui/COMPONENTS-AND-STATES.md`
- `docs/ui/READER-ADAPTER-SPEC.md`
- `docs/logs/ui.md`
- `docs/handoffs/M0-UI-ui-002.md`

---

## 1. UIREV-01–07 逐项修订说明、修改位置与验收用例对应关系

| 修订项 (Review ID) | 审阅缺口与必须修订要求 | 规范文件修改位置 (docs/ui/) | 对应验收用例 | 详细修订与契约对齐说明 |
|---|---|---|---|---|
| **UIREV-01** | 旧 revision 不能自动跳旧页号；调用 resolveSource，仅有效目标导航；区分页级引用与 staleReference，stale 原地告警不跳；区分 conflict 写入冲突；invalidCitation 不可点击 | • `ARCHITECTURE-AND-FLOWS.md` §3.6<br/>• `COMPONENTS-AND-STATES.md` §2 状态 12<br/>• `READER-ADAPTER-SPEC.md` §4.1, §5 | R09, UI-01, UI-T07 | • 废除自动跳旧页逻辑；点击引用必须经 `resolveSource(SourceAnchor)` 解析；<br/>• `staleReference` 绝对保持当前视口不动，弹出 Toast 告警；<br/>• `precision == .page` 执行页级有效导航；<br/>• `invalidCitation` 置灰禁用；<br/>• `conflict` 明确归为批注/笔记保存冲突，走重载流程，不与引用跳转混淆。 |
| **UIREV-02** | `<25页` 仅为短文举例，不能当作全文 P0 边界；大文档支持分批分析、真实覆盖与遗漏页清单、取消/重试；用户主动缩范围标为“部分资料”，不冒充全文完成；readingEstimate 双态呈现 | • `ARCHITECTURE-AND-FLOWS.md` §3.7<br/>• `COMPONENTS-AND-STATES.md` §2 状态 15 | R10, UI-02, UI-T10 | • 澄清全文学习视图为全量 P0，支持 24/25/26 及 200+ 页长篇教材；<br/>• 接入 `buildStudyView` 分批异步分析进度条，显示真实 `coverage`（如 180/200 页）及遗漏清单；<br/>• 用户主动缩窄范围显式标为「部分资料学习视图 (P1–25)」，严禁冒充全文完成；<br/>• `readingEstimate` 严格实现 `available`（分钟与依据）与 `unavailable`（原因）两态展示。 |
| **UIREV-03** | 删除换页阻塞与后台“必须同步完成”承诺；增量异步保存状态机 (clean/dirty/saving/saved/failed/conflict)；expectedRevision 校验；覆盖层复用隔离与防乱序；2s 防抖标候选；失败保留旧有效版本 | • `ARCHITECTURE-AND-FLOWS.md` §3.4<br/>• `COMPONENTS-AND-STATES.md` §2 状态 14<br/>• `READER-ADAPTER-SPEC.md` §3.1–3.2, §5 | R03, R17, UI-05, UI-T05 | • 彻底删除换页同步阻塞与系统挂起前必写完的承诺；<br/>• 建立完整 6 态笔迹生命周期；保存入参包含 `expectedRevision`，写盘结果返回结构化 `Result<Int, SaveInkError>`；<br/>• 覆盖层解绑/复用前以 `pageKey` 与 `drawingRevision` 固化快照，拒绝乱序脏写；<br/>• 切后台申请 `beginBackgroundTask`，超时保留上一版有效 `savedRevision` 并记本地 dirty，绝不虚报成功。 |
| **UIREV-04** | 导航校验 documentID/revision 与非负页号；清晰划分 PDF 页面空间与屏幕空间，纠正 screenRect 误传 pdfView.go(to:on:)；三态工具态机 (Reading/Selection/Annotation)，消除 Pencil 绘写与选文冲突 | • `ARCHITECTURE-AND-FLOWS.md` §3.2, §3.3<br/>• `READER-ADAPTER-SPEC.md` §2.1–2.2, §4.1, §5 | R04, R09, UI-04, UI-T02, UI-T03, UI-T04 | • 导航参数严格校验 `0 <= pageIndex0 < pageCount`；<br/>• 空间规约：PDF 页面坐标用于持久化及 `pdfView.go(to: targetPdfRect, on: page)`；屏幕坐标仅用于 UI 覆盖动画；<br/>• 定义 `ReaderToolMode`（纯阅读/选文/批注），明确选文模式下抑制墨水；<br/>• 硬件双击/挤压标为设备条件可选增强，基础工具条全设备可用。 |
| **UIREV-05** | 显示 scopeSnapshot 与 requestID/attemptID；选区解除/翻页不篡改在途请求与旧回答标签；completed+schema/引用校验才算完成；未校验引用不可点；重试/继续生成派发新 attemptID；细化错误呈现 | • `ARCHITECTURE-AND-FLOWS.md` §3.5<br/>• `COMPONENTS-AND-STATES.md` §2 状态 5, 7, 9.1–9.4, 10, 11 | R05–R08, UI-06, UI-T06, UI-T08 | • 侧栏标头动态展示 `scopeSnapshot` 与 `requestID/attemptID`；<br/>• 选区消失或翻页仅影响后续新请求，在途请求维持原快照；<br/>• 完整流式生命周期事件（started/textDelta/completed/failed/cancelled），双重校验（Schema+引用）成功方呈完成态；<br/>• 细化 `offline`、`timeout`、`rateLimited (429倒计时)`、`providerNotConfigured`、`authFailed`、`unsupportedCapability`。 |
| **UIREV-06** | 隐私面板反显真实 ContextManifest，不恒定承诺未发整本/图片；区分原始文件、全文文本、扫描图与 embedding；首次外发/索引先呈现范围并确认；删除文档提示级联影响 | • `ARCHITECTURE-AND-FLOWS.md` §3.1, §3.9<br/>• `COMPONENTS-AND-STATES.md` §1, §2 状态 6 | R17, UI-03, UI-T11 | • 废除静态硬编码口号；动态绑定底层 `ContextManifest`（范围、文本量、图像、Token、截断理由）；<br/>• 增设首次联网请求与首次向量索引外发确认弹窗 (`FirstTimeConsentModal`)；<br/>• 删除文档弹窗提示将同步清理本地索引、缓存、批注及笔记。 |
| **UIREV-07** | iPadOS 17+ 标候选；消解 900pt 处 70/30 与固定宽度冲突，确立阅读最小宽度 540pt 优先；Notes 基于契约 Note 实体保持普通文本/引用/图片基线；去绝对化承诺；增加动态字体与减少动态效果适配 | • `ARCHITECTURE-AND-FLOWS.md` §1, §2.1–2.2, §3.8<br/>• `COMPONENTS-AND-STATES.md` 标题, §1, §3<br/>• `READER-ADAPTER-SPEC.md` 标题, §4.2 | R02, R03, UI-08, UI-T01 | • 目标系统统一标为：`iPadOS 17.0+（技术候选，最低系统版本以工程验证和 PM 冻结为准）`；<br/>• 确立核心阅读区 $\ge 540\text{ pt}$ 刚性约束；$\ge 900\text{ pt}$ 侧栏限制在 `[320 pt, 400 pt]`；不足则自动转为底部抽屉；<br/>• 删减非基线的专有富文本/涂鸦扩充，Notes 严格基于 `Note` 实体构建纯文本卡片；<br/>• 删除“100%正常/绝对不位移”，补足 Dynamic Type 与 Reduce Motion 静态边框降级。 |

---

## 2. 验证与产品状态声明

1. **文件完整性检查**：
   - 确认 `docs/ui/ARCHITECTURE-AND-FLOWS.md`、`docs/ui/COMPONENTS-AND-STATES.md`、`docs/ui/READER-ADAPTER-SPEC.md` 均已更新且格式健全；
   - 确认三份规范间术语（`pageIndex0`、`resolveSource`、`staleReference`、`scopeSnapshot`、`expectedRevision`）完全统一闭环。
2. **产品代码与测试状态**：
   - **本轮严格执行“暂时不要创建产品代码”原则，未创建任何 Swift 或客户端源码**；
   - 当前宿主为 Windows 环境，Xcode 原生编译、模拟器运行及 iPad 真机手写测试均如实标为 **`NOT_RUN`**；
   - 验收矩阵 R01–R21 与联调用例 UI-T01–UI-T11 保持为可测性设计，等待后续 M1 授权后在真实 Mac/iPad 上执行。

---

## 3. 释放范围与下一步

- 本轮修订完成，释放 `docs/ui/**` 排他写入权限；
- 提请 PM (Claude1) 与 QA (Codex2) 对照本交接逐项复核，关闭设计审阅，评估进入 M1-SETUP 准入条件。
