import Foundation

/// AI 笔记在原文档被删除时的保留策略 (两路删除联动)
public enum AINoteInclusionPolicy: String, Codable, Sendable, Hashable {
    /// 独立保留：解除文档归属并标记来源锚点失效，保留完整卡片笔记内容
    case independent
    /// 绑定文档：随同文档一并级联删除
    case boundToDocument
}

/// AI 笔记来源快照 (AINoteSourceSnapshot)
public struct AINoteSourceSnapshot: Codable, Sendable, Hashable {
    public var documentID: String?
    public var documentRevision: Int?
    public var sourceAnchors: [SourceAnchor]
    public var originKind: AIOriginKind
    public var aiOrigin: AIOrigin?

    public init(
        documentID: String? = nil,
        documentRevision: Int? = nil,
        sourceAnchors: [SourceAnchor] = [],
        originKind: AIOriginKind = .document,
        aiOrigin: AIOrigin? = nil
    ) {
        self.documentID = documentID
        self.documentRevision = documentRevision
        self.sourceAnchors = sourceAnchors
        self.originKind = originKind
        self.aiOrigin = aiOrigin
    }
}

/// R11 AI Notes 卡片笔记模型 (AINoteCard)
public struct AINoteCard: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public var title: String
    public var markdownContent: String
    public var sourceSnapshot: AINoteSourceSnapshot
    public var inclusionPolicy: AINoteInclusionPolicy
    public var tags: [String]
    public var revision: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        markdownContent: String,
        sourceSnapshot: AINoteSourceSnapshot,
        inclusionPolicy: AINoteInclusionPolicy = .independent,
        tags: [String] = [],
        revision: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.markdownContent = markdownContent
        self.sourceSnapshot = sourceSnapshot
        self.inclusionPolicy = inclusionPolicy
        self.tags = tags
        self.revision = revision
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 转换为通用 Note 记录以无缝兼容原有笔记持久化与查询体系
    public func toNote() -> Note {
        Note(
            id: id,
            documentID: sourceSnapshot.documentID,
            chapterID: nil,
            editableText: "# \(title)\n\n\(markdownContent)",
            imageRefs: [],
            sourceAnchors: sourceSnapshot.sourceAnchors,
            aiOrigin: sourceSnapshot.aiOrigin,
            revision: revision,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// 从通用 Note 记录反向重构卡片
    public static func from(note: Note, inclusionPolicy: AINoteInclusionPolicy = .independent) -> AINoteCard {
        let lines = note.editableText.components(separatedBy: "\n")
        let firstLine = lines.first ?? ""
        let title: String
        let markdownContent: String

        if firstLine.hasPrefix("#") {
            title = firstLine.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).trimmingCharacters(in: .whitespacesAndNewlines)
            markdownContent = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            title = "笔记"
            markdownContent = note.editableText
        }

        let snapshot = AINoteSourceSnapshot(
            documentID: note.documentID,
            documentRevision: nil,
            sourceAnchors: note.sourceAnchors,
            originKind: note.aiOrigin != nil ? .document : .general,
            aiOrigin: note.aiOrigin
        )

        return AINoteCard(
            id: note.id,
            title: title.isEmpty ? "未命名笔记" : title,
            markdownContent: markdownContent,
            sourceSnapshot: snapshot,
            inclusionPolicy: inclusionPolicy,
            tags: [],
            revision: note.revision,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt
        )
    }
}

/// R11 AI Notes 管理服务契约 (AINoteServiceProtocol)
public protocol AINoteServiceProtocol: Sendable {
    /// 一键将助学内容固化为卡片笔记
    func createAINote(card: AINoteCard) async throws -> AINoteCard

    /// 更新卡片笔记（带版本冲突检查）
    func updateAINote(card: AINoteCard, expectedRevision: Int) async throws -> AINoteCard

    /// 列出卡片笔记（支持按文档 ID 过滤）
    func listAINotes(documentID: String?) async throws -> [AINoteCard]

    /// 获取单个卡片笔记
    func getAINote(id: String) async throws -> AINoteCard?

    /// 删除单个卡片笔记
    func deleteAINote(id: String) async throws -> Bool

    /// 处理文档删除时的两路策略联动
    func handleDocumentDeletion(
        documentID: String,
        policy: NotePolicy
    ) async throws -> (retainedCardIDs: [String], deletedCardIDs: [String])
}
