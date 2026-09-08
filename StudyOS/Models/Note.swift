import Foundation

/// AI 派生来源信息
public struct AIOrigin: Codable, Sendable, Hashable {
    public let requestID: String
    public let attemptID: String
    public let prompt: String?
    public let generatedAt: Date

    public init(
        requestID: String = UUID().uuidString,
        attemptID: String = UUID().uuidString,
        prompt: String? = nil,
        generatedAt: Date = Date()
    ) {
        self.requestID = requestID
        self.attemptID = attemptID
        self.prompt = prompt
        self.generatedAt = generatedAt
    }

    public init(
        attemptID: String,
        profileID: String? = nil,
        promptSnapshot: String? = nil,
        generatedAt: Date = Date()
    ) {
        self.requestID = profileID ?? UUID().uuidString
        self.attemptID = attemptID
        self.prompt = promptSnapshot
        self.generatedAt = generatedAt
    }

    public init(
        requestID: String,
        promptDigest: String? = nil,
        modelProfile: String? = nil,
        generatedAt: Date = Date()
    ) {
        self.requestID = requestID
        self.attemptID = modelProfile ?? UUID().uuidString
        self.prompt = promptDigest
        self.generatedAt = generatedAt
    }
}

/// 笔记领域记录
public struct Note: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public var documentID: String?
    public var chapterID: String?
    public var editableText: String
    public var imageRefs: [String]
    public var sourceAnchors: [SourceAnchor]
    public var aiOrigin: AIOrigin?
    public var revision: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        documentID: String? = nil,
        chapterID: String? = nil,
        editableText: String = "",
        imageRefs: [String] = [],
        sourceAnchors: [SourceAnchor] = [],
        aiOrigin: AIOrigin? = nil,
        revision: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.documentID = documentID
        self.chapterID = chapterID
        self.editableText = editableText
        self.imageRefs = imageRefs
        self.sourceAnchors = sourceAnchors
        self.aiOrigin = aiOrigin
        self.revision = revision
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
