# StudyOS 原生 UI 方案与信息架构规范

- 规范版本：`v0.3-aligned-be-rev2`
- 对应阶段：`M0-UI`（依据 `docs/project/UI-V03-HANDOFF.md` 与 `0.1-draft / M0-BE-REV2` 契约修订）
- 责任角色：UI 总监与外部前端负责人（Claude2）
- 产品基线：`docs/product/PRD-v0.1-source.md`
- 核心服务契约基准：`docs/backend/CONTRACT-v0.1-draft.md` (修订标识：`0.1-draft / M0-BE-REV2`)
- 目标平台：iPadOS 17.0+（技术候选，最低系统版本以工程验证和 PM 冻结为准；SwiftUI + PDFKit + PencilKit）
- 关联验收用例：`docs/qa/ACCEPTANCE-MATRIX.md` (R01–R21) 与 `docs/qa/UI-INTEGRATION-CASES.md` (UI-T01–UI-T11)

---

## 1. 产品交互最高哲学与设计原则

根据 PRD 最高原则，StudyOS 绝不是“上传文档 → AI 总结 → 用户看 AI”的摘要工具，而是：
> **文档是主体 → 用户主动阅读 → AI 按需介入**
> 核心循环：`Read → Understand → Continue Reading`

1. **阅读优先（Reading First）**：默认必须提供 100% 全屏沉浸式阅读空间。AI 界面绝不永久侵占屏幕；
2. **随叫随到，用完即退（On-Demand Assistance）**：点击「✨ AI 助学」展开 70/30 分栏（横屏宽窗口）或自适应底部抽屉（竖屏/窄窗口），关闭立即无损恢复阅读视野；
3. **严格受控的原文溯源（Verified Grounding）**：AI 回答中所有引用必须经契约解析校验（`resolveSource`）并在主执行域确认当前会话（`readerSessionID`）与文档版本一致后才执行平滑跳转与脉冲发光定位；过期引用（`staleReference`）原地告警而不盲跳；未通过模型校验的非法引用（`invalidCitation`）禁止呈现为可点击的有效来源；已删文档来源标明失效不可导航；
4. **纸笔直觉与手写工效（Pencil-Native Ergonomics）**：提供清晰的三态工具机（阅读滚动、文本选择、PencilKit 批注），消除选文与书写的手势冲突；手写笔迹按 `PageKey`（含源文档版本与页码）与会话独立绑定并遵循排队前固化快照的异步增量持久化；
5. **用户拥有最终编辑权（User Ownership）**：AI 内容「加入笔记」严格沉淀为契约基线的普通可编辑纯文本（`editableText`）与引用锚点，支持保留笔记解除文档关联（`notePolicy: keep`）与失效来源呈现，不引入专有复杂富文本格式；
6. **动态外发透明与两路删除保障（Context Transparency & Lifecycle Safeguard）**：杜绝静态口号，通过动态 `ContextManifest` 聚合真实 `outboundItems`（区分全文提取文本与原始 PDF、图像类型与 embedding 用途），首次外发与全部分批执行显式授权；文档删除提供强制二选一的笔记保留/删除策略，展示真实清理进度。

---

## 2. iPad 屏幕适配与自适应分栏布局架构 (UIREV-07, UI-T01)

### 2.1 屏幕方向、窗口宽度与分栏优先级策略

针对横屏、竖屏、iPadOS Stage Manager（台前调度）及分屏多任务（Split View），确立以**阅读舒适门槛保护**为优先的自适应策略：

- **核心阅读舒适门槛**：PDFView 核心阅读区最小舒适宽度设计阈值为 **540 pt**（确保双栏学术论文与公式不发生严重缩水变形）。**说明**：540 pt 是启用左右分栏的舒适门槛，当窗口因系统分屏窄于 540 pt 时，系统进入全宽单页阅读模式，不阻碍阅读；
- **分栏比例与侧栏约束**：70/30 是受侧栏物理可用宽度约束的近似比例。AI 侧栏的物理宽度弹性收敛在 `[320 pt, 400 pt]` 黄金区间；
- **断点判定规约（以 900 pt 候选断点为基准）**：

