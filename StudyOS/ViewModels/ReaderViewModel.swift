import Foundation
import SwiftUI
import Combine

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
    
    // MARK: - AI 解释与问答
    public func requestAIExplanation(for anchor: SourceAnchor) {
        selectionAnchor = nil
        selectionScreenRect = nil
        adapter.clearCurrentSelection()
        
        isAISidebarOpen = true
        currentScope = .selection(anchor: anchor)
        
        let promptQuote = anchor.quote ?? "选定文本"
        let userMsg = AIMessageItem(isUser: true, text: "解释选区: “\(promptQuote)”")
        messages.append(userMsg)
        
        isAIGenerating = true
        // 模拟 AI 助学流式解析响应
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            let answerText = "该段落主要阐述了核心概念的核心机制。在上下文语境中，它强调了多层抽象与边界隔离的关键设计原则。"
            let aiMsg = AIMessageItem(
                isUser: false,
                text: answerText,
                sources: [anchor]
            )
            self.messages.append(aiMsg)
            self.isAIGenerating = false
        }
    }
    
    public func sendQuestion() {
        let text = askInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        askInputText = ""
        let userMsg = AIMessageItem(isUser: true, text: text)
        messages.append(userMsg)
        
        isAIGenerating = true
        Task {
            try? await Task.sleep(nanoseconds: 750_000_000)
            let responseText = "基于当前文档第 \(adapter.currentPageIndex0 + 1) 页内容分析：\(text) 在系统设计中起到桥梁解耦作用。"
            let currentAnchor = SourceAnchor(
                documentID: document.id,
                documentRevision: document.revision,
                pageIndex0: adapter.currentPageIndex0,
                precision: .page
            )
            let aiMsg = AIMessageItem(isUser: false, text: responseText, sources: [currentAnchor])
            self.messages.append(aiMsg)
            self.isAIGenerating = false
        }
    }
    
    public func cancelAIGeneration() {
        isAIGenerating = false
        if let last = messages.last, !last.isUser {
            displayToast("已终止生成")
        }
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
