# M0-UI 独立设计审阅

后续复核：`M0-UI-RECHECK-002.md` 针对 v0.2-revised 逐项记录关闭与剩余条件。下文保留首轮历史，不代表当前所有条目仍未修订。

2026-09-07T13:21:15+08:00 · Codex2 · 输入 M0-UI-ui-001、三份 UI 方案、PRD、PLAN、CONTRACT 0.1-draft。

结论：核心界面已覆盖 R01–R10，但存在阻止契约冻结的语义冲突。建议 **CHANGES_REQUESTED（设计）**；不是产品 FAIL。全部产品测试 **NOT_RUN**。以下仅由 PM 路由 UI 修订，QA 不改 UI 文件。

| REVIEW | 证据位置（docs/ui/） | 缺口及必要修订 | 关联 |
|---|---|---|---|
| UI-01 | COMPONENTS-AND-STATES.md:91；ARCHITECTURE-AND-FLOWS.md §3.6 | 旧 revision 自动跳旧页号违反契约。先 resolveSource 验证 documentID/revision；staleReference/unavailable 保持当前位置并提示，不能复用旧页号。只有有效同版本页级锚点可页级降级。conflict 属写冲突，应另行重新加载，不能合并为来源跳页。 | R09 |
| UI-02 | COMPONENTS-AND-STATES.md:94；ARCHITECTURE-AND-FLOWS.md:180 | 默认只前 25 页不能替代全文 P0。提供分批分析/进度/取消/重试和真实覆盖清单；用户主动选部分时明确“部分资料”，不得全文完成。24/25/26 与 200+ 页均进入验收。 | R10 |
| UI-03 | ARCHITECTURE-AND-FLOWS.md:228 | 固定“未发送整本 PDF/手写图片”不能代表实际 ContextManifest；全文任务可能发送全文文本，图像降级也可能外发页面。按实际范围、内容类型、批注、Provider 与裁剪明细呈现；首个联网与 embedding 外发亦适用。 | R17 |
| UI-04 | READER-ADAPTER-SPEC.md:105–125 | 导航伪代码仅检查上界，缺 documentID/revision、负页验证与 resolveSource；页面矩形转 screenRect 后又用于带 page 的导航存在空间混用风险。冻结前改为明确接收 PDF 页面空间的导航契约，屏幕坐标仅用于 UI 覆盖层。实际 Apple API 调用需 Mac 编译/旋转裁切用例验证。 | R09 |
| UI-05 | READER-ADAPTER-SPEC.md:91–93 | 阻塞/同步后台刷盘与架构异步策略冲突，无法把“系统挂起前必完成”当保证。补 pageKey+document revision、drawingRevision/expectedRevision、覆盖层复用隔离、乱序拒绝、失败重试及已保存/未保存状态。2 秒防抖应标候选，记录实际防丢窗口；后台时间不足保留旧有效版本，不宣称未提交笔迹已保存。 | R03,R17 |
| UI-06 | ARCHITECTURE-AND-FLOWS.md:146；COMPONENTS-AND-STATES.md:89 | 选区消失后切页范围不能改写在途 scopeSnapshot；完整定义 started/textDelta/completed/failed/cancelled、requestID/attemptID、终态后旧事件拒绝。未完成/未校验引用不可点成有效来源。“继续生成”须映射新 attempt 或明确不支持续传。补 authFailed/providerNotConfigured/unsupportedCapability/invalidModelOutput/invalidCitation 的状态。 | R05–R08 |
| UI-07 | ARCHITECTURE-AND-FLOWS.md §3.2–3.4 | 默认 Pencil 触笔绘写与 Pencil 长按选文冲突。补工具态表：手指滚动/选文、Pencil 绘写/选文、切换及选区清理；硬件双击/挤压按能力可选，无此能力设备仍可工具栏操作。 | R03,R04 |
| UI-08 | ARCHITECTURE-AND-FLOWS.md:8,32–34；COMPONENTS-AND-STATES.md:7 | iPadOS 17+ 尚未冻结，应标候选；70/30 与固定 360–420pt 在900pt宽不一致，须明确优先规则。分屏抽屉、键盘与手写覆盖区域需真机实测，不使用“100%正常/绝对不位移”作证据。最低系统、布局边界、性能门槛由 PM/UI/后端收敛。 | R02,R03 |

非阻止项：多 Provider 原生协议、Notes 富文本/手写、标签搜索、导出、概念频次等超出当前最小契约，先标候选或明确对应字段/操作，避免 UI 承诺全部首版实现。六段结构应允许不适用项说明理由，不为填卡片编造前置知识或易错点。

文档审阅方法：逐项对照原始需求与接口语义，`rg` 定位上述原文；无产品代码运行。Apple 导航文档页面可打开但 Markdown 正文抓取失败，因此本轮不宣称已验证 SDK 签名。后续以 Apple SDK 与 Mac 构建为准。
