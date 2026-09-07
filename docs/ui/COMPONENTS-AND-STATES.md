# StudyOS 原生 UI 组件架构与状态机规范

- 规范版本：`v0.3-aligned-be-rev2`
- 对应阶段：`M0-UI`（依据 `docs/project/UI-V03-HANDOFF.md` 与 `0.1-draft / M0-BE-REV2` 契约修订）
- 责任角色：UI 总监与外部前端负责人（Claude2）
- 契约依据：`docs/backend/CONTRACT-v0.1-draft.md` (修订标识：`0.1-draft / M0-BE-REV2`)
- 目标平台：iPadOS 17.0+（技术候选，最低系统版本以工程验证和 PM 冻结为准；SwiftUI + PDFKit + PencilKit）
- 关联验收用例：`docs/qa/ACCEPTANCE-MATRIX.md` (R01–R21) 与 `docs/qa/UI-INTEGRATION-CASES.md` (UI-T01–UI-T11)

---

## 1. 组件层次与模块清单 (Component Tree)

```text
StudyOSApp (App Entry)
├── LibraryView (首页资料库)
│   ├── LibraryHeaderBar (标题、全局搜索框、网格/列表切换、导入入口)
│   ├── RecentReadingSection (横向滑动最近阅读卡片: 真实封面缩略图、进度条、元数据)
│   ├── DocumentGridSection / DocumentListSection (文档分组与列表项)
│   │   └── DocumentCardItem (封面、标题、格式标签、阅读位置进度、索引状态指示点)
│   ├── DocumentPickerPresenter (系统 UIDocumentPicker 桥接)
│   ├── PasswordPromptSheet (加密 PDF 密码输入模态框)
│   └── DocumentDeletionModal (两路笔记策略的删除确认弹窗: 强制二选一 notePolicy(keep/delete)、展示真实 impact 预览与 cleanupPending 清理进度)
│
├── ReaderContainerView (主阅读工作区容器)
│   ├── ReaderTopNavigationBar (返回按钮、文档标题、TOC/书签/搜索触发器、工具态控制器、全文学习入口、AI助学触发器)
│   │   ├── OutlinePopover (PDF 原生层级大纲)
│   │   ├── BookmarksPopover (个人书签列表)
│   │   ├── DocumentSearchOverlay (关键词高亮与匹配项导航)
│   │   └── ToolModeSegmentedBar (纯阅读 / 文本选择 / 批注模式显式切换)
│   │
│   ├── ReaderWorkspaceSplitView (自适应分栏核心容器: ≥900pt左右分栏且受侧栏[320pt,400pt]与阅读区≥540pt约束，<900pt底部抽屉)
│   │   ├── PDFCanvasViewport (左侧或主视口画布，受 540pt 最小阅读舒适门槛保护)
│   │   │   ├── PDFKitPlatformBridge (PDFView 原生 UIViewRepresentable 桥接)
│   │   │   ├── PencilKitOverlayCanvas (按 PageKey 独立绑定的 PKCanvasView 覆盖层，排队前固化快照)
│   │   │   ├── SelectionCalloutMenu (选区上方弹出式快捷操作菜单)
│   │   │   └── SourceAnchorFocusRing (来源回跳时的发光边框动画高亮层，支持 Reduce Motion 静态降级)
│   │   │
│   │   └── AISidebarView (右侧分栏面板或竖屏底部自适应抽屉 Sheet)
│   │       ├── AIScopeHeaderBar (读者主标题呈现阅读范围名称，诊断抽屉显示 requestID/attemptID 与 scopeSnapshot)
│   │       ├── ContextPrivacyHeader (动态聚合反显真实 ContextManifest: outboundItems 清单、四项 Inclusion、Token 估算)
│   │       ├── SixSectionStudyFeedView (六段式 AI 助学核心卡片流)
│   │       │   ├── SectionOverviewCard (① 这一部分在讲什么)
│   │       │   ├── SectionFocusPointsCard (② 阅读重点清单)
│   │       │   ├── SectionPrerequisitesCard (③ 前置知识药丸及就地解释 Popover，不适用项显示说明)
│   │       │   ├── SectionConceptsCard (④ 核心概念卡片组)
│   │       │   ├── SectionMisconceptionsCard (⑤ 容易理解错的地方 - 警示卡片 ⚠️)
│   │       │   └── SectionReadingQuestionsCard (⑥ 阅读思考问题 - 严格遵循 PRD 默认无答案)
│   │       ├── AskAIConversationView (自由问答对话流)
│   │       │   ├── AskAIMessageRow (用户提问 & AI 回答气泡)
│   │       │   ├── CitationBadgeGroup (来源标记胶囊: 经 resolveSource 校验且通过会话核对可交互，未校验来源置灰禁用，已删文档标明不可导航)
│   │       │   └── ModeTogglePicker (文档模式 vs 扩展模式)
│   │       └── AskAIInputBar (输入框、发送按钮、终止生成按钮、重试按钮)
│   │
│   ├── ReaderBottomProgressBar (底栏 1-based 物理页码指示、快速翻页滑块 Scrubber、书签切换按钮)
│   └── PKToolPickerFloatingAdapter (Apple Pencil 原生悬浮工具箱桥接)
│
├── FullDocumentStudyView (全文学习视图 - P0 独立全屏/大模态)
│   ├── StudyViewHeader (标题、预计阅读时间 Badge [支持 available/unavailable]、分析覆盖率进度、导出到笔记按钮)
│   ├── BatchedTaskProgressBar (大文档分批分析进度条: 正在分析 X/Y 页，支持取消与重试)
│   ├── PartialScopeNoticeBanner (当用户主动传递 pageRange 缩窄范围时，显式标明「部分资料学习视图」，不冒充全文完成)
│   ├── DocumentStructureTreeCard (资料大纲树状图)
│   ├── CoreConceptCloudCard (全篇核心概念及频次)
│   ├── FocusSectionRankCard (五星级重要度重点列表，点击跳转严格复用 ReaderAdapter.navigateTo 会话校验路径)
│   ├── DifficultiesAnalysisCard (理解难点与认知阻碍分析)
│   └── KnowledgeGraphTreeCard (层次化知识关系拓扑树)
│
├── NotesDrawerSheet (AI 笔记库抽屉)
│   └── NoteCardItem (严格对齐契约 Note: editableText、imageRefs、sourceAnchors、createdAt、updatedAt，支持原文档删除后独立保留展示)
│
└── ProviderSettingsSheet (AI 服务配置与隐私透明弹窗)
    ├── ProviderSelectionPicker (OpenAI-compatible 核心基线端点)
    ├── EndpointCredentialsGroup (BaseURL、Keychain 安全凭据 API Key、Model Name)
    ├── CapabilitiesIndicatorBadge (流式/向量/Vision/上下文窗口支持度动态呈现)
    └── FirstTimeConsentModal (首次联网/首次向量索引/全文分批外发授权确认弹窗: 绑定 Manifest 摘要与 providerSnapshot)
```

