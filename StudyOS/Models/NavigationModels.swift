import Foundation

/// 来源定位目标（仅由 resolveSource 成功产生）
public struct NavigationTarget: Codable, Sendable, Hashable {
    public let documentID: String
    public let documentRevision: Int
    public let pageIndex0: Int
    public var regions: [CodableRect]
    public var precision: AnchorPrecision
    public var resolvedFromAnchor: SourceAnchor

    public init(
        documentID: String,
        documentRevision: Int,
        pageIndex0: Int,
        regions: [CodableRect] = [],
        precision: AnchorPrecision = .region,
        resolvedFromAnchor: SourceAnchor
    ) {
        self.documentID = documentID
        self.documentRevision = documentRevision
        self.pageIndex0 = pageIndex0
        self.regions = regions
        self.precision = precision
        self.resolvedFromAnchor = resolvedFromAnchor
    }
}

/// 核心服务对 SourceAnchor 的解析结果
public enum SourceResolution: Sendable, Hashable {
    case navigationTarget(NavigationTarget)
    case staleReference
    case unavailable
}

/// 客户端 UI 导航执行结果（核对会话与页面有效性后）
public enum NavigationResult: Sendable, Hashable {
    case success
    case staleReference
    case unavailable
    case invalidPageIndex
    case ignoredStaleSession
}
