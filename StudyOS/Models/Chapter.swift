import Foundation

/// 章节来源
public enum ChapterSource: String, Codable, Sendable {
    case outline
    case inferred
    case manual
}

/// 章节领域记录
public struct Chapter: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let documentID: String
    public let documentRevision: Int
    public var title: String
    public var startPageIndex0: Int
    public var endPageIndex0: Int // inclusive
    public var source: ChapterSource
    public var confidence: Double

    public init(
        id: String = UUID().uuidString,
        documentID: String,
        documentRevision: Int,
        title: String,
        startPageIndex0: Int,
        endPageIndex0: Int,
        source: ChapterSource = .outline,
        confidence: Double = 1.0
    ) {
        self.id = id
        self.documentID = documentID
        self.documentRevision = documentRevision
        self.title = title
        self.startPageIndex0 = startPageIndex0
        self.endPageIndex0 = endPageIndex0
        self.source = source
        self.confidence = confidence
    }
}
