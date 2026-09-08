import Foundation

/// 统一核心服务实现门面 (CoreService)
public final class CoreService: CoreServiceProtocol, Sendable {
    public let documentService: DocumentServiceProtocol
    public let readerCoreService: ReaderCoreServiceProtocol
    public let noteService: NoteServiceProtocol
    public let aiService: AIServiceProtocol
    public let batchExtractionEngine: BatchExtractionProtocol
    public let aiNoteService: AINoteServiceProtocol
    public let localLLMProvider: LocalLLMProviderProtocol?
    public let fullDocumentStudyService: FullDocumentStudyProtocol
    public let offlineResourceManager: OfflineResourceManagerProtocol
    public let networkRetryEngine: NetworkResilienceRetryEngineProtocol
    public let localModelPackageManager: LocalModelPackageManagerProtocol?
    public let modelProviderRegistry: ModelProviderRegistryProtocol

    public init(
        documentService: DocumentServiceProtocol,
        readerCoreService: ReaderCoreServiceProtocol,
        noteService: NoteServiceProtocol,
        aiService: AIServiceProtocol,
        batchExtractionEngine: BatchExtractionProtocol = DocumentBatchExtractionEngine(),
        aiNoteService: AINoteServiceProtocol = AINoteService(),
        localLLMProvider: LocalLLMProviderProtocol? = nil,
        fullDocumentStudyService: FullDocumentStudyProtocol? = nil,
        offlineResourceManager: OfflineResourceManagerProtocol = OfflineResourceManager(),
        networkRetryEngine: NetworkResilienceRetryEngineProtocol = NetworkResilienceRetryEngine(),
        localModelPackageManager: LocalModelPackageManagerProtocol? = nil,
        modelProviderRegistry: ModelProviderRegistryProtocol = ModelProviderRegistry()
    ) {
        self.documentService = documentService
        self.readerCoreService = readerCoreService
        self.noteService = noteService
        self.aiService = aiService
        self.batchExtractionEngine = batchExtractionEngine
        self.aiNoteService = aiNoteService
        self.localLLMProvider = localLLMProvider
        self.fullDocumentStudyService = fullDocumentStudyService ?? FullDocumentStudyService(
            sandbox: .shared,
            provider: localLLMProvider ?? LocalMockLLMProvider(),
            metadataEngine: MetadataStorageEngine(sandbox: .shared)
        )
        self.offlineResourceManager = offlineResourceManager
        self.networkRetryEngine = networkRetryEngine
        self.localModelPackageManager = localModelPackageManager ?? LocalModelPackageManager(
            offlineResourceManager: offlineResourceManager
        )
        self.modelProviderRegistry = modelProviderRegistry
    }

    /// 快捷单例构造（集成默认沙盒与 Actor 引擎）
    public static func makeDefault(
        provider: LLMProviderProtocol = OpenAICompatibleProvider(
            profileID: "openai-default",
            baseURL: URL(string: "https://api.openai.com/v1")!,
            apiKey: ""
        ),
        localProvider: LocalLLMProviderProtocol? = LocalMockLLMProvider()
    ) -> CoreService {
        let sandbox = LocalSandboxManager.shared
        // 确保冷启动时自动播种学术样例
        sandbox.seedSampleAcademicDocumentIfEmpty()

        let metadataEngine = MetadataStorageEngine(sandbox: sandbox)
        let pageKeyIndexManager = PageKeyIndexManager()
        let inkEngine = InkStorageEngine(sandbox: sandbox, indexManager: pageKeyIndexManager)
        let aiNoteSvc = AINoteService(sandbox: sandbox)
        let docService = DocumentService(metadataEngine: metadataEngine, inkEngine: inkEngine, sandbox: sandbox, aiNoteService: aiNoteSvc)
        let readerService = ReaderCoreService(metadataEngine: metadataEngine, inkEngine: inkEngine)
        let noteSvc = NoteService(metadataEngine: metadataEngine)
        let aiSvc = AIService(provider: provider, metadataEngine: metadataEngine)
        let extractionEngine = DocumentBatchExtractionEngine()
        let fullStudySvc = FullDocumentStudyService(
            sandbox: sandbox,
            provider: localProvider ?? provider,
            metadataEngine: metadataEngine
        )
        let offlineRM = OfflineResourceManager(sandbox: sandbox)
        let retryEngine = NetworkResilienceRetryEngine()
        let modelPkgMgr = LocalModelPackageManager(offlineResourceManager: offlineRM)
        let modelRegistry = ModelProviderRegistry(sandbox: sandbox)

        return CoreService(
            documentService: docService,
            readerCoreService: readerService,
            noteService: noteSvc,
            aiService: aiSvc,
            batchExtractionEngine: extractionEngine,
            aiNoteService: aiNoteSvc,
            localLLMProvider: localProvider,
            fullDocumentStudyService: fullStudySvc,
            offlineResourceManager: offlineRM,
            networkRetryEngine: retryEngine,
            localModelPackageManager: modelPkgMgr,
            modelProviderRegistry: modelRegistry
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
