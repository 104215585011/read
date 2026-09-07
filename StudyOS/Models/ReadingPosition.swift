import Foundation

/// 阅读位置（进度是阅读位置，不是掌握度）
public struct ReadingPosition: Codable, Sendable, Hashable {
    public let documentID: String
    public let documentRevision: Int
    public var pageIndex0: Int
    public var pagePoint: CodablePoint
    public var zoomHint: Double?
    public var updatedAt: Date

    public init(
        documentID: String,
        documentRevision: Int,
        pageIndex0: Int,
        pagePoint: CodablePoint = CodablePoint(x: 0, y: 0),
        zoomHint: Double? = nil,
        updatedAt: Date = Date()
    ) {
        self.documentID = documentID
        self.documentRevision = documentRevision
        self.pageIndex0 = pageIndex0
        self.pagePoint = pagePoint
        self.zoomHint = zoomHint
        self.updatedAt = updatedAt
    }
}
