# 原生前端与核心服务契约 0.1-draft

M0-BE；提案未冻结，前后端双方评审后由 PM 发布正式基线。这里是接口语义，不是可编译代码或远程 REST 要求。

修订标识：0.1-draft / M0-BE-REV2。补齐 UIREV-03–06 已有交互的字段映射；UI 对齐及 QA 复核前不视为冻结。

## 领域记录

| 记录 | 必需字段与约束 |
|---|---|
| Document | id、title、sourceHash、revision、localFileRef、pageCount、importState、indexState、createdAt、updatedAt |
| Page | documentID/revision、pageIndex0、displayLabel、cropBox、rotation、textState、paragraphIDs |
| Paragraph | id、pageIndex0、text、textRevision、regions、order、extractionMethod、confidence |
| Chapter | id、documentID/revision、title、startPageIndex0、endPageIndex0 inclusive、source(outline/inferred/manual)、confidence |
| SourceAnchor | documentID/revision、pageIndex0、regions、paragraphID?、quote?、textRevision?、precision(page/region)、availability(active/documentDeleted) |
| InkPage | documentID/revision、pageIndex0、drawingFileRef、drawingRevision、canvasToPageTransform、formatVersion |
| Annotation | id、kind(highlight/underline/text)、anchor、content、revision、createdAt/updatedAt |
| ReadingPosition | documentID/revision、pageIndex0、pagePoint、zoomHint、updatedAt；进度是阅读位置，不是掌握度 |
| Note | id、documentID?、chapterID?、editableText、imageRefs、sourceAnchors、aiOrigin?、revision、createdAt、updatedAt；服务持久化时生成时间；加入后用户可自由改文 |
| Evidence | evidenceID、anchor、excerpt、extractionMethod；模型输出仅引用本次证据 ID |
| AIRequest | requestID、attemptID、documentID/revision、scope、mode、question?、selectedAnchor?、annotationIDs、conversationID?、providerProfileID |
| AIResult | requestID、attemptID、scopeSnapshot、status、content、validatedSources、coverage、origin(document/general)、createdAt |

内部页号统一从 0 起；界面显示物理页号 pageIndex0+1，并可补充 PDF 自带页标签。模型与 UI 不用可重复的印刷页标签作为主键。时间持久化 ISO 8601，日志显示 +08:00。

