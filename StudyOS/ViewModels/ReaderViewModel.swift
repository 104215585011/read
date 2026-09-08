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

/// 客户端网络韧性与端侧降级 UI 状态 (M4-RELEASE)
public enum NetworkResilienceUIState: Sendable, Equatable {
    case cloudAvailable
    case retrying(attempt: Int, maxAttempts: Int, reason: String)
    case switchedToLocal(modelName: String)
    case offlineUnavailable(reason: String)
    
    public var displayText: String {
        switch self {
        case .cloudAvailable:
            return "云端可用 (高速)"
        case .retrying(let attempt, let maxAttempts, let reason):
            return "弱网重试中 (\(attempt)/\(maxAttempts)): \(reason)"
        case .switchedToLocal(let modelName):
            return "已无缝切换至端侧本地模型 (\(modelName))"
        case .offlineUnavailable(let reason):
            return "离线未连接 (\(reason))"
        }
    }
    
    public var iconName: String {
        switch self {
        case .cloudAvailable:
            return "cloud.fill"
        case .retrying:
            return "arrow.triangle.2.circlepath"
        case .switchedToLocal:
            return "cpu.fill"
        case .offlineUnavailable:
            return "wifi.slash"
        }
    }
    
    public var tintColor: Color {
        switch self {
        case .cloudAvailable:
            return StudyTheme.Colors.success
        case .retrying:
            return StudyTheme.Colors.accent
        case .switchedToLocal:
            return StudyTheme.Colors.primary
        case .offlineUnavailable:
            return StudyTheme.Colors.danger
        }
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
    
    // MARK: - M3-UI 全文学习、分批抽取、AI Notes 与端侧离线模型
    @Published public var fullDocumentAnalysis: FullDocumentAnalysis?
    @Published public var isAnalyzingFullDocument: Bool = false
    @Published public var batchExtractionProgress: BatchExtractionProgress?
    @Published public var isExtractingBatch: Bool = false
    
    @Published public var aiNotes: [AINoteCard] = []
    @Published public var isAINotesOpen: Bool = false
    @Published public var localModelStatus: LocalModelInferenceStatus?
    
    // MARK: - M4-UI 纸张护眼主题与网络弹性
    @Published public var selectedPaperTheme: StudyTheme.PaperTheme = .warmSepia
    @Published public var networkResilienceState: NetworkResilienceUIState = .cloudAvailable
    @Published public var retryEngineStats: RetryEngineStats?
    @Published public var offlinePackages: [ModelPackageMetadata] = []
    
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
        
        await loadAINotes()
        await checkLocalLLMStatus()
        await refreshNetworkAndOfflineResilience()
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
                            sources: selectedAnchor.map { [$0] } ?? [],
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
    
    // MARK: - M3-UI: 全文学习研读与分批抽取引擎联动 (R10 P0)
    public func loadOrGenerateFullDocumentStudy(forceRegenerate: Bool = false) async {
        if !forceRegenerate {
            if let cached = await coreService.fullDocumentStudyService.getCachedAnalysis(documentID: document.id) {
                self.fullDocumentAnalysis = cached
                return
            }
        }
        
        isAnalyzingFullDocument = true
        isExtractingBatch = true
        batchExtractionProgress = BatchExtractionProgress(
            processedPages: 0,
            totalPages: max(1, document.pageCount),
            currentBatchIndex: 0,
            totalBatches: max(1, (document.pageCount + 9) / 10),
            percentage: 0.0,
            isCompleted: false
        )
        
        // 1. 尝试触发长文档异步分批抽取引擎以获取精确进度与文本结构
        let fileURL: URL
        let path = document.localFileRef
        if let parsedURL = URL(string: path), parsedURL.scheme != nil {
            fileURL = parsedURL
        } else {
            fileURL = URL(fileURLWithPath: path)
        }
        
        let batchConfig = BatchExtractionConfig(
            batchSize: 10,
            maxConcurrentBatches: 2,
            timeoutPerBatch: 30.0,
            extractImages: false,
            startPageIndex0: 0,
            endPageIndex0: max(0, document.pageCount - 1)
        )
        
        do {
            _ = try await coreService.batchExtractionEngine.extractDocument(
                documentID: document.id,
                fileURL: fileURL,
                config: batchConfig
            ) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.batchExtractionProgress = progress
                }
            }
            self.isExtractingBatch = false
            
            // 2. 触发全文学习分析服务生成核心概念网络、考点与知识拓扑
            let analysis = try await coreService.fullDocumentStudyService.generateFullDocumentStudy(
                documentID: document.id,
                options: nil
            )
            self.fullDocumentAnalysis = analysis
            self.isAnalyzingFullDocument = false
            displayToast("全文学习研读分析已完成")
        } catch is CancellationError {
            self.isExtractingBatch = false
            self.isAnalyzingFullDocument = false
            displayToast("全文研读抽取已取消")
        } catch {
            self.isExtractingBatch = false
            self.isAnalyzingFullDocument = false
            let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            displayToast("全文研读失败: \(msg)")
        }
    }
    
    public func cancelFullDocumentStudy() async {
        _ = await coreService.batchExtractionEngine.cancelExtraction(documentID: document.id)
        _ = await coreService.fullDocumentStudyService.cancelAnalysis(documentID: document.id)
        self.isExtractingBatch = false
        self.isAnalyzingFullDocument = false
        displayToast("已取消全文研读任务")
    }
    
    // MARK: - M3-UI: AI Notes 卡片沉淀与管理 (R11 P1)
    public func loadAINotes() async {
        do {
            let list = try await coreService.aiNoteService.listAINotes(documentID: document.id)
            self.aiNotes = list
        } catch {
            // 静默处理加载失败
        }
    }
    
    public func saveAINoteFromAIResult(
        title: String? = nil,
        markdownContent: String,
        anchors: [SourceAnchor] = [],
        tags: [String] = []
    ) async {
        let noteTitle: String
        if let t = title, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            noteTitle = t
        } else {
            let firstLine = markdownContent.components(separatedBy: "\n").first ?? ""
            let cleaned = firstLine.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).trimmingCharacters(in: .whitespacesAndNewlines)
            noteTitle = cleaned.isEmpty ? "AI 研读笔记 - \(document.title)" : String(cleaned.prefix(25))
        }
        
        let validAnchors: [SourceAnchor]
        if !anchors.isEmpty {
            validAnchors = anchors
        } else {
            validAnchors = [
                SourceAnchor(
                    documentID: document.id,
                    documentRevision: document.revision,
                    pageIndex0: adapter.currentPageIndex0,
                    precision: .page
                )
            ]
        }
        
        let snapshot = AINoteSourceSnapshot(
            documentID: document.id,
            documentRevision: document.revision,
            sourceAnchors: validAnchors,
            originKind: .document,
            aiOrigin: AIOrigin(
                requestID: activeRequestID ?? UUID().uuidString,
                attemptID: activeAttemptID ?? UUID().uuidString,
                prompt: "digest_\(Date().timeIntervalSince1970)"
            )
        )
        
        let card = AINoteCard(
            title: noteTitle,
            markdownContent: markdownContent,
            sourceSnapshot: snapshot,
            inclusionPolicy: .independent,
            tags: tags
        )
        
        do {
            let created = try await coreService.aiNoteService.createAINote(card: card)
            self.aiNotes.insert(created, at: 0)
            displayToast("已成功沉淀为 AI 笔记")
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            displayToast("保存 AI 笔记失败: \(msg)")
        }
    }
    
    public func saveAINoteFromMessage(_ message: AIMessageItem) async {
        guard !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        await saveAINoteFromAIResult(
            title: "问答笔记: \(String(message.text.prefix(16)))",
            markdownContent: message.text,
            anchors: message.sources,
            tags: ["问答沉淀", "AI助学"]
        )
    }
    
    public func saveAINoteFromFullStudy(_ analysis: FullDocumentAnalysis) async {
        var markdown = "# 全文研读报告: \(analysis.title)\n\n"
        markdown += "\(analysis.overview)\n\n"
        if !analysis.concepts.isEmpty {
            markdown += "## 核心概念\n"
            for c in analysis.concepts {
                markdown += "- **\(c.name)**: \(c.summary)\n"
            }
            markdown += "\n"
        }
        if !analysis.difficultyPoints.isEmpty {
            markdown += "## 重点难点\n"
            for d in analysis.difficultyPoints {
                markdown += "- **\(d.title)**: \(d.description)\n  *攻关策略*: \(d.suggestedStrategy)\n"
            }
        }
        
        var allAnchors: [SourceAnchor] = []
        for c in analysis.concepts { allAnchors.append(contentsOf: c.sourceAnchors) }
        for d in analysis.difficultyPoints { allAnchors.append(contentsOf: d.sourceAnchors) }
        
        await saveAINoteFromAIResult(
            title: "全文研读: \(analysis.title)",
            markdownContent: markdown,
            anchors: allAnchors,
            tags: ["全文导读", "知识拓扑"]
        )
    }
    
    public func deleteAINote(id: String) async {
        do {
            _ = try await coreService.aiNoteService.deleteAINote(id: id)
            self.aiNotes.removeAll { $0.id == id }
            displayToast("已删除 AI 笔记")
        } catch {
            displayToast("删除失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - M3-UI: 端侧离线模型状态与控制 (R14)
    public func checkLocalLLMStatus() async {
        guard let localProvider = coreService.localLLMProvider else {
            self.localModelStatus = nil
            return
        }
        self.localModelStatus = await localProvider.inferenceStatus
    }
    
    public func loadLocalModel() async {
        guard let localProvider = coreService.localLLMProvider else { return }
        do {
            try await localProvider.loadModel()
            self.localModelStatus = await localProvider.inferenceStatus
            displayToast("端侧离线模型就绪")
        } catch {
            displayToast("离线模型加载失败: \(error.localizedDescription)")
        }
    }
    
    public func unloadLocalModel() async {
        guard let localProvider = coreService.localLLMProvider else { return }
        await localProvider.unloadModel()
        self.localModelStatus = await localProvider.inferenceStatus
        displayToast("端侧模型已释放")
    }

    // MARK: - M4-BE: 弱网重试恢复与端侧离线资源管理 (R12, R14)
    
    /// 刷新网络连通性、弹性重试统计与离线模型资源包
    public func refreshNetworkAndOfflineResilience() async {
        // 1. 读取网络弹性重试引擎统计 (R12)
        let stats = await coreService.networkRetryEngine.getStats()
        self.retryEngineStats = stats
        
        // 2. 读取端侧离线资源管理器已注册的离线模型包列表 (R14)
        let packages = await coreService.offlineResourceManager.listPackages()
        self.offlinePackages = packages
        
        // 3. 评估网络连通性与热降级调度状态
        if let packageManager = coreService.localModelPackageManager {
            let net = await packageManager.networkState
            let decision = await packageManager.evaluateFallback(preferredLocalPackageID: nil)
            
            switch decision {
            case .useCloud:
                self.networkResilienceState = .cloudAvailable
            case .fallbackToLocal(let reason):
                let activePkg = await packageManager.getActivePackage()
                let name = activePkg?.modelName ?? "端侧 CoreML"
                self.networkResilienceState = .switchedToLocal(modelName: "\(name) (\(reason))")
            case .failImmediately(let reason):
                if net == .unreachable {
                    self.networkResilienceState = .offlineUnavailable(reason: reason.isEmpty ? "网络已断开且无就绪离线模型" : reason)
                } else {
                    self.networkResilienceState = .cloudAvailable
                }
            }
        } else {
            self.networkResilienceState = .cloudAvailable
        }
    }
    
    /// 走查辅助：切换网络模拟状态 (用于真机走查与弱网恢复测试)
    public func updateSimulatedNetworkState(_ state: NetworkReachabilityState) async {
        if let packageManager = coreService.localModelPackageManager {
            await packageManager.updateNetworkState(state)
            await refreshNetworkAndOfflineResilience()
            displayToast("网络状态已更新为: \(state.rawValue)")
        }
    }
    
    /// 走查辅助：注册并校验端侧模型包 (完整性 SHA-256 检验)
    public func verifyAndRegisterModelPackage(_ metadata: ModelPackageMetadata) async -> PackageIntegrityResult? {
        do {
            try await coreService.offlineResourceManager.registerPackage(metadata)
            let result = try await coreService.offlineResourceManager.verifyPackageIntegrity(packageID: metadata.packageID)
            await refreshNetworkAndOfflineResilience()
            return result
        } catch {
            displayToast("模型包校验失败: \(error.localizedDescription)")
            return nil
        }
    }

    public func displayToast(_ message: String) {
        self.toastMessage = message
        self.showToast = true
    }
}
