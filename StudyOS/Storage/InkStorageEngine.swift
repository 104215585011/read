import Foundation

/// 页面墨水本地持久化引擎 (Actor 隔离)
public actor InkStorageEngine {
    private let sandbox: LocalSandboxManager
    private let indexManager: PageKeyIndexManager
    private let fileManager = FileManager.default

    public init(
        sandbox: LocalSandboxManager = .shared,
        indexManager: PageKeyIndexManager = PageKeyIndexManager()
    ) {
        self.sandbox = sandbox
        self.indexManager = indexManager
    }

    /// 提交保存墨水快照
    public func saveInk(snapshot: InkSaveSnapshot) async -> Result<InkSaveReceipt, SaveInkError> {
        let key = snapshot.pageKey
        let beginResult = await indexManager.beginSave(
            key: key,
            snapshotID: snapshot.snapshotID,
            expectedRevision: snapshot.expectedRevision
        )

        switch beginResult {
        case .failure(let error):
            return .failure(error)
        case .success:
            break
        }

        let nextRevision = snapshot.expectedRevision + 1
        let targetDirectory = sandbox.inkDirectory(
            documentID: key.documentID,
            documentRevision: key.documentRevision
        )

        do {
            if !fileManager.fileExists(atPath: targetDirectory.path) {
                try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
            }

            let fileURL = sandbox.inkFileURL(pageKey: key, drawingRevision: nextRevision)
            try snapshot.drawingBlob.write(to: fileURL, options: .atomic)

            await indexManager.completeSave(
                key: key,
                snapshotID: snapshot.snapshotID,
                savedRevision: nextRevision
            )

            let receipt = InkSaveReceipt(
                pageKey: key,
                snapshotID: snapshot.snapshotID,
                savedRevision: nextRevision,
                readerSessionID: snapshot.readerSessionID
            )
            return .success(receipt)
        } catch {
            let saveError = SaveInkError.saveFailed(error.localizedDescription)
            await indexManager.failSave(
                key: key,
                snapshotID: snapshot.snapshotID,
                error: saveError
            )
            return .failure(saveError)
        }
    }

    /// 加载指定页面的墨水元数据与最新持久化文件
    public func loadInkPage(pageKey: PageKey) async -> InkPage? {
        let currentRev = await indexManager.getPersistedRevision(for: pageKey)
        guard currentRev > 0 else { return nil }

        let fileURL = sandbox.inkFileURL(pageKey: pageKey, drawingRevision: currentRev)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        return InkPage(
            documentID: pageKey.documentID,
            documentRevision: pageKey.documentRevision,
            pageIndex0: pageKey.pageIndex0,
            drawingFileRef: fileURL.path,
            drawingRevision: currentRev,
            canvasToPageTransform: .identity,
            formatVersion: 1
        )
    }

    /// 读取原始墨水二进制数据
    public func loadDrawingBlob(pageKey: PageKey) async -> Data? {
        let currentRev = await indexManager.getPersistedRevision(for: pageKey)
        guard currentRev > 0 else { return nil }

        let fileURL = sandbox.inkFileURL(pageKey: pageKey, drawingRevision: currentRev)
        return try? Data(contentsOf: fileURL)
    }

    /// 删除指定文档的全部笔迹存储
    public func removeInks(documentID: String, documentRevision: Int) async {
        let dir = sandbox.inkDirectory(documentID: documentID, documentRevision: documentRevision)
        try? fileManager.removeItem(at: dir)
        await indexManager.removeKeys(forDocumentID: documentID)
    }
}
