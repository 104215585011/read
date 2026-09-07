import Foundation

/// 统一核心服务实现门面 (CoreService)
public final class CoreService: CoreServiceProtocol, Sendable {
    public let documentService: DocumentServiceProtocol
    public let readerCoreService: ReaderCoreServiceProtocol
    public let noteService: NoteServiceProtocol

    public init(
        documentService: DocumentServiceProtocol,
        readerCoreService: ReaderCoreServiceProtocol,
        noteService: NoteServiceProtocol
    ) {
        self.documentService = documentService
        self.readerCoreService = readerCoreService
        self.noteService = noteService
    }

    /// 快捷单例构造（集成默认沙盒与 Actor 引擎）
    public static func makeDefault() -> CoreService {
        let sandbox = LocalSandboxManager.shared
        let metadataEngine = MetadataStorageEngine(sandbox: sandbox)
        let pageKeyIndexManager = PageKeyIndexManager()
        let inkEngine = InkStorageEngine(sandbox: sandbox, indexManager: pageKeyIndexManager)

        let docService = DocumentService(metadataEngine: metadataEngine, inkEngine: inkEngine, sandbox: sandbox)
        let readerService = ReaderCoreService(metadataEngine: metadataEngine, inkEngine: inkEngine)
        let noteSvc = NoteService(metadataEngine: metadataEngine)

        return CoreService(
            documentService: docService,
            readerCoreService: readerService,
            noteService: noteSvc
        )
    }

    // MARK: - CoreServiceProtocol 转发代理

    public func resolveSource(_ anchor: SourceAnchor) async -> SourceResolution {
        await readerCoreService.resolveSource(anchor)
    }

    public func flushInk(snapshot: InkSaveSnapshot) async -> Result<InkSaveReceipt, SaveInkError> {
        await readerCoreService.flushInk(snapshot: snapshot)
    }

    public func savePosition(_ position: ReadingPosition) async throws -> Bool {
        try await readerCoreService.savePosition(position)
    }
}
