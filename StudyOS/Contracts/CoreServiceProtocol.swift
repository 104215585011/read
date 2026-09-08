import Foundation

/// 文档生命周期管理服务协议
public protocol DocumentServiceProtocol: Sendable {
    func importPDF(fileURL: URL, operationID: String) async throws -> Document
    func unlockDocument(documentID: String, password: String) async throws -> Bool
    func listDocuments() async throws -> [Document]
    func getDocument(id: String) async throws -> Document?
    func previewDeleteDocument(documentID: String, revision: Int) async throws -> DeleteImpact
    func deleteDocument(
        documentID: String,
        expectedRevision: Int,
        notePolicy: NotePolicy,
        confirmedImpactID: String,
        operationID: String
    ) async throws -> DeleteResult
}

/// 阅读器核心与导航/笔迹协议
public protocol ReaderCoreServiceProtocol: Sendable {
    func getReaderSnapshot(documentID: String) async throws -> ReaderSnapshot
    func savePosition(_ position: ReadingPosition) async throws -> Bool
    func resolveSource(_ anchor: SourceAnchor) async -> SourceResolution
    func loadInk(pageKey: PageKey) async throws -> InkPage?
    func flushInk(snapshot: InkSaveSnapshot) async -> Result<InkSaveReceipt, SaveInkError>
    func createBookmark(documentID: String, anchor: SourceAnchor, label: String, operationID: String) async throws -> Bookmark
    func updateBookmark(bookmark: Bookmark, expectedRevision: Int) async throws -> Bookmark
    func deleteBookmark(bookmarkID: String, expectedRevision: Int) async throws -> Bool
    func createAnnotation(annotation: Annotation, expectedRevision: Int) async throws -> Annotation
    func updateAnnotation(annotation: Annotation, expectedRevision: Int) async throws -> Annotation
}

/// 笔记管理服务协议
public protocol NoteServiceProtocol: Sendable {
    func saveNote(_ note: Note, expectedRevision: Int) async throws -> Note
    func updateNote(_ note: Note, expectedRevision: Int) async throws -> Note
    func listNotes(documentID: String?) async throws -> [Note]
    func getNote(id: String) async throws -> Note?
    func deleteNote(id: String) async throws -> Bool
}

/// 核心聚合服务门面协议 (CoreServiceProtocol)
public protocol CoreServiceProtocol: Sendable {
    var documentService: DocumentServiceProtocol { get }
    var readerCoreService: ReaderCoreServiceProtocol { get }
    var noteService: NoteServiceProtocol { get }
    var aiService: AIServiceProtocol { get }
    var batchExtractionEngine: BatchExtractionProtocol { get }
    var aiNoteService: AINoteServiceProtocol { get }
    var localLLMProvider: LocalLLMProviderProtocol? { get }
    var fullDocumentStudyService: FullDocumentStudyProtocol { get }

    func resolveSource(_ anchor: SourceAnchor) async -> SourceResolution
    func flushInk(snapshot: InkSaveSnapshot) async -> Result<InkSaveReceipt, SaveInkError>
    func savePosition(_ position: ReadingPosition) async throws -> Bool
}
