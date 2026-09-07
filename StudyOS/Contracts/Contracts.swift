import Foundation

// MARK: - StudyOS 契约总览 (Contract v0.1-draft / M0-BE-REV2)
// 本文件汇总契约包含的核心协议与记录结构：
//
// 1. 核心协议 (Protocols):
//    - ReaderAdapterProtocol: 客户端 UI/适配器通信协议 (UIREV-01, UIREV-03, UIREV-04)
//    - CoreServiceProtocol: 核心聚合服务协议
//    - ReaderCoreServiceProtocol: 阅读器定位与笔迹持久化协议
//    - DocumentServiceProtocol: 文档生命周期与删除协议
//    - NoteServiceProtocol: 笔记管理与归属维护协议
//
// 2. 领域记录与结构 (Domain Records & Structs):
//    - Document: 文档元数据与状态
//    - Page: 物理页结构 (0-based pageIndex0, cropBox, rotation)
//    - Paragraph: 提取段落与置信度
//    - Chapter: 章节目录与起止页范围
//    - SourceAnchor: 来源定位锚点 (precision, availability)
//    - InkPage: 页面手写记录 (drawingRevision, transform)
//    - Annotation: 页面批注 (highlight/underline/text)
//    - ReadingPosition: 阅读物理进度与缩放提示
//    - Note: 笔记记录 (可编辑文本、图片、AI来源、解绑标记)
//    - Evidence: AI 证据条目与提取来源
//    - ContextManifest: 外发清单与确认绑定 (OutboundItem, InclusionStatus)
//
// 3. 阅读器与持久化交互类型 (Reader & Persistence Types):
//    - PageKey: 跨页/跨文档隔离手写键 (documentID + revision + pageIndex0)
//    - InkSaveSnapshot: 入队前固化的不可变墨水快照
//    - InkSaveReceipt: 服务端确认保存的回执 (savedRevision)
//    - SaveInkError: 结构化保存错误分型
//    - NavigationTarget: 来源解析目标 (PDF 空间坐标)
//    - NavigationResult: 会话核对与安全导航结果 (UIREV-04)
//    - ReaderToolMode: 阅读器工具态 (reading / textSelection / annotation)
//    - NotePolicy: 删除时两路笔记处理策略 (keep / delete)
//    - DeleteImpact: 删除影响预览清单 (UIREV-06)
//    - DeleteResult: 删除终态结果 (completed / cleanupPending)
