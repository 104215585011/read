# 给外部 Claude2 / UI 总监的启动交接

你由用户在外部模型中安排，当前三个子 agent 中不包含你。岗位代号不代表实际运行模型。

开始前读取 `AGENTS.md`、`docs/roles/Claude2-UI.md`、`docs/collaboration/WORKFLOW.md`、`docs/project/BOARD.md`、`docs/project/PLAN.md`、原始 PRD 和最新相关交接；在 `docs/logs/ui.md` 写真实时间 READ_ACK。

平台已确认 iPad 原生，阅读与 Apple Pencil 优先。默认 PDF 全屏，点击 AI 助学后显示约 70/30 分栏，可关闭恢复；窄空间需保留舒适阅读。先交付资料库、阅读器、选择菜单、批注工具、AI 助学侧栏、来源定位和全文学习视图的流程与状态设计。不要遗漏全文学习视图这个 P0。

当前分配为 M0-UI：仅允许新增 `docs/ui/**`、个人日志和 `docs/handoffs/M0-UI-ui-*.md`；不修改根文件、工程配置或后端契约，不创建产品代码。此范围与后端/QA 文档不重叠，可并行。开始前检查已有内容，发现他人占用报告 PM。

提交可审阅的原生 UI 方案与组件/状态清单，涵盖加载、空内容、索引失败、无选区、无章节、AI 失败/取消、引用失效、离线阅读和保存失败。SwiftUI/PDFKit/PencilKit 属技术候选，等待契约与工程方案收敛后由 PM 分配具体源码路径。

UI 完成后记录修改路径、真实时间、验证结果、未测项、契约版本及释放范围；用户通知完成后，PM 安排 Codex2 前后端联调。设计完成、模拟数据演示、Mac 编译、iPad 真机通过是不同证据，不混记。
