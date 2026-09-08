import Foundation
import SwiftUI
import Combine

#if canImport(PDFKit)
import PDFKit
#endif

/// 自由问答或助学消息领域模型
public struct AIMessageItem: Identifiable, Sendable {
    public let id: String
    public let isUser: Bool
    public let text: String
    public let sources: [SourceAnchor]
    public let timestamp: Date
    public let isPartial: Bool
    
    public init(
        id: String = UUID().uuidString,
        isUser: Bool,
        text: String,
        sources: [SourceAnchor] = [],
        timestamp: Date = Date(),
        isPartial: Bool = false
    ) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.sources = sources
        self.timestamp = timestamp
        self.isPartial = isPartial
    }
}

/// 阅读器工作区主 ViewModel
/// 协调 ReaderAdapter、AI 侧栏、选区菜单与来源定位动画 (UIREV-01, UIREV-02, UIREV-04)
@MainActor
public final class ReaderViewModel: ObservableObject {
    // MARK: - 依赖
    public let document: Document
    public let coreService: CoreServiceProtocol
    public var adapter: ReaderAdapter
    
    // MARK: - 阅读器视图状态
    @Published public var snapshot: ReaderSnapshot?
    @Published public var isAISidebarOpen: Bool = false
    @Published public var isFullStudyViewOpen: Bool = false
    @Published public var isOutlineOpen: Bool = false
    @Published public var isBookmarksOpen: Bool = false
    @Published public var isNotesOpen: Bool = false
    
    // 选区与浮动菜单
    @Published public var selectionAnchor: SourceAnchor?
    @Published public var selectionScreenRect: CGRect?
    
    // 来源发光边框动画
    @Published public var focusRingScreenRect: CGRect?
    @Published public var focusRingToken: UUID = UUID()
    
    // 轻量提示 (Toast)
    @Published public var toastMessage: String?
    @Published public var showToast: Bool = false
    
    // AI 交互状态
    @Published public var currentScope: AIScope
    @Published public var isAIGenerating: Bool = false
    @Published public var currentAIResult: AIResult?
    @Published public var messages: [AIMessageItem] = []
    @Published public var askInputText: String = ""
    @Published public var currentAIStatus: AIResultStatus = .pending
    @Published public var currentErrorMessage: String?
    @Published public var activeManifest: ContextManifest?
    
    // 当前在途请求追踪标识 (用于与后端 AIServiceActor cancel 交互)
    private var activeRequestID: String?
    private var activeAttemptID: String?
    private var activeGenerationTask: Task<Void, Never>?
    
    // MARK: - 初始化
    public init(
        document: Document,
        coreService: CoreServiceProtocol,
        initialPageIndex0: Int = 0
    ) {
        self.document = document
        self.coreService = coreService
        
        let adapter = ReaderAdapter(
            documentID: document.id,
            documentRevision: document.revision,
            initialPageIndex0: initialPageIndex0,
            pageCount: document.pageCount,
            coreService: coreService
        )
        self.adapter = adapter
        self.currentScope = .page(index0: initialPageIndex0)
        
        bindAdapterCallbacks()
    }
    
    private func bindAdapterCallbacks() {
        adapter.onPageChanged = { [weak self] pageIndex0 in
            guard let self = self else { return }
            self.currentScope = .page(index0: pageIndex0)
            self.saveReadingPosition(pageIndex0: pageIndex0)
        }
        
        adapter.onSelectionChanged = { [weak self] anchor, screenRect in
            guard let self = self else { return }
            self.selectionAnchor = anchor
            self.selectionScreenRect = screenRect
            if let anchor = anchor {
                self.currentScope = .selection(anchor: anchor)
            }
        }
        
        adapter.onFocusHighlight = { [weak self] screenRect in
            guard let self = self else { return }
            self.focusRingScreenRect = screenRect
            self.focusRingToken = UUID()
        }
        
        adapter.onToastMessage = { [weak self] msg in
            guard let self = self else { return }
            self.displayToast(msg)
        }
    }
    
