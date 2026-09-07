import Foundation

/// 外发项目类型
public enum OutboundItemKind: String, Codable, Sendable {
    case documentText
    case questionText
    case conversationText
    case annotationText
    case originalPDF
    case pageImage
    case handwritingImage
    case systemText
}

/// 外发用途
public enum OutboundPurpose: String, Codable, Sendable {
    case generation
    case embedding
    case vision
}

/// 包含状态
public enum InclusionStatus: Codable, Sendable, Hashable {
    case included(itemIDs: [String])
    case excluded(reason: String)
}

/// Provider 快照信息
public struct ProviderSnapshot: Codable, Sendable, Hashable {
    public let profileID: String
    public let configRevision: Int
    public let endpoint: String
    public let model: String

    public init(
        profileID: String,
        configRevision: Int = 1,
        endpoint: String,
        model: String
    ) {
        self.profileID = profileID
        self.configRevision = configRevision
        self.endpoint = endpoint
        self.model = model
    }
}

/// 外发条目详情
public struct OutboundItem: Identifiable, Codable, Sendable, Hashable {
    public var id: String { itemID }

    public let itemID: String
    public let kind: OutboundItemKind
    public let purpose: OutboundPurpose
    public var sourceIDs: [String]
    public var pageCoverage: [Int]
    public var payloadDigest: String
    public var byteCount: Int
    public var characterCount: Int?
    public var imageCount: Int?
    public var containsHandwriting: Bool

    public init(
        itemID: String = UUID().uuidString,
        kind: OutboundItemKind,
        purpose: OutboundPurpose,
        sourceIDs: [String] = [],
        pageCoverage: [Int] = [],
        payloadDigest: String,
        byteCount: Int,
        characterCount: Int? = nil,
        imageCount: Int? = nil,
        containsHandwriting: Bool = false
    ) {
        self.itemID = itemID
        self.kind = kind
        self.purpose = purpose
        self.sourceIDs = sourceIDs
        self.pageCoverage = pageCoverage
        self.payloadDigest = payloadDigest
        self.byteCount = byteCount
        self.characterCount = characterCount
        self.imageCount = imageCount
        self.containsHandwriting = containsHandwriting
    }
}

/// 外发上下文清单与确认绑定
public struct ContextManifest: Identifiable, Codable, Sendable {
    public var id: String { manifestID }

    public let manifestID: String
    public var manifestRevision: Int
    public let documentID: String
    public let documentRevision: Int
    public var operationKind: String
    public var providerSnapshot: ProviderSnapshot
    public var outboundItems: [OutboundItem]
    public var originalFileInclusion: InclusionStatus
    public var pageImageInclusion: InclusionStatus
    public var handwritingInclusion: InclusionStatus
    public var annotationInclusion: InclusionStatus
    public var estimatedInputTokens: Int
    public var reservedOutputTokens: Int
    public var truncationReasons: [String]
    public var scopeSnapshot: String
    public var evidenceIDs: [String]
    public var pageCoverage: [Int]

    public init(
        manifestID: String = UUID().uuidString,
        manifestRevision: Int = 1,
        documentID: String,
        documentRevision: Int,
        operationKind: String,
        providerSnapshot: ProviderSnapshot,
        outboundItems: [OutboundItem] = [],
        originalFileInclusion: InclusionStatus = .excluded(reason: "默认不外发原始PDF"),
        pageImageInclusion: InclusionStatus = .excluded(reason: "未选中图像"),
        handwritingInclusion: InclusionStatus = .excluded(reason: "默认不外发手写"),
        annotationInclusion: InclusionStatus = .excluded(reason: "未选中批注"),
        estimatedInputTokens: Int = 0,
        reservedOutputTokens: Int = 0,
        truncationReasons: [String] = [],
        scopeSnapshot: String = "",
        evidenceIDs: [String] = [],
        pageCoverage: [Int] = []
    ) {
        self.manifestID = manifestID
        self.manifestRevision = manifestRevision
        self.documentID = documentID
        self.documentRevision = documentRevision
        self.operationKind = operationKind
        self.providerSnapshot = providerSnapshot
        self.outboundItems = outboundItems
        self.originalFileInclusion = originalFileInclusion
        self.pageImageInclusion = pageImageInclusion
        self.handwritingInclusion = handwritingInclusion
        self.annotationInclusion = annotationInclusion
        self.estimatedInputTokens = estimatedInputTokens
        self.reservedOutputTokens = reservedOutputTokens
        self.truncationReasons = truncationReasons
        self.scopeSnapshot = scopeSnapshot
        self.evidenceIDs = evidenceIDs
        self.pageCoverage = pageCoverage
    }
}
