# M0-UI 一致性审阅与 M1 准入

当前复核对象：`docs/handoffs/M0-UI-ui-002.md`、`docs/ui/` 三份 `v0.2-revised` 规范；依据原始 PRD、PLAN、后端架构与 `0.1-draft` 契约。下方保留 001 的原始审阅要求，最新裁决见“002 逐项复核”。本轮是设计/契约 REVIEW，产品编译、运行、联调、真实 Provider 与 Pencil 测试均为 NOT_RUN。

## 覆盖结论

R01–R10 都有界面入口或流程，默认阅读全屏、按需 AI、三种即时范围、六段助学、文档/扩展模式、独立全文视图方向一致。内部 0-based 页号、PDF 页面 points 和逐页笔迹的总体约定一致。但入口齐全不等于需求语义一致，以下冲突需修订后才能冻结交付。

| 修订 ID | 影响/证据 | 必须修订与验收条件 | 归属 |
|---|---|---|---|
| UIREV-01 | R09；ARCHITECTURE-AND-FLOWS §3.6、COMPONENTS 状态12 | 旧 revision 不能自动跳旧页号；先调用 resolveSource，只有匹配文档/版本的有效目标才能导航。区分页级有效引用与 staleReference；conflict 是写入冲突，须重新加载/解决而非导航。三个 UI 文档一致 | UI；BE复核 |
| UIREV-02 | R10；ARCHITECTURE §3.7、COMPONENTS 状态15 | `<25页` 只是短文示例。大文档保留分批全文分析、覆盖/遗漏、取消/重试与汇总；用户主动选局部是另一种范围，不能默认前25页然后标全文完成 | UI |
| UIREV-03 | R03；READER-ADAPTER §3.1–3.2、§5 | 删除换页阻塞及后台“必须同步完成”的实现承诺。说明持续增量异步保存、dirty/saving/saved/failed/conflict 状态、预期 revision/保存确认、覆盖层复用前快照归属及乱序防护；接口保留结构化失败而非仅 Bool。离页/后台失败保留旧有效版本和可恢复状态，不承诺系统挂起前必写完 | UI；BE复核 |
| UIREV-04 | R04/R09；READER-ADAPTER §4.1、§5 | 导航校验 documentID、revision、非负且有效页号；避免绕过已验证 navigationTarget。明确 PDF 页坐标与视口坐标用于导航/绘制的边界，示例中的 screenRect 传 go(to:on:) 需按 Apple API 校正并记录依据。明确阅读/选择/书写工具态与 Pencil/手指切换，避免默认手写同时长按选择的竞争 | UI |
| UIREV-05 | R05–R08；COMPONENTS 状态5–11 | 显示请求 scopeSnapshot 与 requestID/attemptID；选区消失/翻页只改下一请求，不能将旧回答标成新范围。补 completed+schema/引用校验才完成、无效输出/引用、未配置/鉴权/不支持能力的呈现；部分结果不得作为已验证引用。重试/继续生成明确新 attempt，限流/超时分开，扫描件入口按 OCR/vision 实际能力显示 | UI；BE复核 |
| UIREV-06 | R17；ARCHITECTURE §3.9、COMPONENTS 状态5/6 | 发送面板从真实 ContextManifest 显示，不恒定承诺“未发整本PDF/笔迹图片”。区分原始文件与全文文本、扫描图、embedding 外发；首次联网/索引外发先呈现实际 Provider 和范围，未确认不发送。删除文档应显示关联数据/笔记影响 | UI；BE确认现有契约能承载 |
| UIREV-07 | PLAN 待决策；两份UI标题及新增功能 | iPadOS17+ 改为候选，最低版本以工程验证和 PM 冻结为准；Pencil Pro 挤压、多厂商 Provider、标签、富文本/笔记涂鸦/导出等新增承诺标为待排期能力，不能隐含扩大 M1。Notes 保留 editableText 与图片/引用基线，不能强制新增富文本存储格式 | UI；PM冻结范围 |

以上是 M0-UI 文档修订范围；不要求现在实现产品或拿到真实测试结果。涉及后端接口新增时先提变更，由 Codex1 串行修订契约，再由 UI 对齐，不各自创建同名类型。

## 可延后到对应实现阶段

- M1 原型确认最低系统、PDF 覆盖层挂载 API、Pencil 能力检测、保存窗口、缩放/旋转/裁切往返和手势；无条件“100%正常”“绝对不位移”改为可测试目标，并同时保留失败状态。
- 70/30 与固定360–420pt在900pt窗口存在取舍，实施前统一以可用窗口宽度和阅读最小宽度为准；动画最终持续时间、配色与装饰性图形不阻塞文档修订。添加减少动态效果和文字放大检查。
- M2 前冻结首个 Provider、超时/限流参数、OCR边界、搜索取消/部分索引状态与 AI 真实评估门槛；不得推迟最小 P0 Provider 通路到 AI 之后。
- M3 前落实 Notes 图片与按章节组织、全文任务数据结构、赞踩/继续阅读指标口径；不因为未在 UI 详写而从 V0.1 删除。

## 准入与交接

当前 M0-UI 为 CHANGES_REQUESTED；M1-SETUP 保持 TODO，本轮不授权源码写入。UI 按 UIREV-01–07 修订三份规范并提交唯一新交接；QA 对照修订逐项复核，PM 再判文档关闭。产品联调需后续可构建源码和用户 Mac/iPad 的实际证据。

UI 继续独占 `docs/ui/**` 与个人日志；BE独占后端文档，QA独占验收/审阅文档，PM独占本报告及看板。M1 开工前还需明确工程配置唯一写者、双方源码目录与可构建最小切片。

