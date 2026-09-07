import Foundation

/// 文本提取方式
public enum ExtractionMethod: String, Codable, Sendable {
    case native
    case ocr
    case hybrid
}

/// 段落领域记录
public struct Paragraph: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let pageIndex0: Int
    public var text: String
    public var textRevision: Int
    public var regions: [CodableRect]
    public var order: Int
    public var extractionMethod: ExtractionMethod
    public var confidence: Double

    public init(
        id: String = UUID().uuidString,
        pageIndex0: Int,
        text: String,
        textRevision: Int = 1,
        regions: [CodableRect] = [],
        order: Int = 0,
        extractionMethod: ExtractionMethod = .native,
        confidence: Double = 1.0
    ) {
        self.id = id
        self.pageIndex0 = pageIndex0
        self.text = text
        self.textRevision = textRevision
        self.regions = regions
        self.order = order
        self.extractionMethod = extractionMethod
        self.confidence = confidence
    }
}