---

## 2. 全局状态机与异常矩阵 (Failure & Edge Cases Handling)

为满足系统韧性及 `docs/qa/UI-INTEGRATION-CASES.md` 的严格检验，核心视图按以下状态机规约处理异常：

| 业务场景 / 状态码 (Code) | 触发条件 | UI 呈现形式与反馈规范 | 用户交互与恢复路径 | 关联验收 |
|---|---|---|---|---|
| **1. 导入与解析中 (Importing / Extracting)** | 用户选择大文件，正在拷贝与提取文本 | 列表项显示 `ProgressView`，显示 `正在导入并验证文档... (45%)`；阅读器打开时优先呈现 PDF 首屏，后台异步解析 | 用户可正常浏览其他文档；支持点击取消导入；损坏或无法读取不进入异常白屏 | R01, UI-T09 |
| **2. 需要密码 (passwordRequired / invalidPassword)** | PDF 被加密锁定 | 弹出 `PasswordPromptSheet`；输错密码震动反馈并提示 `密码错误，请重新输入` | 提供密码输入框与取消按钮；密码仅在内存验证，禁止明文入日志；取消则安全退回资料库 | R01 |
| **3. 非法 PDF / 损坏 (invalidPDF / permissionDenied)** | 文件格式非标准、CRC 损坏或无文件沙盒读取权限 | 资料库卡片标记红色警示图标：`无法打开该文档 (文件损坏或权限受限)` | 提示移除该文件或重新导入；禁止生成空壳假文档 | R01 |
| **4. 空内容状态 (Empty States)** | 资料库无文档、搜索无结果、暂无书签/笔记 | 学术极简风格占位：<br/>- 资料库为空：`资料库暂无文档，点击右上角导入`<br/>- 搜索无结果：`未找到与 “xxx” 匹配的内容`<br/>- 无书签：`点击底栏书签图标即可收藏当前页` | 突出主要操作按钮（如 `+ 导入资料`、`清除关键词`） | R16 |
| **5. 扫描件 / 无文字页 (textUnavailable / unsupportedCapability)** | 页面为纯位图扫描件，无内嵌矢量文本 | 阅读器顶部显示轻量提示条：`当前页为扫描图像，无法直接划选文本`。若 Provider 支持 Vision 则提供全页图像助学选项；若 Provider 不支持 Vision 则明确标明 `当前 Provider 不支持图像解析 (unsupportedCapability)，选区助学受限` | 不阻碍用户正常翻页与 Apple Pencil 手绘批注；用户可配置支持 Vision 的 Provider 或等待本地 OCR | R04, UI-T08 |
| **6. 索引建立中 / 局部检索 (indexPartial / lexicalOnly)** | 大文档后台仍在构建向量索引 | AI 侧栏上方微型胶囊指示：`正在建立深度知识索引 (65%)...`；问答界面标明 `当前回答基于局部即时检索`；隐私面板动态展示当前外发项 | 允许用户正常提问，系统采用快速词法段落检索降级响应；不虚构宣称向量已完成 | R18, UI-T08 |
| **7. 选区解除 / 跨页切换 (No Selection / Page Switched)** | 用户发起解释请求后，在流式生成中点击空白处解除选区或翻页 | 选区浮动菜单立即淡出；**在途流式请求保留原 `scopeSnapshot`（如 `选区: P12 第3段`）完整完成输出**；界面绝不将旧回答篡改标记为新翻到的页面 | 翻页或选区变动仅作用于下一次新发起的请求；状态机严防数据错位 | R05, UI-T06 |
| **8. 无目录结构 / 无法分章 (Missing Chapter Outline)** | PDF 未内嵌目录且算法无法可靠推断章节 | 点击「当前章节」助学时，侧栏展示提示：`该文档暂无明确章节大纲`，并自动提供降级选项：`[以当前前后 5 页作为分析范围]` 或 `[自定义分析页码范围]` | 用户无需繁琐手工建目录，一键选定邻近范围即可继续获得高质量章节助学 | R07, R12 |
| **9.1 网络离线 (offline)** | 处于飞行模式或 Wi-Fi 断开 | AI 侧栏输入框上方显示离线条：`网络未连接，AI 助学暂不可用`；本地 PDF 阅读、翻页、缩放、书签、PencilKit 手绘批注与本地笔记在无网环境下正常可用 | 提供 `[检查网络并重试]`；用户输入的问题内容原地保留，不被清空 | R17, UI-T08, UI-T09 |
| **9.2 响应超时 (timeout)** | API 请求超过候选超时阈值（候选：30s）无响应 | 回答卡片转为超时态：`AI 响应超时 (>30s)，请检查网络或 Provider 状态` | 提供 `[🔄 重新尝试]` 按钮；重新发起请求使用全新 `attemptID` | R08, UI-T08 |
| **9.3 速率受限 (rateLimited / 429)** | 触发 Provider 频控或限流 | 卡片提示：`触发服务调用频控 (429)，请等待 X 秒后重试`，显示动态倒计时 | 倒计时期间禁用重试；倒计时结束后重试按钮恢复可用；严禁自动无限重试 | R14, UI-T08 |
| **9.4 Provider 未配置 / 鉴权失败 (providerNotConfigured / authFailed)** | 首次使用未配 Key，或 API Key 失效 / 401 | 侧栏弹出引导横幅：`尚未配置有效的 AI Provider / API Key 验证失败` | 提供 `[打开配置面板]` 直达按钮，用户输入并保存 Keychain 后即刻可恢复请求 | R14, UI-T08 |
| **10.1 用户主动终止 (cancelled)** | 用户在流式生成中主动点击「⏹️ 终止生成」 | 客户端向服务发送 `cancelAI(requestID, attemptID)`；确认后进入 `cancelled` 终态，打字机停滞，末尾标注 `已终止生成 (部分结果)` | 用户可点击 `[继续生成]` 或 `[重新提问]`（均分派全新 `attemptID` 并复核 Manifest）；**未完成结果中的引用禁止呈现为可点击来源** | R08, UI-T06 |
| **10.2 服务执行失败 (failed)** | 因服务端异常、网络中断或 Schema 校验失败中断 | 客户端进入 `failed` 终态，保留具体错误描述及已生成的不完整内容；**前端严禁自动向服务发送 cancelAI** | 服务端串行裁决互斥终态，若尝试已终态则返回 `alreadyTerminal`，不覆写原结果；迟到事件一概丢弃；用户可点击重试（新 attemptID） | R08, UI-T06 |
| **11. 证据不足与非法输出 (insufficientEvidence / invalidModelOutput / invalidCitation)** | - 文档无相关依据<br/>- 模型输出格式不合规<br/>- 模型伪造不存在的引用锚点 | - 证据不足：灰色卡片诚恳提示 `当前文档未提及该内容`，提供 `[切换至扩展模式]` 引导<br/>- 格式非法：提示 `模型输出格式异常，请重试`<br/>- 伪造引用：引用胶囊置灰并标记 `[未验证来源]`，禁用点击交互 | 文档模式下杜绝胡乱编造；保证所有可点击来源必须经过验证 | R08, R09, UI-T06, UI-T07 |
| **12. 引用解析与跨会话核对 (resolveSource / staleReference / ignoredStaleSession)** | 点击引用胶囊，或在引用解析 await 期间切换了文档或关闭了阅读器 | `resolveSource` 返回后在主执行域校验：<br/>- 会话已换/关闭：返回 `ignoredStaleSession`，**绝不跳转、绝不高亮、静默丢弃**<br/>- `staleReference`：**保持当前视口绝对不跳**，Toast 提示 `引用对应旧版文档（版本已过期），无法定位`<br/>- `unavailable` 或 `documentDeleted`：原地提示 `引用目标已失效或文档已删除`<br/>- 有效：平滑跳至目标页，PDF 页面坐标定位并触发发光动画 | 杜绝跨文档/跨会话迟到导航与盲目乱跳；保存冲突（`conflict`）独立处理为数据重载，不与来源跳转混淆 | R09, UI-T04, UI-T07 |
| **13. 完全离线阅读 (Offline Reading)** | 飞行模式或无网环境下研读 | 本地 PDF 查看、双指缩放、翻页、目录跳转、PencilKit 手绘批注、高亮下划线、书签、本地笔记完全保留并在本地可用；AI 功能标明离线不可用 | 践行 PRD“文档是主体”理念，无网环境绝不阻碍用户自主学习 | R02, R03, R17, UI-T09 |
| **14. 异步持久化生命周期与会话隔离 (InkSaveSnapshot / Receipt / conflict)** | 手写抬笔、快速连续翻页、切后台或会话切换 | - 提交不可变 `InkSaveSnapshot`（含 PageKey、readerSessionID、expectedRevision）<br/>- 收到 `InkSaveReceipt` 推进 `persistedRevision` 并清除对应快照 dirty；较新笔画保持 dirty 排队<br/>- 切文档/关会话后，旧结果仅更新底层账本，**绝不反写新画布**<br/>- `dirty` 仅为指示状态，不作为笔划恢复数据；已删文档提交拒绝写盘并告警 | 彻底根除跨页脏写与版本冲突；保存失败提示 `storageFull / saveFailed`，提供重试与冲突重载 | R03, R17, UI-T05 |
| **15. 全文学习视图分批任务与真实覆盖率 (Batched Study View & Budget)** | 大文档（如 24、25、26 或 200+ 页）生成学习视图 | **不设 25 页硬上限，在系统资源与 Provider 能力限制内分批处理**。显式传递 `scope(.document 或 .pageRange)`；头部展示真实 `coverage`（如 `已分析 180/200 页`）与遗漏清单；用户主动指定局部时标明 `部分资料学习视图 (P1–25)`，不冒充全文完成 | 允许用户中途取消或重试；支持 `readingEstimate` 的 `available(minutes, basis, coverage)` 和 `unavailable(reason)` 双态呈现 | R10, UI-T10 |
| **16. 文档删除与两路笔记策略 (previewDeleteDocument / notePolicy / cleanupPending)** | 用户在资料库删除文档 | 1. 调 `previewDeleteDocument` 弹出预览弹窗，展示原件、索引、批注、笔迹与关联笔记数量；<br/>2. **强制二选一选择 `notePolicy`**：<br/>- `keep`：保留笔记文字/图片/时间，解除外键归属，引用标 `documentDeleted` 不可跳；<br/>- `delete`：彻底清理关联笔记；<br/>3. 提交 `deleteDocument`；若版本变更提示 `conflict` 重新预览；<br/>4. 若物理清理未完成，界面展示 `正在清理关联数据 (cleanupPending)`，不提前宣称完成 | 彻底保障用户学术笔记资产安全，防止误删不可逆丢失 | R16, R17, UI-T11 |

