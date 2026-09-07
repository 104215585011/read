import Foundation

/// AI 范围定义
public enum AIScope: Codable, Sendable, Hashable {
    case selection(anchor: SourceAnchor)
    case page(index0: Int)
    case chapter(chapterID: String?, startPageIndex0: Int, endPageIndex0: Int)
    case document
}

/// AI 交互模式
public enum AIMode: String, Codable, Sendable {
    case guide
    case ask
    case studyView
}

/// AI 来源归属类型
public enum AIOriginKind: String, Codable, Sendable {
    case document
    case general
}

/// AI 请求终态状态
public enum AIResultStatus: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
    case cancelled
}

/// 阅读时间估算
public enum ReadingEstimate: Codable, Sendable, Hashable {
    case available(minutes: Int, basis: String, coverage: Double)
    case unavailable(reason: String)
}

/// AI 请求数据结构
public struct AIRequest: Codable, Sendable, Hashable {
    public let requestID: String
    public let attemptID: String
    public let documentID: String
    public let documentRevision: Int
    public let scope: AIScope
    public let mode: AIMode
    public var question: String?
    public var selectedAnchor: SourceAnchor?
    public var annotationIDs: [String]
    public var conversationID: String?
    public var providerProfileID: String

    public init(
        requestID: String = UUID().uuidString,
        attemptID: String = UUID().uuidString,
        documentID: String,
        documentRevision: Int,
        scope: AIScope,
        mode: AIMode,
        question: String? = nil,
        selectedAnchor: SourceAnchor? = nil,
        annotationIDs: [String] = [],
        conversationID: String? = nil,
        providerProfileID: String
    ) {
        self.requestID = requestID
        self.attemptID = attemptID
        self.documentID = documentID
        self.documentRevision = documentRevision
        self.scope = scope
        self.mode = mode
        self.question = question
        self.selectedAnchor = selectedAnchor
        self.annotationIDs = annotationIDs
        self.conversationID = conversationID
        self.providerProfileID = providerProfileID
    }
}

/// AI 结果数据结构
public struct AIResult: Codable, Sendable {
    public let requestID: String
    public let attemptID: String
    public let scopeSnapshot: String
    public var status: AIResultStatus
    public var content: String
    public var validatedSources: [SourceAnchor]
    public var coverage: Double
    public var origin: AIOriginKind
    public var readingEstimate: ReadingEstimate?
    public var createdAt: Date

    public init(
        requestID: String,
        attemptID: String,
        scopeSnapshot: String,
        status: AIResultStatus = .pending,
        content: String = "",
        validatedSources: [SourceAnchor] = [],
        coverage: Double = 0.0,
        origin: AIOriginKind = .document,
        readingEstimate: ReadingEstimate? = nil,
        createdAt: Date = Date()
    ) {
        self.requestID = requestID
        self.attemptID = attemptID
        self.scopeSnapshot = scopeSnapshot
        self.status = status
        self.content = content
        self.validatedSources = validatedSources
        self.coverage = coverage
        self.origin = origin
        self.readingEstimate = readingEstimate
        self.createdAt = createdAt
    }
}
