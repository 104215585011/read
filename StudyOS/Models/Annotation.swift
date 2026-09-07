import Foundation

/// 批注类型
public enum AnnotationKind: String, Codable, Sendable {
    case highlight
    case underline
    case text
}

/// 批注领域记录
public struct Annotation: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public var kind: AnnotationKind
    public var anchor: SourceAnchor
    public var content: String
    public var revision: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        kind: AnnotationKind,
        anchor: SourceAnchor,
        content: String = "",
        revision: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.anchor = anchor
        self.content = content
        self.revision = revision
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
