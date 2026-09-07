# iPad 原生架构提案

状态：M0-BE，供 PM / UI / QA 审阅，尚未实施。基线：PRD-v0.1-source；用户确认 iPad 原生，优先阅读与手写，拥有 Mac 和 iPad。

## 方案取舍

推荐 SwiftUI 应用外壳 + UIKit 阅读容器（PDFKit / PencilKit）+ 本地核心服务。PDF 保持主体；服务是 App 内模块，不要求独立 HTTP 后端。替代方案为纯 UIKit（交互掌控更直接，但常规界面开发量较大）或跨平台框架加原生桥接（共享界面多，但手写和 PDF 生命周期仍需原生维护）。本次提案选择第一种，最低系统版本待 Mac 原型验证后与 PM 冻结，不依赖最新 SDK 专属能力。

## 模块与所有权

| 模块 | 职责 | 建议实施所有者 |
|---|---|---|
| App / Library / Study / Notes UI | 页面、导航、状态呈现、用户事件 | 外部前端 |
| ReaderAdapter | PDFView 生命周期、页面坐标转换、PencilKit 覆盖层、手势冲突 | 外部前端，核心服务提供持久化契约 |
| DocumentCore | 导入、页与段落、章节、内容索引、引用校验 | Codex1 |
| LocalStore | 原件、批注、笔记、阅读位置、事务、迁移 | Codex1 |
| LearningCore | 五级上下文、助学结构、全文学习视图、问答 | Codex1 |
| ProviderAdapter | 请求/流式、能力协商、密钥引用、错误映射 | Codex1 |

PM 冻结目录授权后才创建代码。所有 UI 可见状态更新在主执行域；重任务经异步服务调度，避免同步解析/网络阻塞书写。PDFKit 对象不跨执行域任意共享，传递不可变领域快照。

## 阅读与手写

PDFKit 呈现原始 PDF、选择/搜索/目录/跳页；PencilKit 捕获笔迹。按页覆盖层可通过 PDFPageOverlayViewProvider 接入，具体手势及缩放必须真机原型验证。[Apple 覆盖层协议](https://developer.apple.com/documentation/pdfkit/pdfpageoverlayviewprovider)、[WWDC22 PDFKit](https://developer.apple.com/videos/play/wwdc2022/10089/)。

每页 PKDrawing 以可编辑二进制旁车保存；高亮和下划线保存为独立文本锚点与几何区域。原始 PDF 不覆盖。PencilKit 提供绘制、擦除与笔迹数据；数据可用 dataRepresentation 保存。[PencilKit](https://developer.apple.com/documentation/pencilkit)、[PKDrawing 数据](https://developer.apple.com/documentation/pencilkit/pkdrawing-swift.struct/datarepresentation())。

触笔绘写、手指滚动为默认策略建议；文本选择与书写显式工具态切换。覆盖层复用前提交旧页快照，新页仅加载自身笔迹；笔迹更新递增 revision，乱序保存拒绝。短延迟合并写入并在离页/后台化触发 flush，未完成时显示保存中/失败，不能宣称永不丢笔。崩溃恢复保留上一有效版本；最终防丢窗口由真机测试测量。

## 本地存储与隐私

原始 PDF、笔迹/图片放应用私有文件区；结构化记录用版本化 SQLite 存储方案，首版不增加云同步。原件 hash 与 revision 固定，索引可重建，用户笔记与手写不是可丢弃缓存。导入通过临时文件、验证、原子落盘、事务登记；失败回收本任务临时物，不能误删别的导入。存储不足时保留旧版本并报告错误。

API Key 存 Keychain，数据库只留 credentialRef；日志不记文档原文/请求体/密钥。Keychain 用于保存小型秘密数据。[Apple Keychain](https://developer.apple.com/documentation/security/keychain-services)。实施时明确设备锁定访问策略；不默认同步 Keychain。删除资料级联删除索引、笔迹和相关会话，关联笔记的保留/删除由显式操作参数决定；删除前 UI 呈现影响。

BYOK 一个 OpenAI-compatible adapter 是首个候选，不代表所有兼容服务支持 embedding/vision/流式。官方托管模型未来若加入，服务端持有平台密钥；当前不内置共享平台密钥。首次联网操作呈现将发送的文档范围、批注及 Provider。embedding 也算外发，不能在导入时静默上传。普通导入、阅读、批注不依赖网络。

## AI 数据路径

导入后优先可阅读；后台页文本/段落 → 内嵌目录或章节候选 → 内容分类/概念 → 索引。扫描页标记 textUnavailable，可安排本地 OCR 管线；OCR 未完成不伪造可选择文本。不以“扫描件暂不支持 AI”替代正常数字 PDF 的 P0。加密文件等待密码，权限/损坏失败明确呈现。

五级结构 Document → Chapter → Page → Paragraph → Selection。选区和问题优先，预算内补充邻段/当前页/章节信息；禁止每次复制全文。请求固定文档 revision 与 scope 快照，翻页不悄悄改变已发请求。无可靠章节时提供可见页范围建立章节上下文，并标明未识别章节；不能直接取消当前章节助学 P0。

全文学习视图是 P0 独立任务：按段/章分批分析再汇总结构、概念、重点、难点和关系，保存进度与覆盖页码，支持取消/重试。小文档可一次分析但仍受 Provider 预算约束；长文档不以 25 页为硬拒绝阈值。部分覆盖必须标为不完整，不得显示全文完成。

默认文档模式只依据已检索证据，无证据返回 insufficientEvidence，提供用户主动启用扩展模式；扩展知识与文档来源分开显示。模型只能返回给定 evidenceID，应用校验后绑定本地引用；未匹配引用不得生成假跳转。助学固定六段结构，重点 3–5 个，阅读问题 1–3 个默认不带答案；文档类型影响内容策略，不改变统一展示契约。

## 环境验证和阶段门

本次仅文档评审，无产品代码和测试结果。当前 Windows 无 Swift/Xcode；用户可提供 Mac+iPad 后续构建和验收。M1 必须先验证：原生壳运行、PDF 覆盖层、触笔/手指/选区冲突、横竖屏与缩放坐标、离页保存与重启恢复。记录 macOS/Xcode/iPadOS/设备/Pencil 型号和命令结果；Windows 静态检查不能替代真机结果。

排期遵从 docs/project/PLAN.md：M1 导入/阅读/手写；M2 范围上下文、Provider、选区/页/章节助学与证据问答；M3 全文学习视图与其余 V0.1 能力。离线、取消、磁盘满、Provider 拒绝和解析错误均纳入 QA。搜索的正文基础能力与末尾 P1 表存在优先级差异，提案完整保留并纳入 PM 的 M1 阅读阶段。
