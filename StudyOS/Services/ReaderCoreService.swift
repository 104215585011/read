import Foundation

/// 阅读器核心与导航/笔迹服务实现 (Actor 隔离)
public actor ReaderCoreService: ReaderCoreServiceProtocol {
    private let metadataEngine: MetadataStorageEngine
    private let inkEngine: InkStorageEngine

    public init(
        metadataEngine: MetadataStorageEngine,
        inkEngine: InkStorageEngine
    ) {
        self.metadataEngine = metadataEngine
        self.inkEngine = inkEngine
    }

    /// 解析来源锚点 (UIREV-01, UIREV-04)
    public func resolveSource(_ anchor: SourceAnchor) async -> SourceResolution {
        // 1. 检查引用有效性状态
        guard anchor.availability == .active else {
            return .unavailable
        }

        // 2. 检查对应文档是否存在
        guard let document = await metadataEngine.getDocument(id: anchor.documentID) else {
            return .unavailable
        }

        // 3. 严格核对文档版本 (UIREV-01: 禁止跳转至旧版本疑似位置)
        guard document.revision == anchor.documentRevision else {
            return .staleReference
        }

        // 4. 严格校验非负页码与有效边界
        guard anchor.pageIndex0 >= 0, anchor.pageIndex0 < document.pageCount else {
            return .unavailable
        }

        let target = NavigationTarget(
            documentID: anchor.documentID,
            documentRevision: anchor.documentRevision,
            pageIndex0: anchor.pageIndex0,
            regions: anchor.regions,
            precision: anchor.precision,
            resolvedFromAnchor: anchor
        )
        return .navigationTarget(target)
    }

    /// 获取阅读器全景快照
    public func getReaderSnapshot(documentID: String) async throws -> ReaderSnapshot {
        guard let doc = await metadataEngine.getDocument(id: documentID) else {
            throw StorageError.notFound("Document not found: \(documentID)")
        }

        let bookmarks = await metadataEngine.getBookmarks(documentID: documentID)
        let pos = await metadataEngine.getReadingPosition(documentID: documentID)

        return ReaderSnapshot(
            documentID: documentID,
            pageCount: doc.pageCount,
            chapters: [],
            bookmarks: bookmarks,
            readingPosition: pos,
            indexState: doc.indexState
        )
    }

    /// 保存阅读位置 (UIREV-04)
    public func savePosition(_ position: ReadingPosition) async throws -> Bool {
        guard let doc = await metadataEngine.getDocument(id: position.documentID) else {
            throw StorageError.notFound("Document not found: \(position.documentID)")
        }

        guard doc.revision == position.documentRevision else {
            throw StorageError.conflict(expectedRevision: position.documentRevision, currentRevision: doc.revision)
        }

        guard position.pageIndex0 >= 0, position.pageIndex0 < doc.pageCount else {
            return false
        }

        await metadataEngine.saveReadingPosition(position)
        return true
    }

    /// 提交保存墨水快照 (UIREV-03)
    public func flushInk(snapshot: InkSaveSnapshot) async -> Result<InkSaveReceipt, SaveInkError> {
        await inkEngine.saveInk(snapshot: snapshot)
    }

    /// 加载指定页面的墨水元数据
    public func loadInk(pageKey: PageKey) async throws -> InkPage? {
        await inkEngine.loadInkPage(pageKey: pageKey)
    }

    // MARK: - Bookmarks

    public func createBookmark(
        documentID: String,
        anchor: SourceAnchor,
        label: String,
        operationID: String
    ) async throws -> Bookmark {
        guard (await metadataEngine.getDocument(id: documentID)) != nil else {
            throw StorageError.notFound("Document not found: \(documentID)")
        }

        let bookmark = Bookmark(
            documentID: documentID,
            anchor: anchor,
            label: label,
            revision: 1
        )
        await metadataEngine.saveBookmark(bookmark)
        return bookmark
    }

    public func updateBookmark(bookmark: Bookmark, expectedRevision: Int) async throws -> Bookmark {
        guard bookmark.revision == expectedRevision else {
            throw StorageError.conflict(expectedRevision: expectedRevision, currentRevision: bookmark.revision)
        }
        var updated = bookmark
        updated.revision = expectedRevision + 1
        await metadataEngine.saveBookmark(updated)
        return updated
    }

    public func deleteBookmark(bookmarkID: String, expectedRevision: Int) async throws -> Bool {
        await metadataEngine.deleteBookmark(id: bookmarkID)
    }

    // MARK: - Annotations

    public func createAnnotation(annotation: Annotation, expectedRevision: Int) async throws -> Annotation {
        await metadataEngine.saveAnnotation(annotation)
        return annotation
    }

    public func updateAnnotation(annotation: Annotation, expectedRevision: Int) async throws -> Annotation {
        guard annotation.revision == expectedRevision else {
            throw StorageError.conflict(expectedRevision: expectedRevision, currentRevision: annotation.revision)
        }
        var updated = annotation
        updated.revision = expectedRevision + 1
        updated.updatedAt = Date()
        await metadataEngine.saveAnnotation(updated)
        return updated
    }
}
