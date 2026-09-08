import Foundation

/// 知识关系连接 (KnowledgeRelation)
public struct KnowledgeRelation: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let sourceConceptID: String
    public let targetConceptID: String
    public let relationType: String // e.g. "prerequisite", "derivesFrom", "contrastsWith", "appliesTo"
    public let description: String

    public init(
        id: String = UUID().uuidString,
        sourceConceptID: String,
        targetConceptID: String,
        relationType: String,
        description: String
    ) {
        self.id = id
        self.sourceConceptID = sourceConceptID
        self.targetConceptID = targetConceptID
        self.relationType = relationType
        self.description = description
    }
}

/// 核心概念节点 (ConceptNode)
public struct ConceptNode: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let summary: String
    public let importance: Double // 0.0 ~ 1.0
    public var sourceAnchors: [SourceAnchor]

    public init(
        id: String = UUID().uuidString,
        name: String,
        summary: String,
        importance: Double = 1.0,
        sourceAnchors: [SourceAnchor] = []
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.importance = importance
        self.sourceAnchors = sourceAnchors
    }
}

/// 核心难点与考点解析 (DifficultyPoint)
public struct DifficultyPoint: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let description: String
    public let suggestedStrategy: String
    public var sourceAnchors: [SourceAnchor]

    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        suggestedStrategy: String,
        sourceAnchors: [SourceAnchor] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.suggestedStrategy = suggestedStrategy
        self.sourceAnchors = sourceAnchors
    }
}

/// 关键小节研读指引 (KeySectionGuide)
public struct KeySectionGuide: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let chapterID: String?
    public let title: String
    public let startPageIndex0: Int
    public let endPageIndex0: Int
    public let keyTakeaways: [String]
    public var anchor: SourceAnchor

    public init(
        id: String = UUID().uuidString,
        chapterID: String? = nil,
        title: String,
        startPageIndex0: Int,
        endPageIndex0: Int,
        keyTakeaways: [String] = [],
        anchor: SourceAnchor
    ) {
        self.id = id
        self.chapterID = chapterID
        self.title = title
        self.startPageIndex0 = startPageIndex0
        self.endPageIndex0 = endPageIndex0
        self.keyTakeaways = keyTakeaways
        self.anchor = anchor
    }
}

/// 全文学习分析报告 (FullDocumentAnalysis) - R10 全文学习视图领域模型
public struct FullDocumentAnalysis: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let documentID: String
    public let documentRevision: Int
    public let title: String
    public let overview: String
    public var readingEstimate: ReadingEstimate?
    public var concepts: [ConceptNode]
    public var relations: [KnowledgeRelation]
    public var difficultyPoints: [DifficultyPoint]
    public var keySections: [KeySectionGuide]
    public let analyzedAt: Date

    public init(
        id: String = UUID().uuidString,
        documentID: String,
        documentRevision: Int = 1,
        title: String,
        overview: String,
        readingEstimate: ReadingEstimate? = nil,
        concepts: [ConceptNode] = [],
        relations: [KnowledgeRelation] = [],
        difficultyPoints: [DifficultyPoint] = [],
        keySections: [KeySectionGuide] = [],
        analyzedAt: Date = Date()
    ) {
        self.id = id
        self.documentID = documentID
        self.documentRevision = documentRevision
        self.title = title
        self.overview = overview
        self.readingEstimate = readingEstimate
        self.concepts = concepts
        self.relations = relations
        self.difficultyPoints = difficultyPoints
        self.keySections = keySections
        self.analyzedAt = analyzedAt
    }
}

/// 全文学习分析协议 (FullDocumentStudyProtocol)
public protocol FullDocumentStudyProtocol: Sendable {
    /// 触发全文学习分析
    func generateFullDocumentStudy(
        documentID: String,
        options: LLMCompletionOptions?
    ) async throws -> FullDocumentAnalysis

    /// 获取已缓存的全文研读报告
    func getCachedAnalysis(documentID: String) async -> FullDocumentAnalysis?

    /// 保存全文研读报告
    func saveAnalysis(_ analysis: FullDocumentAnalysis) async throws

    /// 取消正在进行的全文分析
    func cancelAnalysis(documentID: String) async -> Bool
}