## 002 逐项复核

PM 已重读实际修订文件，不以交接中的“完全闭环”自述作为验收；已接收 QA 独立逐项复核 `docs/qa/M0-UI-RECHECK-002.md`，双方结论一致。R01–R10 仍保留；章节缺失可选择页范围、六段输出不造内容、全文分批和来源失效不跳等主要问题已有修订。当前剩余四组，继续 CHANGES_REQUESTED。

| ID | 002 设计复核 | 证据与剩余关闭条件 |
|---|---|---|
| UIREV-01 | CLOSED（文档） | ARCHITECTURE §3.6、COMPONENTS 状态12 与 Adapter §4.1 已区分有效页级、staleReference/unavailable 和非法引用；旧版不自动跳。异步会话执行风险归 UIREV-04，避免重复列项 |
| UIREV-02 | CLOSED（文档） | ARCHITECTURE §3.7、COMPONENTS 状态15 已保留分批全文、真实 coverage、部分标识与 readingEstimate 双态。“任意长度”随下一修订改为资源/Provider能力内分批、不设25页硬上限，不代表无限资源保证 |
| UIREV-03 | OPEN | Adapter §3 已补 pageKey 和异步状态，但 §5 的 flushInk(pageIndex0, expectedRevision) 与 flushAllDirtyInks 返回仅以页号为键；应明确 immutable 文档/版本会话绑定或显式 pageKey、drawingRevision，跨文档异步结果只写原快照。不得靠当前 UI 页号补齐；dirty 标记不是未保存笔画的恢复副本 |
| UIREV-04 | OPEN | Adapter §4.1 在 await resolveSource 前捕获 document，返回后只校验页号；应在主执行域对当前 reader 会话/文档ID/revision与已验证 target 再核对，文档已切换/关闭则丢弃迟到导航。坐标方向已改正确语义，但 SDK 签名/运行仍 NOT_RUN；三态工具设计已闭合 |
| UIREV-05 | OPEN | 主要快照/完成校验/错误状态已补；COMPONENTS 状态10仍把 failed 与 cancelled 合并成“已终止”并调用 cancelAI。拆分用户取消与服务端失败，失败保留真实错误且不自动发取消；两者重试才新建 attempt，终态后旧事件忽略 |
| UIREV-06 | OPEN | 动态 Manifest 方向正确，但契约未定义 UI 所需外发类型/图片/文本数量的来源映射；先由 BE 补齐最小字段或明确由已确认请求清单派生，不让 UI 猜测。ARCHITECTURE §3.1 固定删除全部笔记，需与后端“保留/删除显式参数”一致：提供明确策略并将选择传入删除契约，显示影响 |
| UIREV-07 | CLOSED（文档，附清理） | 最低系统标候选、Provider缩为兼容端点、Notes使用editableText/图片、硬件增强条件化，动态字体/减少动效已补。COMPONENTS 状态9.1仍有“100%正常”残句，下轮移除。540pt为分栏优先目标，窄窗口全宽小于540pt时不得形成硬性不可用条件 |

### 修订路由与 M1 准入

1. UI 可独立修 UIREV-03/04/05 及上述文案，继续独占三份 UI 规范；只修设计，不要求本轮运行 SDK。
2. UIREV-06 先由 Codex1 提交最小契约补充（外发清单字段来源、删除笔记策略），其唯一可写范围为 `docs/backend/**`、backend 日志和独立交接；PM 对齐后再由 UI 引用同版本，不能两端并行改同一契约。
3. QA 复核以上四组后，PM 才能将 M0-UI DONE。当前 M0 文档阶段未完全关闭，M1-SETUP 保持 TODO。
4. M1 候选目录分工：Codex1 管核心服务/持久化与唯一工程配置，Claude2 管 App UI/ReaderAdapter，QA 管测试样本与测试目录。此处仅建议，不授予任何源码路径；实际目录名、Xcode工程/包结构、最低系统及唯一配置写者必须在 M1 开工条目中明确。
5. M1 出口必须含用户 Mac 构建、模拟器基本流程及 iPad/Pencil 坐标/手势/持久化实际证据。文档关闭也不能把产品测试 NOT_RUN 改为 PASS。

QA 补充亦纳入上述关闭条件：已提交的旧保存确认仍需更新正确 savedRevision，不能把“拒绝旧快照”误写为丢弃真实提交确认；全文重点导航复用同一校验路径；继续生成是新尝试而非流续传。契约同步说明 buildStudyView 局部 scope、Note 创建时间来源、NavigationTarget/PageKey/错误映射、buildIndex/buildStudyView 的 Manifest 确认绑定；Provider或发送清单变更后旧确认不代表新内容。30秒超时标候选。这些属于已有交互的字段闭合，不增加新的产品功能。

## BE-REV2 接收与 v0.3 路由

2026-09-07T15:32:39.5785319+08:00：PM 读取完整 0.1-draft / M0-BE-REV2 契约，接收 QA 的 docs/qa/M0-BE-REV2-RECHECK.md 与交接 M0-BE-REV2-qa-001。四组后端设计缺口已补齐，Note 时间及学习视图 scope 已定义；后端修订文档 DONE。此前002表的 OPEN 现在仅表示 UI 尚未对齐，不再表示后端缺字段。契约尚未冻结。

外部 Claude2 下一次按 docs/project/UI-V03-HANDOFF.md 完成四组精确差异和少量残余文案；仅修改UI文档并提交003。随后QA复核，再由PM关闭M0-UI。M0-UI继续CHANGES_REQUESTED、M1 TODO；产品测试全NOT_RUN。

