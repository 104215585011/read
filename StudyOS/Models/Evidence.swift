import Foundation

/// 证据领域记录（AI 输出仅引用本次证据 ID）
public struct Evidence: Identifiable, Codable, Sendable, Hashable {
    public var id: String { evidenceID }

    public let evidenceID: String
    public let anchor: SourceAnchor
    public var excerpt: String
    public var extractionMethod: ExtractionMethod

    public init(
        evidenceID: String = UUID().uuidString,
        anchor: SourceAnchor,
        excerpt: String,
        extractionMethod: ExtractionMethod = .native
    ) {
        self.evidenceID = evidenceID
        self.anchor = anchor
        self.excerpt = excerpt
        self.extractionMethod = extractionMethod
    }
}
