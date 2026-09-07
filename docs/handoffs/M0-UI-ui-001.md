# M0-UI 原生 UI 方案交接

时间：2026-09-07T13:17:30+08:00。发送：外部 UI 总监与前端负责人 Claude2；接收：项目经理 Claude1、项目测试 Codex2、项目后端 Codex1、主协调者。

基线：`docs/product/PRD-v0.1-source.md`、`docs/project/PLAN.md`；契约：`docs/backend/CONTRACT-v0.1-draft.md` (0.1-draft)。

变更路径：
- `docs/ui/ARCHITECTURE-AND-FLOWS.md`
- `docs/ui/COMPONENTS-AND-STATES.md`
- `docs/ui/READER-ADAPTER-SPEC.md`
- `docs/logs/ui.md`
- `docs/handoffs/M0-UI-ui-001.md`

完成事项：
1. **iPad 原生布局与信息架构**：确立“文档是主体 → 用户主动阅读 → AI 按需介入”最高原则。iPad 横屏默认 PDF 100% 全屏，AI 打开呈 70/30 左右分栏；iPad 竖屏与分屏采用底部自适应抽屉（Sheet / Inspector），确保窄空间下 PDF 舒适阅读与手写不被过度压缩。
2. **核心业务流程覆盖**：
   - 资料库 (Library)：最近阅读卡片（阅读进度 %、缩略图、快速恢复）、文件夹、收藏、导入及加密 PDF 流程；
   - 阅读器 (Reader View)：沉浸工具栏、底栏物理页码（1-based 物理显示）与快速选页滑块、目录与书签；
   - Apple Pencil 批注：原生 `PKToolPicker` 桥接、笔迹与 PDF 几何保持、Apple Pencil 轻点/双击快捷切换；
   - 选区上下文菜单：高亮、下划线、复制、✨ 助学解释、加入笔记；
   - AI 助学侧栏：三级范围切换（选中内容、当前页、当前章节）、严格 PRD 六段式结构（① 这一部分在讲什么、② 阅读重点、③ 可点击前置知识 Popover、④ 核心概念、⑤ 容易理解错的地方 ⚠️、⑥ 思考题 [默认无答案]）、Ask AI 对话流（文档模式 vs 扩展模式）；
   - 来源定位 (Grounding Locator)：可点击引用胶囊（如 `P12 第3段`）、页面平滑滚动、目标矩形呼吸发光高亮（Pulse Ring）、旧版失效（staleReference）优雅降级；
   - 全文学习视图 (Full Document Study View - P0)：独立全屏/大模态入口、预计阅读时间（含文本不足降级提示）、资料结构、核心概念云、重点星级排行榜、理解难点、层次化知识关系拓扑树；
   - AI Notes：一键沉淀为普通可编辑卡片，保留文档引用与时间戳；
   - Provider 与隐私面板：BYOK 设置（密钥存 Keychain）及发送内容透明清单（明确未发送整篇 PDF 与手绘图片）。
3. **组件树与异常状态机**：
   - 完整组件层级树结构（SwiftUI 视图体系与原生 UIKit/PDFKit 封装）；
   - 15 种异常与边界状态全覆盖：加载中、需密码、损坏 PDF、空内容、扫描件无文字、索引建立中/部分索引、无选区/选区失效、无章节大纲降级、AI 超时/限流/断网、AI 用户主动终止（保留部分结果）、证据不足提示、引用失效降级、完全离线阅读（100% 保障核心阅读与批注）、存储满/保存失败、学习视图页数超限。
4. **ReaderAdapter 桥接契约**：
   - 明确内部 `0-based` (`pageIndex0`) 与 UI 物理页码 `pageIndex0 + 1` 转换规约；
   - 严格遵循 Apple 原生转换 API（`pdfView.convert`、`page.bounds(for: .cropBox)`、`page.transform`），明确禁止简单 Y 翻转推算；
   - Per-Page 单页挂载 `PKCanvasView` 覆盖层生命周期，规定抬笔防抖、换页、切后台（`sceneDidEnterBackground`）与关闭文档的严格刷盘（`flushInk`）时机；
   - 定义 `ReaderAdapterProtocol` 跨层通信接口与视觉聚焦动画规范。

验证与检查：
- 文件检查：`docs/ui/` 下三份技术规范已生成，内容完整详实，无截断；
- PRD 映射核对：对照 PRD-v0.1-source.md 与 PLAN.md，全部 P0 功能（R01–R10）在 UI 方案中 100% 完整覆盖，无任何功能缩减；
- 真实构建/真机验证状态：当前为 Windows 操作系统，无 macOS / Xcode 构建链，故原生编译、模拟器运行与 iPad 真机手写实测均为 **NOT_RUN**。设计完成、模拟演示、Mac 编译、真机通过界限分明，不混淆记录。

待收敛与下一步：
- 待 PM (Claude1) 审阅 UI 方案，待 QA (Codex2) 依据 UI 规范完善验收矩阵与联调方案；
- 待 PM 在 M1 明确工程单一写者与客户端源码目录后，启动客户端最小切片代码开发；
- 释放本轮 `docs/ui/**` 编辑权，所有权归 Claude2，后续修订走统一反馈流程。