| 窗口/屏幕形态 | 可用宽度条件 | 布局模式 | 布局细节与尺寸约束 |
|---|---|---|---|
| **iPad 横屏 / 全屏宽窗口** | 可用宽度 $\ge 900\text{ pt}$ 且剩余阅读区 $\ge 540\text{ pt}$ | **PDF 主视图 + AI 侧栏左右分栏** | - PDFView 视口动态过渡，保持当前阅读锚点不变<br/>- 侧栏宽度限制在 `[320 pt, 400 pt]` 舒适区间，PDF 占剩余宽度（约 70%）<br/>- 分栏支持点击顶部「收起」或边缘拖拽关闭 |
| **iPad 竖屏 / 分屏窄窗口** | 可用宽度 $< 900\text{ pt}$ 或侧栏展开会导致阅读区 $< 540\text{ pt}$ | **PDF 全屏 + AI 底部自适应抽屉 (Sheet / Inspector)** | - 严禁在窄屏下强行左右分栏压缩 PDF 字号<br/>- 底部抽屉提供三档高度：`折叠 (Hidden)`、`半开 (40% 视口)`、`大半开 (70% 视口)`<br/>- 半开状态下上方 PDF 仍保留关键视野并可翻阅 |

```text
================================ iPad 横屏布局 (Landscape ≥900pt: 约70/30) ================================
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│ ← 资料库  TCP-IP.pdf               [TOC] [书签] [搜索] [🖊️ 批注]                ✨ AI助学 (已展开) │
├───────────────────────────────────────────────────────────┬───────────────────────────────┤
│                                                           │ [ 选中内容 | 当前页 | 当前章节 ] │
│                                                           │ ───────────────────────────── │
│                                                           │ 当前范围: 第 3.2 节 (P8-15)    │
│                      PDF 核心阅读区                        │ (诊断详情: req-0907-a12/att-1) │
│                   (≥ 540 pt 舒适区)                        │ ───────────────────────────── │
│                                                           │ ① 这一部分在讲什么             │
│              [PencilKit 页面独立手写层]                     │   TCP 三次握手建立可靠连接...  │
│                                                           │                               │
│                 ┌────────────────────┐                    │ ② 阅读重点                     │
│                 │ 页面文本选区        │                    │   • 关注状态转移图              │
│                 └────────────────────┘                    │   • 理解 SYN/ACK 递增规则     │
│                                                           │                               │
│                                                           │ ... [加入笔记]                 │
│                                                           │ ───────────────────────────── │
│                                                           │ Ask AI: [文档模式 ▼] [输入...] │
├───────────────────────────────────────────────────────────┴───────────────────────────────┤
│                         ◀ 上一页    [ 12 / 46 ] (进度 26%)    下一页 ▶                      │
└───────────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 无障碍与动态效果适应 (Accessibility & Ergonomics)
- **动态字体 (Dynamic Type)**：AI 侧栏、六段卡片与问答流严格遵循 iOS 动态类型阶梯，字号缩放时不截断内容；
- **减少动态效果 (Reduce Motion)**：当系统开启「减弱动态效果」时，关闭 70/30 弹簧滑动与引用定位时的呼吸闪烁脉冲动画，改用即时淡入及静态矩形高亮框。

---

## 3. 核心界面详细设计与交互流程

### 3.1 首页资料库与两路删除策略 (Library & Deletion Policy - UIREV-06, UI-T11)

- **定位**：纯粹、无干扰的个人学术研读馆，严禁引入打卡、排行榜或强制复习组件。
- **核心组件与交互**：
  1. **顶部操作栏**：应用标题 `StudyOS`、文档搜索框、卡片/列表切换、「+ 导入资料」调起系统文档选择器；
  2. **「最近阅读」横向滚动区**：展示最近 5 份文档封面缩略图、标题、格式标签、阅读物理页进度百分比及最后阅读时间，点击精准恢复 `pageIndex0`；
  3. **资料库分类与文档列表**：文件夹分类、全部文档、收藏夹（⭐）、文档元数据与状态指示点；
  4. **两路笔记策略的文档删除交互 (`previewDeleteDocument` / `deleteDocument`)**：
     - 用户在文档卡片长按菜单点击「删除文档」时，客户端首先调用 `previewDeleteDocument(documentID/revision)` 获取该文档删除影响清单（`impactID`、文档版本摘要、受影响的批注数、手写数、会话数、关联笔记数及图片副本数）；
     - 弹出结构化确认弹窗，**强制用户必须显式二选一选择笔记策略 (`notePolicy`)**：
       - **选项 A：保留关联笔记 (`keep`)**：保留该文档所有笔记正文（`editableText`）、图片附件副本、创建/更新时间与原来源引文；自动解除笔记的 `documentID` 与 `chapterID` 归属，引用的 `SourceAnchor` 状态标记为 `documentDeleted` 且不可导航；仅彻底删除 PDF 原件、本地索引、手写笔迹及批注；
       - **选项 B：彻底删除关联笔记 (`delete`)**：将该文档的所有笔记随原件一同删除，并释放未被其他记录引用的本地图片副本；
     - 用户确认后携带 `confirmedImpactID`、`expectedRevision` 与所选 `notePolicy` 调用 `deleteDocument`；若预览后数据发生变动则提示 `conflict` 重新预览；
     - 界面展示真实清理状态：若原件已删但旁车待清，展示 `正在清理关联数据 (cleanupPending: 待清理文件 X 个)`，**严禁在后台未清完前宣称物理清理已完成**。

---

### 3.2 PDF 阅读器与工具态机 (Reader View & Tool States - UIREV-04, UI-T02)

- **定位**：最高频的核心工作区，提供零干扰的高性能阅读与批注。
- **三态工具状态机 (Tool State Machine)**：
  明确划分三大工具态，消除触笔书写与文本长按选择的手势冲突：

| 工具状态 (Tool State) | 手指操作行为 (Finger) | Apple Pencil 操作行为 (Stylus) | 适用场景与状态切换 |
|---|---|---|---|
| **1. 纯阅读态 (Reading)**<br/>*默认状态* | 单指/双指滑动平滑翻页，双指捏合缩放 | 笔尖触碰**默认直接触发手写批注**（激活单页笔迹层），防误触机制忽略手掌压感 | 沉浸阅读时，拿起笔即可划线写字；工具栏收起 |
| **2. 文本选择态 (Text Selection)** | 长按并拖拽触发文字选择 handles，呼出浮动操作菜单条 | 笔尖精准点按并划选文本，呼出浮动菜单条，**此时抑制墨水绘制** | 用户主动长按文字，或从浮动菜单进入选择模式 |
| **3. 批注工具态 (Annotation Mode)** | 单指/双指用于视口漫游与翻页 | 依 `PKToolPicker` 当前选定工具（钢笔、荧光笔、铅笔、橡皮擦）进行矢量绘制 | 点击工具栏「🖊️ 批注」图标显式呼出原生工具箱 |

- **硬件手势支持声明 (UIREV-07, UI-T02)**：Apple Pencil 2 代「轻点两下」与 Apple Pencil Pro「挤压 (Squeeze)」定义为**设备条件可选增强**；在无对应硬件传感器的设备上，通过屏幕顶部触控工具栏平齐支持。
- **底栏物理页码显示 (UIREV-04, UI-T03)**：界面显示严格遵循 `pageIndex0 + 1` 物理页码（例如第 0 页渲染为 `1 / 46`），可辅助展示 PDF 内置罗马字母页标签，但禁止将重复印刷标签作为核心主键；快速跳页滑块拖拽时，严格校验目标页为非负且在 `[0, pageCount - 1]` 范围，越界直接拦截。

---

### 3.3 文本选择与上下文浮动菜单 (Text Selection & Callout Menu)

- 用户选中文字后，选区正上方弹出定制菜单：`[ 🖊️ 高亮 | 〰️ 下划线 | 📋 复制 | ✨ 助学解释 | 📝 加入笔记 ]`；
- 点击「✨ 助学解释」：自动捕获当前选区的 `SourceAnchor` 作为 `scopeSnapshot` 发起请求；
- **选区解除不污染在途请求 (UIREV-05, UI-T06)**：若用户发起请求后点击空白处解除选区，在途流式请求继续正常渲染并保持原始选区快照标签，决不被清空或篡改成新页。

---

### 3.4 Apple Pencil 批注与增量持久化契约 (UIREV-03, UI-T05)

- **PageKey 与单页独立绑定**：`PageKey = documentID + documentRevision + pageIndex0`。源文档版本与手写 `drawingRevision` 严格区分；
- **排队前固化快照与 Receipt 确认机制**：
  1. 触发保存时，客户端立即在排队前创建不可变的 `InkSaveSnapshot`，固化完整 `PageKey`、`readerSessionID`、`snapshotID`、`drawingBlob`、`canvasToPageTransform` 与 `expectedRevision`；
  2. 提交核心服务保存，返回以 `PageKey` 标识的 `InkSaveReceipt`；批量保存结果亦以 `PageKey` 与 `snapshotID` 严格区分，去除仅以 Int 页号为键的模糊映射；
  3. **乱序与合并规则**：同一 `PageKey` 串行提交；仅可合并尚未排队开始的旧快照。一旦收到已提交快照的 `InkSaveReceipt`，必须推进对应页面的 `persistedRevision`，**绝不可盲目丢弃已确认版本导致后续 `expectedRevision` 冲突**；
  4. **增量 dirty 规则**：收到保存成功确认仅清除对应 `snapshotID` 范围的 dirty 状态；若在保存期间用户产生了更新的笔划，页面继续保持 `dirty`，并使用刚确认的 `savedRevision` 作为下一次排队的 `expectedRevision`；
  5. **会话切换隔离**：若切换了文档或关闭了阅读器（`readerSessionID` 改变），旧会话的写盘确认仅更新底层服务账本，**绝对不反写或污染新会话的画布与保存指示状态**；
  6. **容灾与防抖**：抬笔后启动 2 秒候选防抖定时器（`debounceTimer`，为工程调优候选参数）。切入后台通过 `beginBackgroundTask` 申请异步写盘；若系统因后台预算耗尽提前终止，系统保持上一版有效 `savedRevision` 并在本地记录 `dirty` 供下次恢复。**客户端明确声明：dirty 标记仅用于指示有未提交修改，绝不宣称 dirty 标记本身能恢复未落盘的墨水笔画**。

---

### 3.5 核心功能：AI 助学侧栏 (AI Study Sidebar - UIREV-05, UI-T06)

- **顶级范围选择器**：`[ 选中内容 | 当前页 | 当前章节 ]`；
- **标题与快照诊断展示**：
  - 侧栏顶部面向读者的主标题直接展示易懂的阅读范围（如 `当前范围: 第 3.2 节 (P8-15)` 或 `当前范围: 当前页 (P12)`）；
  - `requestID` 与尝试序号 `attemptID` 收敛在轻量副标题或诊断抽屉中，供问题排查，避免干扰主体阅读；
  - 翻页或选区变动仅作用于下一次新发起的请求，在途请求维持原快照；
- **严格 PRD 六段式输出规范 (The Six-Section Structure)**：
  1. **① 这一部分在讲什么**：2~4 句话提炼核心问题与目的；
  2. **② 阅读重点**：3~5 条关注点列表；
  3. **③ 前置知识**：必备概念药丸标签，点击就地弹出 Popover 图文释义（不适用项显示说明理由，不生造内容）；
  4. **④ 核心概念**：术语名 + 一句话精准定义；
  5. **⑤ 容易理解错的地方 (Misconceptions)**：黄色警示卡片 ⚠️ 点出高频误区；
  6. **⑥ 阅读问题 (Reading Questions)**：1~3 个启发性问题，**严格遵循 PRD 规范：默认不提供答案**。
- **AI 互斥终态与重试模型 (UIREV-05)**：
  - 事件流：`started` → `textDelta` → `completed` / `failed` / `cancelled`；
  - **终态互斥细分**：
    - **`cancelled`**：仅当用户对运行中的 attempt 主动点击「终止生成」时，前端才调用 `cancelAI(requestID, attemptID)`。收到取消确认后进入 `cancelled` 状态，打字机光标停滞，标记为 `已终止生成 (部分结果)`；
    - **`failed`**：当遭遇网络断开、超时或服务端异常时，进入 `failed` 状态，保留具体结构化错误描述及已输出的部分文本。**前端严禁在 failed 发生时自动触发 cancelAI**；
    - 终态由服务端串行裁决。已处于终态的请求若收到迟到的取消动作，服务端返回 `alreadyTerminal`，前端不覆写原状态；终态之后到达的迟到事件一概丢弃；
    - **重试与继续生成**：点击「重试」或「继续生成」均触发 `retryAI` 生成全新的 `attemptID`，并重新核验当前 `ContextManifest` 是否依然有效。**前端明确标明：继续生成属于发起新尝试，绝不承诺未经实现的底层流续传**；
    - **完成态校验**：只有当收到 `completed` 且 Schema 校验与引用有效性校验（`validatedSources`）双重通过时，才呈现为完成态；未完成或未经验证的引用置灰禁用，不可点击。
- **自由问答 (Ask AI)**：支持文档模式（无依据时明确告知资料未提及）与扩展模式切换。

---

### 3.6 严格原文溯源与会话隔离导航 (Grounding Locator - UIREV-01, UIREV-04, UI-T04, UI-T07)

- **来源引用胶囊**：回答末尾展示来源标记（如 `📍 P12 第3段`、`📍 P15 图 3-2`）；
- **主执行域会话核对与安全导航协议**：
  点击引用胶囊时，客户端严禁直接用原页码盲跳，必须执行严格的跨会话核对：
  1. 客户端在发起前捕获当前阅读器会话快照：`sessionID = readerSessionID`、`docID = currentDocumentID`、`docRev = currentDocumentRevision`；
  2. 调用核心层 `resolveSource(sourceAnchor)`；
  3. **`await` 返回后，在主执行域（Main Actor）进行严格的三重安全核对**：
     - 当前阅读器会话是否仍处于打开状态（`readerSessionID == sessionID`）；
     - 当前显示的文档与版本是否依然匹配（`currentDocumentID == target.documentID && currentDocumentRevision == target.documentRevision`）；
     - 目标物理页码是否在合法边界内（`0 <= target.pageIndex0 < document.pageCount`）；
  4. **导航执行分流**：
     - **核对通过且有效**：在同一执行段调用 `pdfView.go(to: target.regions[0], on: page)`（入参严格使用 PDF 页面坐标），并在屏幕坐标转换后触发 `SourceAnchorFocusRing` 发光动画；若为页级引用则调用 `pdfView.go(to: page)` 并 Toast 说明；
     - **会话已切换或关闭**：直接返回 `ignoredStaleSession`，**绝不执行页面跳转，绝不绘制动画高亮，静默丢弃迟到导航**；
     - **源锚点版本过期 (`staleReference`)**：保持当前阅读位置不动，Toast 提示 `引用基于旧版本文档（版本不一致），无法定位至当前内容`；
     - **源锚点目标不可用 (`unavailable`)**：原地提示 `引用目标已失效或文档已删除`；
     - **模型非法伪造引用 (`invalidCitation`)**：引用胶囊置灰并标记 `[未验证来源]`，禁用点击交互；
     - **已删除文档保留笔记中的引用 (`availability == .documentDeleted`)**：标记为 `[原文档已删除]`，禁用点击。

---

### 3.7 全文学习视图 (Full Document Study View - P0 - UIREV-02, UIREV-04, UI-T10)

- **定位澄清**：全量 P0 核心功能，**不设 25 页硬上限，在系统资源与 Provider 能力限制内支持分批处理**（如 24、25、26 及 200+ 页文档），失败与部分覆盖明确呈现；
- **分批异步任务与范围入参**：
  - 调用 `buildStudyView`，显式传递 `scope`：
    - 全文分析传递 `scope: .document`；
    - 用户主动缩窄范围（如指定分析前 25 页或指定章节）传递显式页码范围 `scope: .pageRange(start...end inclusive)`；
  - 界面展示全局任务进度环；支持中途取消与重新分析；
- **真实覆盖率与局部范围提示**：
  - 视图头部显式展示分析覆盖率：`已分析 180/200 页 (90%)`，并列出遗漏页码清单（`coverage.uncoveredPages`）；
  - 若用户主动指定局部页码范围，视图顶部显著标明：`部分资料学习视图 (第 1–25 页)`，**绝不冒充全文完成**；
- **阅读时间估计的双态呈现**：
  - 文本充足时呈现 `available(minutes, basis, coverage)`：`预计阅读时间：约 45 min（基于 12,000 字与公式密度计算）`；
  - 文本不足/扫描件时呈现 `unavailable(reason)`：`暂无法估计阅读时间（原因：文档有效提取文本不足）`；
- **结构化核心模块与重点跳转 (UIREV-04)**：
  1. 资料结构大纲树；
  2. 核心概念云（含出现频次与关联章节）；
  3. **重点内容星级排行**（如 `★★★★★ 三次握手过程 P8–11`）：**重点项点击跳转严格复用 §3.6 的安全导航与会话核对入口，绝不绕过会话检查走后门盲跳**；
  4. 理解难点剖析；
  5. 知识关系拓扑树。

---

### 3.8 AI 笔记流 (AI Notes - UIREV-07)

- **契约基线对齐**：
  - 笔记严格基于契约 `Note` 实体构建，包含字段：`id`、`documentID?`、`chapterID?`、`editableText`、`imageRefs`、`sourceAnchors`、`aiOrigin?`、`revision`、`createdAt`、`updatedAt`；
  - 界面呈现为普通可编辑卡片，**不强制引入专有复杂富文本格式或笔记涂鸦引擎**；
  - 当原文档被删除且用户选择 `keep` 策略时，`documentID` 与 `chapterID` 置空，卡片顶部标记为 `独立笔记`，引用标记显示 `[原文档已删除]`（不可导航），但用户的文字正文、图片附件及创建/修改时间完整保留；
  - 用户对正文拥有 100% 最终编辑权。

---

### 3.9 Provider 配置与基于真实清单的隐私面板 (UIREV-06, UI-03, UI-T11)

- **配置面板**：支持 OpenAI 兼容端点配置（Base URL、Keychain 存储 API Key、Model Name），动态呈现 Provider 能力标签；
- **基于真实 ContextManifest.outboundItems 的隐私透明面板**：
  点击 AI 侧栏底部的「隐私与外发范围」图标，实时弹出面板，直接聚合反显底层生成的真实 `ContextManifest`：
  1. **传输内容分类与字符统计 (outboundItems 聚合)**：
     - 显式区分 `documentText`（提取的正文文本，标明字符数及是否为全文提取）、`originalPDF`（原始二进制文件，默认 excluded）、`pageImage`（页面位图截图）、`handwritingImage`（独立手写笔迹图）；
     - **含手写合成图标识**：对于混合页截图，若底层标记 `containsHandwriting: true`，UI 明确披露 `包含页面上的手写笔迹图像`，**严禁将包含笔迹的截图虚假声称为未发手写**；
  2. **四项显式包含决策 (Inclusion Status)**：
     - `originalFileInclusion`：`included / excluded(原因)`
     - `pageImageInclusion`：`included / excluded(原因)`
     - `handwritingInclusion`：`included / excluded(原因)`
     - `annotationInclusion`：`included / excluded(原因)`
  3. **用途与 Token 估算**：明确标注每项用途（`generation / embedding / vision`），展示预计输入 Token、预留输出 Token 及截断原因（`truncationReasons`）；
- **首次外发授权确认弹窗 (`FirstTimeConsentModal`)**：
  - 覆盖 `generateGuide`、`ask`、`buildIndex` 的远端 embedding 外发、以及 `buildStudyView` 的全部分批请求；
  - 弹窗绑定 Manifest 摘要与 `providerSnapshot`（profileID、端点地址、模型名），经用户点击确认后方可发送；
  - **动态变更重确认机制**：若后续操作增加了新的外发数据项、扩充了发送范围或切换了 Provider，系统自动终止旧确认令牌，弹出新清单重新征得用户授权确认。
