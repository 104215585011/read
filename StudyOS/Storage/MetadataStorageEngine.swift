import Foundation

/// 元数据存储通用错误
public enum StorageError: Error, Sendable {
    case notFound(String)
    case conflict(expectedRevision: Int, currentRevision: Int)
    case saveFailed(String)
    case documentDeleted
}

/// 本地元数据与领域记录持久化引擎 (Actor 隔离)
public actor MetadataStorageEngine {
    private let sandbox: LocalSandboxManager
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // 内存数据镜像（支持本地文件备份与快照）
    private var documents: [String: Document] = [:]
    private var pages: [String: Page] = [:]
    private var annotations: [String: Annotation] = [:]
    private var bookmarks: [String: Bookmark] = [:]
    private var readingPositions: [String: ReadingPosition] = [:] // key: documentID
    private var notes: [String: Note] = [:]

    public init(sandbox: LocalSandboxManager = .shared) {
        self.sandbox = sandbox
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Document Operations

    public func saveDocument(_ doc: Document) {
        documents[doc.id] = doc
        persistMetadata(fileName: "documents", object: documents)
    }

    public func getDocument(id: String) -> Document? {
        documents[id]
    }

    public func listDocuments() -> [Document] {
        Array(documents.values).sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Delete Document Preview & Execution (UIREV-06)

    public func previewDeleteDocument(id: String, revision: Int) -> DeleteImpact {
        let relatedAnnotations = annotations.values.filter { $0.anchor.documentID == id }
        let relatedNotes = notes.values.filter { $0.documentID == id }
        let relatedImagesCount = relatedNotes.reduce(0) { $0 + $1.imageRefs.count }

        return DeleteImpact(
            documentID: id,
            documentRevision: revision,
            originalFileCount: 1,
            indexCount: 1,
            annotationCount: relatedAnnotations.count,
            inkCount: 0,
            sessionCount: 1,
            associatedNoteCount: relatedNotes.count,
            associatedImageCount: relatedImagesCount
        )
    }

    public func deleteDocument(
        id: String,
        expectedRevision: Int,
        notePolicy: NotePolicy,
        confirmedImpactID: String
    ) throws -> DeleteResult {
        guard let doc = documents[id] else {
            throw StorageError.notFound("Document not found: \(id)")
        }

        guard doc.revision == expectedRevision else {
            throw StorageError.conflict(expectedRevision: expectedRevision, currentRevision: doc.revision)
        }

        // 1. 删除原件文档记录
        documents.removeValue(forKey: id)
        readingPositions.removeValue(forKey: id)

        // 2. 清理批注与书签
        let deletedAnnotations = annotations.filter { $0.value.anchor.documentID == id }
        for (annID, _) in deletedAnnotations {
            annotations.removeValue(forKey: annID)
        }

        let deletedBookmarks = bookmarks.filter { $0.value.documentID == id }
        for (bmID, _) in deletedBookmarks {
            bookmarks.removeValue(forKey: bmID)
        }

        // 3. 处理关联笔记（两路策略：keep / delete）
        var retainedNoteIDs: [String] = []
        let docNotes = notes.filter { $0.value.documentID == id }

        switch notePolicy {
        case .keep:
            // 保留笔记文本与图片副本，解除 documentID/chapterID 归属，标为 documentDeleted 不可导航
            for (noteID, var note) in docNotes {
                note.documentID = nil
                note.chapterID = nil
                note.sourceAnchors = note.sourceAnchors.map { anchor in
                    var updatedAnchor = anchor
                    updatedAnchor.availability = .documentDeleted
                    return updatedAnchor
                }
                note.updatedAt = Date()
                notes[noteID] = note
                retainedNoteIDs.append(noteID)
            }

        case .delete:
            // 连带删除关联笔记
            for (noteID, _) in docNotes {
                notes.removeValue(forKey: noteID)
            }
        }

        persistMetadata(fileName: "documents", object: documents)
        persistMetadata(fileName: "notes", object: notes)
        persistMetadata(fileName: "annotations", object: annotations)
        persistMetadata(fileName: "bookmarks", object: bookmarks)

        let deletedCounts: [String: Int] = [
            "documents": 1,
            "annotations": deletedAnnotations.count,
            "bookmarks": deletedBookmarks.count,
            "notes": notePolicy == .delete ? docNotes.count : 0
        ]

        return .completed(
            policy: notePolicy,
            deletedCounts: deletedCounts,
            retainedNoteIDs: retainedNoteIDs
        )
    }

    // MARK: - Reading Position

    public func saveReadingPosition(_ pos: ReadingPosition) {
        readingPositions[pos.documentID] = pos
        persistMetadata(fileName: "reading_positions", object: readingPositions)
    }

    public func getReadingPosition(documentID: String) -> ReadingPosition? {
        readingPositions[documentID]
    }

    // MARK: - Bookmarks

    public func saveBookmark(_ bookmark: Bookmark) {
        bookmarks[bookmark.id] = bookmark
        persistMetadata(fileName: "bookmarks", object: bookmarks)
    }

    public func getBookmarks(documentID: String) -> [Bookmark] {
        bookmarks.values.filter { $0.documentID == documentID }
    }

    public func deleteBookmark(id: String) -> Bool {
        guard bookmarks.removeValue(forKey: id) != nil else { return false }
        persistMetadata(fileName: "bookmarks", object: bookmarks)
        return true
    }

    // MARK: - Annotations

    public func saveAnnotation(_ annotation: Annotation) {
        annotations[annotation.id] = annotation
        persistMetadata(fileName: "annotations", object: annotations)
    }

    public func getAnnotations(documentID: String) -> [Annotation] {
        annotations.values.filter { $0.anchor.documentID == documentID }
    }

    // MARK: - Notes

    public func saveNote(_ note: Note, expectedRevision: Int) throws -> Note {
        if let existing = notes[note.id] {
            guard existing.revision == expectedRevision else {
                throw StorageError.conflict(expectedRevision: expectedRevision, currentRevision: existing.revision)
            }
        }
        var updated = note
        updated.revision = expectedRevision + 1
        updated.updatedAt = Date()
        notes[updated.id] = updated
        persistMetadata(fileName: "notes", object: notes)
        return updated
    }

    public func getNote(id: String) -> Note? {
        notes[id]
    }

    public func listNotes(documentID: String? = nil) -> [Note] {
        if let docID = documentID {
            return notes.values.filter { $0.documentID == docID }.sorted { $0.updatedAt > $1.updatedAt }
        }
        return Array(notes.values).sorted { $0.updatedAt > $1.updatedAt }
    }

    public func deleteNote(id: String) -> Bool {
        guard notes.removeValue(forKey: id) != nil else { return false }
        persistMetadata(fileName: "notes", object: notes)
        return true
    }

    // MARK: - Disk Persistence Helper

    private func persistMetadata<T: Encodable>(fileName: String, object: T) {
        let fileURL = sandbox.metadataFileURL(fileName: fileName)
        if let data = try? encoder.encode(object) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
