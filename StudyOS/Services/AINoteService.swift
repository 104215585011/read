import Foundation

/// AI 笔记服务实现 (Actor 隔离)
/// 落实 R11 P1：助学内容一键沉淀为卡片笔记、乐观锁控制、与文档两路删除策略联动
public actor AINoteService: AINoteServiceProtocol {
    private let sandbox: LocalSandboxManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cards: [String: AINoteCard] = [:]

    public init(sandbox: LocalSandboxManager = .shared) {
        self.sandbox = sandbox
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.loadFromDisk()
    }

    /// 一键将助学内容固化为卡片笔记
    public func createAINote(card: AINoteCard) async throws -> AINoteCard {
        var newCard = card
        newCard.revision = 1
        newCard.createdAt = Date()
        newCard.updatedAt = Date()
        cards[newCard.id] = newCard
        persistToDisk()
        return newCard
    }

    /// 更新卡片笔记（带版本冲突检查）
    public func updateAINote(card: AINoteCard, expectedRevision: Int) async throws -> AINoteCard {
        guard let existing = cards[card.id] else {
            throw StorageError.notFound("AI Note card not found: \(card.id)")
        }
        guard existing.revision == expectedRevision else {
            throw StorageError.conflict(expectedRevision: expectedRevision, currentRevision: existing.revision)
        }

        var updated = card
        updated.revision = expectedRevision + 1
        updated.updatedAt = Date()
        cards[updated.id] = updated
        persistToDisk()
        return updated
    }

    /// 列出卡片笔记（支持按文档 ID 过滤）
    public func listAINotes(documentID: String? = nil) async throws -> [AINoteCard] {
        if let docID = documentID {
            return cards.values
                .filter { $0.sourceSnapshot.documentID == docID }
                .sorted { $0.updatedAt > $1.updatedAt }
        }
        return Array(cards.values).sorted { $0.updatedAt > $1.updatedAt }
    }

    /// 获取单个卡片笔记
    public func getAINote(id: String) async throws -> AINoteCard? {
        cards[id]
    }

    /// 删除单个卡片笔记
    public func deleteAINote(id: String) async throws -> Bool {
        guard cards.removeValue(forKey: id) != nil else { return false }
        persistToDisk()
        return true
    }

    /// 处理文档删除时的两路策略联动 (UIREV-06 / R11)
    public func handleDocumentDeletion(
        documentID: String,
        policy: NotePolicy
    ) async throws -> (retainedCardIDs: [String], deletedCardIDs: [String]) {
        var retainedCardIDs: [String] = []
        var deletedCardIDs: [String] = []

        let targetCards = cards.filter { $0.value.sourceSnapshot.documentID == documentID }

        switch policy {
        case .keep:
            // 保留卡片笔记，解除原文档绑定，将锚点可用性标记为 documentDeleted
            for (cardID, var card) in targetCards {
                card.sourceSnapshot.documentID = nil
                card.sourceSnapshot.sourceAnchors = card.sourceSnapshot.sourceAnchors.map { anchor in
                    var updatedAnchor = anchor
                    updatedAnchor.availability = .documentDeleted
                    return updatedAnchor
                }
                card.updatedAt = Date()
                cards[cardID] = card
                retainedCardIDs.append(cardID)
            }

        case .delete:
            // 连带删除关联卡片笔记
            for (cardID, _) in targetCards {
                cards.removeValue(forKey: cardID)
                deletedCardIDs.append(cardID)
            }
        }

        persistToDisk()
        return (retainedCardIDs, deletedCardIDs)
    }

    // MARK: - 本地沙盒原子写盘

    private func persistToDisk() {
        let fileURL = sandbox.metadataFileURL(fileName: "ai_notes")
        if let data = try? encoder.encode(cards) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func loadFromDisk() {
        let fileURL = sandbox.metadataFileURL(fileName: "ai_notes")
        guard let data = try? Data(contentsOf: fileURL),
              let loaded = try? decoder.decode([String: AINoteCard].self, from: data) else {
            return
        }
        self.cards = loaded
    }
}
