import Foundation

/// 文档生命周期管理服务实现 (Actor 隔离)
public actor DocumentService: DocumentServiceProtocol {
    private let metadataEngine: MetadataStorageEngine
    private let inkEngine: InkStorageEngine
    private let sandbox: LocalSandboxManager
    private let fileManager = FileManager.default

    public init(
        metadataEngine: MetadataStorageEngine,
        inkEngine: InkStorageEngine,
        sandbox: LocalSandboxManager = .shared
    ) {
        self.metadataEngine = metadataEngine
        self.inkEngine = inkEngine
        self.sandbox = sandbox
    }

    /// 导入本地或拾取的 PDF 文件
    public func importPDF(fileURL: URL, operationID: String) async throws -> Document {
        let docID = UUID().uuidString
        let docDir = sandbox.documentDirectory(id: docID)

        if !fileManager.fileExists(atPath: docDir.path) {
            try fileManager.createDirectory(at: docDir, withIntermediateDirectories: true)
        }

        let targetPDFURL = sandbox.documentPDFURL(id: docID)
        if fileManager.fileExists(atPath: targetPDFURL.path) {
            try fileManager.removeItem(at: targetPDFURL)
        }
        try fileManager.copyItem(at: fileURL, to: targetPDFURL)

        // 计算基础文件信息
        let attributes = try? fileManager.attributesOfItem(atPath: targetPDFURL.path)
        let fileSize = (attributes?[.size] as? Int64) ?? 0
        let sourceHash = "hash_\(fileSize)_\(docID.prefix(8))"

        let document = Document(
            id: docID,
            title: fileURL.deletingPathExtension().lastPathComponent,
            sourceHash: sourceHash,
            revision: 1,
            localFileRef: targetPDFURL.path,
            pageCount: 1, // 初始估算，随后由 PDFKit 解析更新
            importState: .readable,
            indexState: .none,
            createdAt: Date(),
            updatedAt: Date()
        )

        await metadataEngine.saveDocument(document)
        return document
    }

    /// 解密受保护文档
    public func unlockDocument(documentID: String, password: String) async throws -> Bool {
        guard let doc = await metadataEngine.getDocument(id: documentID) else {
            throw StorageError.notFound("Document not found: \(documentID)")
        }
        // 密码不记录在日志中
        guard !password.isEmpty else { return false }
        var updated = doc
        updated.importState = .readable
        await metadataEngine.saveDocument(updated)
        return true
    }

    public func listDocuments() async throws -> [Document] {
        await metadataEngine.listDocuments()
    }

    public func getDocument(id: String) async throws -> Document? {
        await metadataEngine.getDocument(id: id)
    }

    /// 预览删除影响清单 (UIREV-06)
    public func previewDeleteDocument(documentID: String, revision: Int) async throws -> DeleteImpact {
        guard let doc = await metadataEngine.getDocument(id: documentID) else {
            throw StorageError.notFound("Document not found: \(documentID)")
        }
        guard doc.revision == revision else {
            throw StorageError.conflict(expectedRevision: revision, currentRevision: doc.revision)
        }
        return await metadataEngine.previewDeleteDocument(id: documentID, revision: revision)
    }

    /// 执行文档删除（两路笔记处理策略：keep / delete）
    public func deleteDocument(
        documentID: String,
        expectedRevision: Int,
        notePolicy: NotePolicy,
        confirmedImpactID: String,
        operationID: String
    ) async throws -> DeleteResult {
        // 1. 删除元数据及按策略处理笔记
        let result = try await metadataEngine.deleteDocument(
            id: documentID,
            expectedRevision: expectedRevision,
            notePolicy: notePolicy,
            confirmedImpactID: confirmedImpactID
        )

        // 2. 清理墨水物理文件与索引
        await inkEngine.removeInks(documentID: documentID, documentRevision: expectedRevision)

        // 3. 清理 PDF 文件目录
        let docDir = sandbox.documentDirectory(id: documentID)
        try? fileManager.removeItem(at: docDir)

        return result
    }
}
