import Foundation

/// 笔记管理服务实现 (Actor 隔离)
public actor NoteService: NoteServiceProtocol {
    private let metadataEngine: MetadataStorageEngine

    public init(metadataEngine: MetadataStorageEngine) {
        self.metadataEngine = metadataEngine
    }

    /// 创建或保存笔记（支持乐观锁冲突校验）
    public func saveNote(_ note: Note, expectedRevision: Int) async throws -> Note {
        try await metadataEngine.saveNote(note, expectedRevision: expectedRevision)
    }

    /// 更新已有笔记
    public func updateNote(_ note: Note, expectedRevision: Int) async throws -> Note {
        try await metadataEngine.saveNote(note, expectedRevision: expectedRevision)
    }

    /// 获取笔记列表（支持按文档 ID 过滤）
    public func listNotes(documentID: String? = nil) async throws -> [Note] {
        await metadataEngine.listNotes(documentID: documentID)
    }

    /// 获取单条笔记
    public func getNote(id: String) async throws -> Note? {
        await metadataEngine.getNote(id: id)
    }

    /// 删除笔记
    public func deleteNote(id: String) async throws -> Bool {
        await metadataEngine.deleteNote(id: id)
    }
}
