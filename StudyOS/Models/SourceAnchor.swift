import Foundation

/// 引用定位精度
public enum AnchorPrecision: String, Codable, Sendable {
    case page
    case region
}

/// 引用有效性状态
public enum AnchorAvailability: String, Codable, Sendable {
    case active
    case documentDeleted
}

/// 来源定位锚点
public struct SourceAnchor: Codable, Sendable, Hashable {
    public let documentID: String
    public let documentRevision: Int
    public let pageIndex0: Int
    public var regions: [CodableRect]
    public var paragraphID: String?
    public var quote: String?
    public var textRevision: Int?
    public var precision: AnchorPrecision
    public var availability: AnchorAvailability

    public init(
        documentID: String,
        documentRevision: Int,
        pageIndex0: Int,
        regions: [CodableRect] = [],
        paragraphID: String? = nil,
        quote: String? = nil,
        textRevision: Int? = nil,
        precision: AnchorPrecision = .region,
        availability: AnchorAvailability = .active
    ) {
        self.documentID = documentID
        self.documentRevision = documentRevision
        self.pageIndex0 = pageIndex0
        self.regions = regions
        self.paragraphID = paragraphID
        self.quote = quote
        self.textRevision = textRevision
        self.precision = precision
        self.availability = availability
    }
}
