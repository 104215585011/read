import Foundation

/// 导入状态
public enum ImportState: String, Codable, Sendable {
    case copying
    case validating
    case readable
    case needsPassword
    case failed
}

/// 索引状态
public enum IndexState: String, Codable, Sendable {
    case none
    case partial
    case ready
    case failed
}

/// 文档领域记录
public struct Document: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public var title: String
    public var sourceHash: String
    public var revision: Int
    public var localFileRef: String
    public var pageCount: Int
    public var importState: ImportState
    public var indexState: IndexState
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        sourceHash: String,
        revision: Int = 1,
        localFileRef: String,
        pageCount: Int = 0,
        importState: ImportState = .validating,
        indexState: IndexState = .none,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.sourceHash = sourceHash
        self.revision = revision
        self.localFileRef = localFileRef
        self.pageCount = pageCount
        self.importState = importState
        self.indexState = indexState
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