坐标固定为该 revision 的 PDF 页面空间 points，保存 cropBox（含非零原点）及 rotation；不用屏幕像素或滚动偏移。regions 可含多个矩形。ReaderAdapter 借 PDFView 页/视图转换 API 转换；不能简单 y 翻转假设所有页同尺寸。[Apple 坐标转换](https://developer.apple.com/documentation/pdfkit/pdfview/convert(_:from:)-4evlx)。PencilKit 画布变换必须记录并随覆盖层恢复；对 0/90/180/270 度、裁切原点与缩放进行往返 QA。缺少区域可定位页并显示“页级来源”；revision 不匹配返回 staleReference，不自动跳至疑似位置。

## 服务操作

所有变更支持取消、结构化失败和 requestID；写入接受 expectedRevision，冲突返回 conflict，UI 不静默覆盖。单次导入/请求可用 operationID 避免重复提交。

| 服务操作 | 输入 | 输出与事件 |
|---|---|---|
| importPDF | pickedFileHandle、operationID | documentID；copying → validating → readable / needsPassword / failed |
| previewDeleteDocument/deleteDocument | documentID/revision / documentID、expectedRevision、notePolicy(keep/delete)、已确认 impactID、operationID | 删除影响清单 / DeleteResult；notePolicy 必填，无默认值 |
| unlockDocument | documentID、临时密码 | readable / invalidPassword；密码不进日志 |
| buildIndex | documentID/revision、外发策略、发生外发时的已确认 Manifest | extraction/structure/embedding 进度、逐页覆盖、partial/ready/failed |
| listLibrary/updateLibraryItem | filter / favorite、folder、expectedRevision | 文档列表 / 新 revision |
| getReaderSnapshot | documentID | 页数、目录、书签、阅读位置、解析状态 |
| savePosition | position | accepted |
| createBookmark/updateBookmark/deleteBookmark | documentID、anchor、label / bookmarkID、expectedRevision | bookmark（id、anchor、label、revision）/ 删除确认；重复操作按 operationID 去重 |
| loadInk/saveInk/flushInk | PageKey / InkSaveSnapshot（定义见下） | snapshot / InkSaveReceipt / 结构化错误 |
| createAnnotation/updateAnnotation | annotation、expectedRevision | 持久化记录 |
| searchDocument | documentID、query | 可取消结果流（anchor + excerpt）；部分索引明确标识 |
| resolveSource | SourceAnchor | NavigationTarget / staleReference / unavailable |
| buildContext | AIRequest、budget、providerCapabilities | ContextManifest + evidence；无网络副作用 |
| generateGuide/ask | AIRequest、确认的 ContextManifest | started、textDelta、completed、failed、cancelled |
| buildStudyView | documentID/revision、scope(document 或显式 pageRange inclusive)、providerProfileID、已确认 Manifest | jobID、attemptID、progress、partial、completed/failed/cancelled；coverage 包含遗漏页；局部任务明确标局部 |
| cancelAI/retryAI | requestID/jobID、attemptID | 取消确认 / 新 attemptID；旧响应不能覆写新结果 |
| saveNote/updateNote | 内容/来源、expectedRevision | Note；普通可编辑内容 |

Guide completed 结构：overview、focusPoints、prerequisites、concepts、misconceptions、readingQuestions、sources；不适用项返回空数组及理由，不能造内容填满。StudyView：structure、concepts、focusSections、difficulties、relations、coverage、readingEstimate。readingEstimate 为 available(minutes、basis、coverage) 或 unavailable(reason)；有足够文本时必须生成并标明估计，文本不足时 UI 显示“暂无法估计阅读时间”及原因，不能隐藏字段。增量文本是临时显示，只有 completed 且通过 schema/来源校验才标为完成；中断结果可留存但标注未完成。

## Provider 与上下文

ProviderProfile 含 baseURL、model、credentialRef、capabilities（generate/stream/embed/vision）、contextWindow 配置及来源。契约包含 generate、stream、embed、vision、contextWindow；不支持的能力明确 unsupportedCapability，不伪装成功。URL 校验与 HTTPS 默认；密钥只能交对应配置的主机，重定向不转发凭据到新主机。

ContextManifest 含 scopeSnapshot、evidenceIDs、pageCoverage、annotationInclusion、estimatedInputTokens、reservedOutputTokens、truncationReasons、providerProfileID。UI 可查看实际发送范围。预算未知则要求配置保守上限，超限切片或收窄并告知；不能无限重试。Embedding 缺失可临时使用关键词检索但标记 lexicalOnly，不宣称向量索引完成；向量索引仍保留为实施任务。索引键含文档/text revision、embedding 模型与维度，变化必须失效重建。

### 实际外发清单与确认绑定

ContextManifest 还必含 manifestID、manifestRevision、documentID/revision、operationKind、providerSnapshot（profileID、配置revision、endpoint、model）、outboundItems。每个 item 含 itemID、kind、purpose(generation/embedding/vision)、sourceIDs、pageCoverage、payloadDigest、byteCount，以及 text 项的 characterCount 或 image 项的 imageCount。kind 枚举为 documentText、questionText、conversationText、annotationText、originalPDF、pageImage、handwritingImage、systemText；documentText 用 coverage/fullDocumentText 标识全文提取文本，不能混称“原始PDF”。embedding 是用途，需与实际发送的文本/图像类型一起显示。混合页图像记录 containsHandwriting，不能将含笔迹截图声称为未发手写。

Manifest 显式给出 originalFileInclusion、pageImageInclusion、handwritingInclusion、annotationInclusion：均为 included(itemIDs) 或 excluded(reason)，由实际 outboundItems 及混合图像内容推导；handwritingInclusion 涵盖独立手写图与合成页内笔迹。UI 的字数/图片数/原件/批注状态只聚合该清单，不根据当前页或能力开关猜测。raw PDF 默认 excluded，但字段反映真实请求，不能固定显示不发送。

本地 buildContext/外发任务准备步骤先生成清单，不发网络请求；确认令牌绑定该 Manifest 的完整摘要及 providerSnapshot。generateGuide、ask、buildIndex 的远程 embedding、buildStudyView 全部分批请求必须受确认覆盖，实际序列化发送项须与清单匹配。分批任务可先确认完整批次清单；动态增加内容、变更 Provider/模型/范围或批注须生成新清单并再次确认，不能复用旧令牌。准备期间无法确定清单则停在 awaitingConfirmation，不先发送。未涉及外发的本地索引无需确认。

### 删除结果

previewDeleteDocument 返回 impactID、文档 revision、受影响记录版本摘要与分类数量（原件、索引、批注、笔迹、会话、关联笔记及图片）。deleteDocument 校验摘要未改变，否则 conflict 并要求刷新影响预览。keep 保留笔记文字、图片副本、时间与原来源信息，解除 documentID/chapterID 外键归属，原来源标 documentDeleted 且不可导航；delete 删除关联笔记，仅删除不再被其他记录引用的图片。两种策略均删除原件、文档索引、笔迹、批注与文档会话。

DeleteResult 为 completed（策略、deletedCounts、retainedNoteIDs）或 cleanupPending（同前述字段、待清理文件数量、重试标识）；只有原件及旁车清理完毕才能 completed。事务失败返回结构化错误且不宣称删除成功；已提交的逻辑删除必须返回真实清理状态，可幂等恢复。UI 在确认前呈现两种笔记选择与相应影响，不能将全删设为唯一行为。

### 阅读会话、保存与来源解析

PageKey = documentID + documentRevision + pageIndex0。documentRevision 是源 PDF 版本，expectedRevision 是该页已持久化的 drawingRevision，两者不能互换。InkSaveSnapshot 含 PageKey、readerSessionID、snapshotID、drawingBlob、canvasToPageTransform、expectedRevision；在排队前固化完整值，不在 await 后从当前页补齐。flushInk 提交指定快照，批量 flush 返回以 PageKey/snapshotID 标识的每项结果，不能仅以 Int 页号为键。

InkSaveReceipt 含 PageKey、snapshotID、savedRevision、readerSessionID。同一 PageKey 串行提交；可合并尚未开始的旧快照，但已经提交的确认必须更新对应页的 persistedRevision，不能一概丢弃旧确认。确认只清除对应快照的 dirty；较新笔画仍保持 dirty 并用已确认 revision 排队。保存失败映射 storageFull/saveFailed/conflict/staleReference/unavailable；保留未提交快照的内存或真实恢复文件，不声称 dirty 标志能恢复笔画。切换会话后旧结果只更新原 PageKey 的服务账本，不能覆盖新页画布/保存指示。文档删除或版本替换后提交应拒绝，不重建被删记录。

NavigationTarget 含 documentID、documentRevision、pageIndex0、regions（PDF页面坐标）、precision、resolvedFromAnchor；仅由 resolveSource 成功产生。ReaderAdapter 发起解析时捕获 readerSessionID 和 documentID/revision；await 返回后在主执行域再次核对当前会话仍打开、文档/版本匹配、target 匹配及页号有效，随后在同一执行段导航。会话关闭/替换则 ignoredStaleSession，禁止导航或高亮；staleReference/unavailable 映射同名呈现状态，不按旧页号退回导航。全文重点导航使用同一入口。所有保存 await 后的 UI 更新同样核对会话和 PageKey；服务持久化确认与 UI 是否仍显示原页分开处理。

### AI 尝试终态

每条事件携带 requestID/jobID、attemptID、scopeSnapshot。每个 attempt 从 pending/running 最多进入一个 completed、failed 或 cancelled 终态；failed 与 cancelled 互斥。用户对运行中尝试主动取消才调用 cancelAI，返回取消确认后进入 cancelled；failed 保留结构化错误与标为未完成的部分内容，不自动调用 cancelAI。终态由服务串行裁决，已终态的取消返回 alreadyTerminal，不能覆写失败或完成；终态后的迟到事件忽略。

retryAI 为失败/取消/已结束尝试创建新 attemptID，并重新核验 Manifest 是否仍有效；“继续生成”也是新尝试，不承诺流续传。旧 attempt 的响应不得更新新 attempt。关闭 UI 可脱离订阅，资源清理由服务负责，不应把失败显示成用户取消。

scope：selection(anchor)、page(index0)、chapter(chapterID 或明确页范围)、document。系统提示与用户问题独立于不可信文档文本；文档中的指令不作为系统权限。默认不向外发手写图片；若将其纳入，需显式范围显示和支持 vision 的 Provider。生成完成再次验证文档未被删除/替换。

## 失败与 UI 处理

| code | UI/恢复语义 |
|---|---|
| passwordRequired / invalidPassword | 密码输入；未解锁不分析 |
| invalidPDF / permissionDenied | 导入失败，保留错误原因，不呈现空成功文档 |
| textUnavailable / indexPartial | 可读原件；文本 AI 说明缺失范围并提供 OCR/重建任务状态 |
| storageFull / saveFailed | 保留旧版，显示未保存，可重试；离页不能冒充已存 |
| providerNotConfigured / authFailed | 保持本地阅读，打开配置入口 |
| offline / timeout / rateLimited | 显示可重试，尊重等待时间；用户可取消 |
| insufficientEvidence | 说明文档证据不足，用户主动切扩展 |
| contextTooLarge / unsupportedCapability | 明确受限能力，切片或调整范围 |
| invalidModelOutput / invalidCitation | 不显示已验证来源，结果失败或明确部分；可重试 |
| cancelled / staleReference / conflict | 停止更新 / 提示旧文档引用 / 重新加载冲突，不覆盖 |

## 前端联调交接最小集

前端交付需附 ReaderAdapter 的坐标约定、工具态、保存调用时机与错误呈现。核心服务提供带 0-based 页号、旋转/裁切、无文字页、章节缺失、部分 AI 和失效引用的固定测试样本。mock 仅用于开发演示，必须标为 mock；最终需在 Mac 构建、iPad Pencil 真机与真实 Provider 各独立记录实测。Schema 版本修改须 PM 协调，不直接破坏外部 UI。