    // MARK: - 生命周期加载
    public func loadInitialSnapshot() async {
        do {
            let snap = try await coreService.readerCoreService.getReaderSnapshot(documentID: document.id)
            self.snapshot = snap
            if let pos = snap.readingPosition {
                _ = adapter.goToPage(index0: pos.pageIndex0)
            }
        } catch {
            displayToast("加载阅读快照失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 来源跳转
    public func navigateToSource(_ source: SourceAnchor) async {
        let result = await adapter.navigateTo(source: source)
        switch result {
        case .success:
            break
        case .staleReference:
            displayToast("引用基于旧版本文档，无法唯一定位")
        case .unavailable:
            displayToast("引用目标已失效或文档已删除")
        case .invalidPageIndex:
            displayToast("目标页面越界或已被移除")
        case .ignoredStaleSession:
            // 静默忽略过期会话导航
            break
        }
    }
    
    // MARK: - AI 真实流式助学与问答 (M2-UI 规范落地)
    
    /// 依据物理页码尝试从 PDFKit 渲染树或本地源文件提取实际页面文本
    public func extractPageText(pageIndex0: Int) -> String? {
        guard pageIndex0 >= 0 && pageIndex0 < document.pageCount else { return nil }
        #if canImport(PDFKit)
        if let pdfView = adapter.pdfView,
           let doc = pdfView.document,
           pageIndex0 < doc.pageCount,
           let page = doc.page(at: pageIndex0),
           let str = page.string, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return str
        }
        let path = document.localFileRef
        if !path.isEmpty {
            let fileURL: URL
            if let parsedURL = URL(string: path), parsedURL.scheme != nil {
                fileURL = parsedURL
            } else {
                fileURL = URL(fileURLWithPath: path)
            }
            if let doc = PDFDocument(url: fileURL),
               pageIndex0 < doc.pageCount,
               let page = doc.page(at: pageIndex0),
               let str = page.string, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return str
            }
        }
        #endif
        return nil
    }

    /// 依据目标学习范围搜集真实的物理页面文本
    public func collectPageTexts(for scope: AIScope) -> [Int: String] {
        var result: [Int: String] = [:]
        switch scope {
        case .selection(let anchor):
            if let text = extractPageText(pageIndex0: anchor.pageIndex0) {
                result[anchor.pageIndex0] = text
            }
        case .page(let page0):
            if let text = extractPageText(pageIndex0: page0) {
                result[page0] = text
            }
        case .chapter(_, let startPage, let endPage):
            let validStart = max(0, startPage)
            let validEnd = min(document.pageCount - 1, endPage)
            if validStart <= validEnd {
                for p in validStart...validEnd {
                    if let text = extractPageText(pageIndex0: p) {
                        result[p] = text
                    }
                }
            }
        case .document:
            for p in 0..<document.pageCount {
                if let text = extractPageText(pageIndex0: p) {
                    result[p] = text
                }
            }
        }
        return result
    }
    
    /// 请求选区解释
    public func requestAIExplanation(for anchor: SourceAnchor) {
        selectionAnchor = nil
        selectionScreenRect = nil
        adapter.clearCurrentSelection()
        
        isAISidebarOpen = true
        currentScope = .selection(anchor: anchor)
        
        let promptQuote = anchor.quote ?? "选定文本"
        askAI(text: "解释选区: “\(promptQuote)”", selectedAnchor: anchor)
    }
    
    /// 发送自由问答
    public func sendQuestion() {
        let text = askInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        askInputText = ""
        askAI(text: text)
    }
    
    /// 核心自由问答流式调用：基于 coreService.aiService 消费 AsyncThrowingStream
    public func askAI(text: String, selectedAnchor: SourceAnchor? = nil) {
        // 若当前正在生成，先主动终止前序任务
        if isAIGenerating {
            stopAIGeneration()
        }
        
        let reqID = UUID().uuidString
        let attID = UUID().uuidString
        self.activeRequestID = reqID
        self.activeAttemptID = attID
        
        // 0. 捕获已有历史对话（在追加本次新问答之前）
        let history: [LLMMessage] = messages.filter { !$0.isPartial && !$0.text.isEmpty }.map { msg in
            LLMMessage(
                role: msg.isUser ? .user : .assistant,
                content: msg.text
            )
        }
        
        // 1. 追加用户消息
        let userMsg = AIMessageItem(isUser: true, text: text)
        messages.append(userMsg)
        
        // 2. 初始化 AI 占位消息与状态
        let aiMsgID = UUID().uuidString
        let initialAiMsg = AIMessageItem(
            id: aiMsgID,
            isUser: false,
            text: "",
            sources: [],
            isPartial: true
        )
        messages.append(initialAiMsg)
        
        isAIGenerating = true
        currentAIStatus = .running
        currentErrorMessage = nil
        
        // 3. 构建请求与上下文清单
        let scopeToUse: AIScope
        if let anchor = selectedAnchor {
            scopeToUse = .selection(anchor: anchor)
        } else {
            scopeToUse = currentScope
        }
        
        let request = AIRequest(
            requestID: reqID,
            attemptID: attID,
            documentID: document.id,
            documentRevision: document.revision,
            scope: scopeToUse,
            mode: .ask,
            question: text,
            selectedAnchor: selectedAnchor,
            providerProfileID: "openai-default"
        )
        
        let providerSnapshot = ProviderSnapshot(
            profileID: "openai-default",
            endpoint: "https://api.openai.com/v1",
            model: "gpt-4o-mini"
        )
        let aggregator = ContextAggregator()
        let pageTexts = collectPageTexts(for: scopeToUse)
        let aggregated = aggregator.buildContext(
            request: request,
            providerSnapshot: providerSnapshot,
            document: document,
            pageTexts: pageTexts,
            conversationHistory: history
        )
        self.activeManifest = aggregated.manifest
        
        // 4. 启动异步 Task 消费流
        activeGenerationTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let stream = try await self.coreService.aiService.generateStream(
                    request: request,
                    context: aggregated
                )
                
                var accumulatedText = ""
                for try await chunk in stream {
                    // 检查 Task 是否已取消
                    if Task.isCancelled {
                        return
                    }
                    accumulatedText += chunk.delta
                    
                    // 响应式逐字更新 UI 上的最后一条 AI 消息
                    if let idx = self.messages.firstIndex(where: { $0.id == aiMsgID }) {
                        self.messages[idx] = AIMessageItem(
                            id: aiMsgID,
                            isUser: false,
                            text: accumulatedText,
                            sources: selectedAnchor != nil ? [selectedAnchor!] : [],
                            timestamp: Date(),
                            isPartial: true
                        )
                    }
                }
                
                // 正常完成流式生成
                guard !Task.isCancelled, self.activeAttemptID == attID else { return }
                
                // 锚点验证
                var sources: [SourceAnchor] = []
                if let anchor = selectedAnchor {
                    sources = await self.coreService.aiService.validateSources(sources: [anchor])
                } else {
                    let pageAnchor = SourceAnchor(
                        documentID: self.document.id,
                        documentRevision: self.document.revision,
                        pageIndex0: self.adapter.currentPageIndex0,
                        precision: .page
                    )
                    sources = await self.coreService.aiService.validateSources(sources: [pageAnchor])
                }
                
                if let idx = self.messages.firstIndex(where: { $0.id == aiMsgID }) {
                    self.messages[idx] = AIMessageItem(
                        id: aiMsgID,
                        isUser: false,
                        text: accumulatedText.isEmpty ? "（未获取到有效回答内容）" : accumulatedText,
                        sources: sources,
                        timestamp: Date(),
                        isPartial: false
                    )
                }
                
                self.currentAIStatus = .completed
                self.isAIGenerating = false
                self.activeRequestID = nil
                self.activeAttemptID = nil
                
            } catch is CancellationError {
                // 主动取消：严格置为 .cancelled 终态，与 .failed 互斥
                guard self.activeAttemptID == attID else { return }
                self.markGenerationCancelled(msgID: aiMsgID)
            } catch let error as LLMProviderError where error == .cancelled {
                guard self.activeAttemptID == attID else { return }
                self.markGenerationCancelled(msgID: aiMsgID)
            } catch {
                // 异常处理：严格置为 .failed 终态，与 .cancelled 互斥
                guard self.activeAttemptID == attID else { return }
                if self.currentAIStatus != .cancelled {
                    self.markGenerationFailed(msgID: aiMsgID, error: error)
                }
            }
        }
    }
    
    /// 生成助学导读卡片流（六段式）
    public func generateStudyGuide(scope: AIScope) {
        if isAIGenerating {
            stopAIGeneration()
        }
        
        let reqID = UUID().uuidString
        let attID = UUID().uuidString
        self.activeRequestID = reqID
        self.activeAttemptID = attID
        
        isAIGenerating = true
        currentAIStatus = .running
        currentErrorMessage = nil
        currentScope = scope
        
        let request = AIRequest(
            requestID: reqID,
            attemptID: attID,
            documentID: document.id,
            documentRevision: document.revision,
            scope: scope,
            mode: .guide,
            question: "为当前学习范围生成深度六段式研读导引与核心考点解析",
            providerProfileID: "openai-default"
        )
        
        let providerSnapshot = ProviderSnapshot(
            profileID: "openai-default",
            endpoint: "https://api.openai.com/v1",
            model: "gpt-4o-mini"
        )
        let aggregator = ContextAggregator()
        let pageTexts = collectPageTexts(for: scope)
        let aggregated = aggregator.buildContext(
            request: request,
            providerSnapshot: providerSnapshot,
            document: document,
            pageTexts: pageTexts
        )
        self.activeManifest = aggregated.manifest
        
        var guideResult = AIResult(
            requestID: reqID,
            attemptID: attID,
            scopeSnapshot: aggregated.manifest.scopeSnapshot,
            status: .running,
            content: ""
        )
        self.currentAIResult = guideResult
        
        activeGenerationTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let stream = try await self.coreService.aiService.generateStream(
                    request: request,
                    context: aggregated
                )
                
                var accumulated = ""
                for try await chunk in stream {
                    if Task.isCancelled { return }
                    accumulated += chunk.delta
                    guideResult.content = accumulated
                    self.currentAIResult = guideResult
                }
                
                guard !Task.isCancelled, self.activeAttemptID == attID else { return }
                guideResult.status = .completed
                guideResult.content = accumulated
                self.currentAIResult = guideResult
                self.currentAIStatus = .completed
                self.isAIGenerating = false
                self.activeRequestID = nil
                self.activeAttemptID = nil
            } catch is CancellationError {
                guard self.activeAttemptID == attID else { return }
                self.currentAIStatus = .cancelled
                guideResult.status = .cancelled
                self.currentAIResult = guideResult
                self.isAIGenerating = false
                self.displayToast("导学生成已取消")
            } catch let error as LLMProviderError where error == .cancelled {
                guard self.activeAttemptID == attID else { return }
                self.currentAIStatus = .cancelled
                guideResult.status = .cancelled
                self.currentAIResult = guideResult
                self.isAIGenerating = false
                self.displayToast("导学生成已取消")
            } catch {
                guard self.activeAttemptID == attID else { return }
                if self.currentAIStatus != .cancelled {
                    self.currentAIStatus = .failed
                    let errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    self.currentErrorMessage = errorText
                    guideResult.status = .failed
                    self.currentAIResult = guideResult
                    self.isAIGenerating = false
                    self.displayToast("导学生成失败: \(errorText)")
                }
            }
        }
    }
    
    /// 主动停止当前正在进行的生成（严格保证 cancelled 与 failed 互斥，支持 alreadyTerminal 防御）
    public func stopAIGeneration() {
        guard isAIGenerating, let reqID = activeRequestID, let attID = activeAttemptID else {
            isAIGenerating = false
            return
        }
        
        // 1. 取消客户端 Task
        activeGenerationTask?.cancel()
        activeGenerationTask = nil
        
        // 2. 状态机互斥置为 cancelled
        currentAIStatus = .cancelled
        isAIGenerating = false
        
        // 3. 标记最后一条 AI 消息为取消终态
        if let last = messages.last, !last.isUser && last.isPartial {
            if let idx = messages.indices.last {
                let updatedText = last.text.isEmpty ? "（生成已由读者主动终止）" : "\(last.text)\n\n[⏹️ 读者已终止生成]"
                messages[idx] = AIMessageItem(
                    id: last.id,
                    isUser: false,
                    text: updatedText,
                    sources: last.sources,
                    timestamp: Date(),
                    isPartial: false
                )
            }
        }
        
        // 4. 调用后端 AIService cancel
        Task { [weak self] in
            guard let self = self else { return }
            _ = await self.coreService.aiService.cancel(requestID: reqID, attemptID: attID)
            self.displayToast("已停止生成")
        }
    }
    
    /// 重试上一次失败或取消的任务（派发全新 attemptID 并复核 Manifest）
    public func retryLastAIAction() {
        if let lastUserMsg = messages.last(where: { $0.isUser }) {
            askAI(text: lastUserMsg.text)
        } else {
            generateStudyGuide(scope: currentScope)
        }
    }
    
    // MARK: - 内部私有终态辅助 (互斥保障)
    private func markGenerationCancelled(msgID: String) {
        currentAIStatus = .cancelled
        isAIGenerating = false
        if let idx = messages.firstIndex(where: { $0.id == msgID }) {
            let item = messages[idx]
            let updatedText = item.text.isEmpty ? "（生成已终止）" : "\(item.text)\n\n[⏹️ 已终止生成 (部分结果)]"
            messages[idx] = AIMessageItem(
                id: item.id,
                isUser: false,
                text: updatedText,
                sources: item.sources,
                timestamp: Date(),
                isPartial: false
            )
        }
        displayToast("已终止生成")
    }
    
    private func markGenerationFailed(msgID: String, error: Error) {
        currentAIStatus = .failed
        let errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        currentErrorMessage = errorText
        isAIGenerating = false
        if let idx = messages.firstIndex(where: { $0.id == msgID }) {
            let item = messages[idx]
            let updatedText = item.text.isEmpty ? "生成失败: \(errorText)" : "\(item.text)\n\n[⚠️ 生成中断: \(errorText)]"
            messages[idx] = AIMessageItem(
                id: item.id,
                isUser: false,
                text: updatedText,
                sources: item.sources,
                timestamp: Date(),
                isPartial: false
            )
        }
        displayToast("AI 生成失败: \(errorText)")
    }
    
    public func cancelAIGeneration() {
        stopAIGeneration()
    }

    
    // MARK: - 笔记与书签快捷操作
    public func saveNoteFromSelection(text: String, anchor: SourceAnchor) async {
        let note = Note(
            documentID: document.id,
            editableText: text,
            sourceAnchors: [anchor]
        )
        do {
            _ = try await coreService.noteService.saveNote(note, expectedRevision: 1)
            displayToast("已将选区保存至笔记")
        } catch {
            displayToast("保存笔记失败: \(error.localizedDescription)")
        }
        selectionAnchor = nil
        selectionScreenRect = nil
        adapter.clearCurrentSelection()
    }
    
    public func toggleBookmarkForCurrentPage() async {
        let page0 = adapter.currentPageIndex0
        let anchor = SourceAnchor(
            documentID: document.id,
            documentRevision: document.revision,
            pageIndex0: page0,
            precision: .page
        )
        do {
            _ = try await coreService.readerCoreService.createBookmark(
                documentID: document.id,
                anchor: anchor,
                label: "第 \(page0 + 1) 页书签",
                operationID: UUID().uuidString
            )
            displayToast("已添加第 \(page0 + 1) 页书签")
        } catch {
            displayToast("添加书签失败: \(error.localizedDescription)")
        }
    }
    
    private func saveReadingPosition(pageIndex0: Int) {
        Task {
            let pos = ReadingPosition(
                documentID: document.id,
                documentRevision: document.revision,
                pageIndex0: pageIndex0
            )
            _ = try? await coreService.savePosition(pos)
        }
    }
    
    public func displayToast(_ message: String) {
        self.toastMessage = message
        self.showToast = true
    }
}
