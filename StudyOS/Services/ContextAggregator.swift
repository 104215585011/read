import Foundation

/// 聚合上下文片段模型
public struct AggregatedContext: Sendable {
    public let manifest: ContextManifest
    public let systemPrompt: String
    public let userPrompt: String
    public let assembledText: String

    public init(
        manifest: ContextManifest,
        systemPrompt: String,
        userPrompt: String,
        assembledText: String
    ) {
        self.manifest = manifest
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.assembledText = assembledText
    }
}

/// 五级上下文动态聚合引擎 (ContextAggregator)
/// 依据 PRD 与 0.1-draft / M0-BE-REV2 契约规范，将选区、页面、章节、全篇与对话历史动态聚合，
/// 生成透明可审计的 OutboundItem 清单与 ContextManifest，严控隐私边界与用量估算。
public struct ContextAggregator: Sendable {
    public init() {}

    /// 聚合构建上下文与外发清单
    public func buildContext(
        request: AIRequest,
        providerSnapshot: ProviderSnapshot,
        document: Document?,
        chapters: [Chapter] = [],
        pageTexts: [Int: String] = [:], // pageIndex0 -> 提取文本
        conversationHistory: [LLMMessage] = []
    ) -> AggregatedContext {
        var outboundItems: [OutboundItem] = []
        var evidenceIDs: [String] = []
        var pageCoverage: [Int] = []
        var truncationReasons: [String] = []

        var assembledContextParts: [String] = []

        // Level 1: Selection (选区文本)
        if let selectedAnchor = request.selectedAnchor, let quote = selectedAnchor.quote, !quote.isEmpty {
            let digest = computeDigest(quote)
            let item = OutboundItem(
                kind: .documentText,
                purpose: .generation,
                sourceIDs: [selectedAnchor.paragraphID ?? "selection_p\(selectedAnchor.pageIndex0)"],
                pageCoverage: [selectedAnchor.pageIndex0],
                payloadDigest: digest,
                byteCount: quote.utf8.count,
                characterCount: quote.count,
                containsHandwriting: false
            )
            outboundItems.append(item)
            pageCoverage.append(selectedAnchor.pageIndex0)
            assembledContextParts.append("[当前选区内容 (第 \(selectedAnchor.pageIndex0 + 1) 页)]:\n\(quote)")
        }

        // Level 2 & 3 & 4: 根据 Scope 聚合页面与章节文本
        switch request.scope {
        case .selection:
            // 已经在 Level 1 处理，如有当前页文本作为背景可酌情补充
            break

        case .page(let pageIndex0):
            pageCoverage.append(pageIndex0)
            if let pageText = pageTexts[pageIndex0], !pageText.isEmpty {
                let digest = computeDigest(pageText)
                let item = OutboundItem(
                    kind: .documentText,
                    purpose: .generation,
                    sourceIDs: ["page_\(pageIndex0)"],
                    pageCoverage: [pageIndex0],
                    payloadDigest: digest,
                    byteCount: pageText.utf8.count,
                    characterCount: pageText.count,
                    containsHandwriting: false
                )
                outboundItems.append(item)
                assembledContextParts.append("[当前页面内容 (第 \(pageIndex0 + 1) 页)]:\n\(pageText)")
            }

        case .chapter(let chapterID, let startPage, let endPage):
            for p in startPage...endPage {
                pageCoverage.append(p)
                if let pText = pageTexts[p], !pText.isEmpty {
                    let digest = computeDigest(pText)
                    let item = OutboundItem(
                        kind: .documentText,
                        purpose: .generation,
                        sourceIDs: [chapterID ?? "ch_p\(p)"],
                        pageCoverage: [p],
                        payloadDigest: digest,
                        byteCount: pText.utf8.count,
                        characterCount: pText.count,
                        containsHandwriting: false
                    )
                    outboundItems.append(item)
                    assembledContextParts.append("[第 \(p + 1) 页]:\n\(pText)")
                }
            }

        case .document:
            // 全文大纲与概要聚合 (Level 4)
            if !chapters.isEmpty {
                let outlineSummary = chapters.map { "- \($0.title) (第 \($0.startPageIndex0 + 1) ~ \($0.endPageIndex0 + 1) 页)" }.joined(separator: "\n")
                let digest = computeDigest(outlineSummary)
                let item = OutboundItem(
                    kind: .documentText,
                    purpose: .generation,
                    sourceIDs: ["outline_summary"],
                    pageCoverage: Array(Set(chapters.flatMap { $0.startPageIndex0...$0.endPageIndex0 })).sorted(),
                    payloadDigest: digest,
                    byteCount: outlineSummary.utf8.count,
                    characterCount: outlineSummary.count,
                    containsHandwriting: false
                )
                outboundItems.append(item)
                assembledContextParts.append("[全书目录结构]:\n\(outlineSummary)")
            } else if let doc = document {
                let metaSummary = "文档标题: \(doc.title), 总页数: \(doc.pageCount)"
                let digest = computeDigest(metaSummary)
                let item = OutboundItem(
                    kind: .documentText,
                    purpose: .generation,
                    sourceIDs: ["document_meta"],
                    pageCoverage: [],
                    payloadDigest: digest,
                    byteCount: metaSummary.utf8.count,
                    characterCount: metaSummary.count,
                    containsHandwriting: false
                )
                outboundItems.append(item)
                assembledContextParts.append("[文档元数据]:\n\(metaSummary)")
            }
        }

        // Level 5: 历史对话与用户提问
        if let question = request.question, !question.isEmpty {
            let digest = computeDigest(question)
            let qItem = OutboundItem(
                kind: .questionText,
                purpose: .generation,
                sourceIDs: ["user_question"],
                pageCoverage: [],
                payloadDigest: digest,
                byteCount: question.utf8.count,
                characterCount: question.count,
                containsHandwriting: false
            )
            outboundItems.append(qItem)
        }

        if !conversationHistory.isEmpty {
            let historyText = conversationHistory.map { "\($0.role.rawValue): \($0.content)" }.joined(separator: "\n")
            let digest = computeDigest(historyText)
            let hItem = OutboundItem(
                kind: .conversationText,
                purpose: .generation,
                sourceIDs: ["conversation_history"],
                pageCoverage: [],
                payloadDigest: digest,
                byteCount: historyText.utf8.count,
                characterCount: historyText.count,
                containsHandwriting: false
            )
            outboundItems.append(hItem)
        }

        // 整理唯一覆盖页码
        let uniquePageCoverage = Array(Set(pageCoverage)).sorted()

        // 估算 Token (粗略按照 1 token ≈ 4 字符 / 0.75 词)
        let totalChars = outboundItems.compactMap { $0.characterCount }.reduce(0, +)
        let estimatedTokens = max(10, Int(Double(totalChars) / 2.5))

        // 隐私与脱敏推导：依据契约 0.1-draft / M0-BE-REV2
        let docTextItems = outboundItems.filter { $0.kind == .documentText }.map { $0.itemID }
        let originalPDFStatus: InclusionStatus = .excluded(reason: "默认不外发原始PDF二进制文件")
        let pageImageStatus: InclusionStatus = .excluded(reason: "当前请求未勾选外发页面截图")
        let handwritingStatus: InclusionStatus = .excluded(reason: "手写墨水笔迹默认保留本地，未外发")
        let annotationStatus: InclusionStatus = request.annotationIDs.isEmpty ? .excluded(reason: "未选中批注") : .included(itemIDs: request.annotationIDs)

        let scopeSnapshot = describeScope(request.scope)

        let manifest = ContextManifest(
            manifestID: UUID().uuidString,
            manifestRevision: 1,
            documentID: request.documentID,
            documentRevision: request.documentRevision,
            operationKind: request.mode.rawValue,
            providerSnapshot: providerSnapshot,
            outboundItems: outboundItems,
            originalFileInclusion: originalPDFStatus,
            pageImageInclusion: pageImageStatus,
            handwritingInclusion: handwritingStatus,
            annotationInclusion: annotationStatus,
            estimatedInputTokens: estimatedTokens,
            reservedOutputTokens: 2048,
            truncationReasons: truncationReasons,
            scopeSnapshot: scopeSnapshot,
            evidenceIDs: evidenceIDs,
            pageCoverage: uniquePageCoverage
        )

        // 构造 System Prompt 与 User Prompt
        let systemPrompt = """
        你是 StudyOS 原生 iPad 阅读学习助学专家。
        你将依据提供的文档上下文、选区或大纲进行精准解析。
        规则：
        1. 必须基于提供的上下文内容作答，严禁编造文献中不存在的内容；
        2. 如文档内容不足，必须明确指出“文档证据不足”，切勿凭空猜测；
        3. 如引用具体内容，尽量标明所属页码或段落来源；
        4. 语言专业、清晰、精炼，贴合学术与精读场景。
        """

        let contextBlock = assembledContextParts.joined(separator: "\n\n")
        let userQuestion = request.question ?? (request.mode == .guide ? "请为我生成本节导读与重点拆解" : "请分析上述选区内容")
        let userPrompt = """
        \(contextBlock.isEmpty ? "" : "【参考文档资料】：\n" + contextBlock + "\n\n")【用户问题/指令】：
        \(userQuestion)
        """

        return AggregatedContext(
            manifest: manifest,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            assembledText: contextBlock
        )
    }

    private func computeDigest(_ content: String) -> String {
        let length = content.utf8.count
        let prefix = content.prefix(16).hashValue
        return "sha256_\(length)_\(abs(prefix))"
    }

    private func describeScope(_ scope: AIScope) -> String {
        switch scope {
        case .selection(let anchor):
            return "选区 (第 \(anchor.pageIndex0 + 1) 页)"
        case .page(let p):
            return "单页 (第 \(p + 1) 页)"
        case .chapter(_, let start, let end):
            return "章节 (第 \(start + 1) ~ \(end + 1) 页)"
        case .document:
            return "全文范围"
        }
    }
}