---

## 3. 核心交互组件行为规范与动效规则

### 3.1 70/30 布局切换动效 (Split Animation)
- **触发与过渡**：点击顶部导航栏 `✨ AI 助学`；
- **动效参数**：采用 SwiftUI 标准弹簧阻尼 `.spring(response: 0.35, dampingFraction: 0.82)`；
- **视口稳定保障**：在 PDFView 宽度缩放过渡期间，底层通过计算当前视口中心点在目标页面中的相对比例，动态微调 `contentOffset`，保证用户当前眼光聚焦的文字行不会移出屏幕；
- **Reduce Motion 适配**：若系统开启减少动态效果，直接以 0.15s 透明度淡入完成布局切换，不执行水平横移拉伸。

### 3.2 来源定位发光动画 (Source Focus Animation)
- **触发与执行**：用户点击经 `resolveSource` 校验且通过当前会话验证的有效引用胶囊；
- **动效规范**：
  - PDFView 滚动至目标页面并居中显示目标矩形区域（PDF 页面空间坐标）；
  - `SourceAnchorFocusRing` 绘制外围高亮边框（屏幕空间坐标转换后绘制，主题色 `#2563EB` 或暗色模式对应高亮色）；
  - **常规模式**：执行 2 次呼吸脉冲缩放（透明度在 0.2 至 0.8 间往返，单次周期 0.6 秒，共 1.2 秒），随后平滑衰减为静态细线框；
  - **Reduce Motion 模式**：禁用缩放脉冲，以静态半透明高亮矩形直接常驻 1.5 秒后淡出；
  - 高亮层设置 `isUserInteractionEnabled = false`，不阻断用户的即时手写或触控滚动。
