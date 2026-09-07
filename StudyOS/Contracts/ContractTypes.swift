import Foundation

/// 墨水异步持久化错误类型 (UIREV-03, 契约对齐)
public enum SaveInkError: Error, Sendable, Hashable {
    case conflict(currentRevision: Int)
    case storageFull
    case saveFailed(String)
    case staleReference
    case unavailable
    case timeout
    case cancelled
}

/// 阅读器工具态 (UIREV-04)
public enum ReaderToolMode: String, Codable, Sendable {
    case reading          // 纯阅读模式 (手指滚动/翻页，Pencil 触碰默认书写)
    case textSelection    // 文本选择模式 (手指/Pencil 精准选词选句，抑制墨水)
    case annotation       // 显式批注模式 (PKToolPicker 处于激活态)
}

/// 文档删除时关联笔记处理策略（强制二选一，无默认值）
public enum NotePolicy: String, Codable, Sendable {
    case keep    // 保留笔记文字与图片副本，解绑归属，标为 documentDeleted 不可导航
    case delete  // 连带删除关联笔记
}

/// 文档删除影响预览
public struct DeleteImpact: Identifiable, Codable, Sendable {
    public var id: String { impactID }

    public let impactID: String
    public let documentID: String
    public let documentRevision: Int
    public let originalFileCount: Int
    public let indexCount: Int
    public let annotationCount: Int
    public let inkCount: Int
    public let sessionCount: Int
    public let associatedNoteCount: Int
    public let associatedImageCount: Int

    public init(
        impactID: String = UUID().uuidString,
        documentID: String,
        documentRevision: Int,
        originalFileCount: Int = 1,
        indexCount: Int = 0,
        annotationCount: Int = 0,
        inkCount: Int = 0,
        sessionCount: Int = 0,
        associatedNoteCount: Int = 0,
        associatedImageCount: Int = 0
    ) {
        self.impactID = impactID
        self.documentID = documentID
        self.documentRevision = documentRevision
        self.originalFileCount = originalFileCount
        self.indexCount = indexCount
        self.annotationCount = annotationCount
        self.inkCount = inkCount
        self.sessionCount = sessionCount
        self.associatedNoteCount = associatedNoteCount
        self.associatedImageCount = associatedImageCount
    }
}

/// 文档删除执行结果
public enum DeleteResult: Codable, Sendable {
    case completed(
        policy: NotePolicy,
        deletedCounts: [String: Int],
        retainedNoteIDs: [String]
    )
    case cleanupPending(
        policy: NotePolicy,
        deletedCounts: [String: Int],
        retainedNoteIDs: [String],
        pendingFileCount: Int,
        retryToken: String
    )
}

/// 书签领域记录
public struct Bookmark: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let documentID: String
    public var anchor: SourceAnchor
    public var label: String
    public var revision: Int
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        documentID: String,
        anchor: SourceAnchor,
        label: String,
        revision: Int = 1,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.documentID = documentID
        self.anchor = anchor
        self.label = label
        self.revision = revision
        self.createdAt = createdAt
    }
}

/// 阅读器快照
public struct ReaderSnapshot: Codable, Sendable {
    public let documentID: String
    public let pageCount: Int
    public let chapters: [Chapter]
    public let bookmarks: [Bookmark]
    public let readingPosition: ReadingPosition?
    public let indexState: IndexState

    public init(
        documentID: String,
        pageCount: Int,
        chapters: [Chapter] = [],
        bookmarks: [Bookmark] = [],
        readingPosition: ReadingPosition? = nil,
        indexState: IndexState = .none
    ) {
        self.documentID = documentID
        self.pageCount = pageCount
        self.chapters = chapters
        self.bookmarks = bookmarks
        self.readingPosition = readingPosition
        self.indexState = indexState
    }
}

/// PDF 目录大纲树节点
public struct OutlineNode: Identifiable, Codable, Sendable {
    public var id: String { "\(pageIndex0)_\(title)" }
    public let title: String
    public let pageIndex0: Int
    public var children: [OutlineNode]

    public init(title: String, pageIndex0: Int, children: [OutlineNode] = []) {
        self.title = title
        self.pageIndex0 = pageIndex0
        self.children = children
    }
}

/// 检索匹配结果条目
public struct SearchResultItem: Identifiable, Codable, Sendable {
    public var id: String { anchor.quote ?? "\(anchor.pageIndex0)_\(excerpt.prefix(10))" }
    public let anchor: SourceAnchor
    public let excerpt: String
    public let score: Double

    public init(anchor: SourceAnchor, excerpt: String, score: Double = 1.0) {
        self.anchor = anchor
        self.excerpt = excerpt
        self.score = score
    }
}
