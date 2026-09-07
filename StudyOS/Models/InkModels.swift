import Foundation

/// 页面手写唯一标识键（基于 0-based 物理页号与源文档版本）
public struct PageKey: Hashable, Codable, Sendable {
    public let documentID: String
    public let documentRevision: Int
    public let pageIndex0: Int

    public init(documentID: String, documentRevision: Int, pageIndex0: Int) {
        self.documentID = documentID
        self.documentRevision = documentRevision
        self.pageIndex0 = pageIndex0
    }

    public var storageKey: String {
        "\(documentID)_\(documentRevision)_p\(pageIndex0)"
    }
}

/// 页面手写记录
public struct InkPage: Identifiable, Codable, Sendable, Hashable {
    public var id: String {
        "\(documentID)_\(documentRevision)_\(pageIndex0)"
    }

    public let documentID: String
    public let documentRevision: Int
    public let pageIndex0: Int
    public var drawingFileRef: String
    public var drawingRevision: Int
    public var canvasToPageTransform: CodableTransform
    public var formatVersion: Int

    public init(
        documentID: String,
        documentRevision: Int,
        pageIndex0: Int,
        drawingFileRef: String,
        drawingRevision: Int = 1,
        canvasToPageTransform: CodableTransform = .identity,
        formatVersion: Int = 1
    ) {
        self.documentID = documentID
        self.documentRevision = documentRevision
        self.pageIndex0 = pageIndex0
        self.drawingFileRef = drawingFileRef
        self.drawingRevision = drawingRevision
        self.canvasToPageTransform = canvasToPageTransform
        self.formatVersion = formatVersion
    }
}

/// 墨水异步保存快照（入队前不可变固化）
public struct InkSaveSnapshot: Sendable {
    public let pageKey: PageKey
    public let readerSessionID: String
    public let snapshotID: String
    public let drawingBlob: Data
    public let canvasToPageTransform: CodableTransform
    public let expectedRevision: Int

    public init(
        pageKey: PageKey,
        readerSessionID: String,
        snapshotID: String = UUID().uuidString,
        drawingBlob: Data,
        canvasToPageTransform: CodableTransform = .identity,
        expectedRevision: Int
    ) {
        self.pageKey = pageKey
        self.readerSessionID = readerSessionID
        self.snapshotID = snapshotID
        self.drawingBlob = drawingBlob
        self.canvasToPageTransform = canvasToPageTransform
        self.expectedRevision = expectedRevision
    }
}

/// 墨水异步保存回执（推进 persistedRevision）
public struct InkSaveReceipt: Hashable, Codable, Sendable {
    public let pageKey: PageKey
    public let snapshotID: String
    public let savedRevision: Int
    public let readerSessionID: String

    public init(
        pageKey: PageKey,
        snapshotID: String,
        savedRevision: Int,
        readerSessionID: String
    ) {
        self.pageKey = pageKey
        self.snapshotID = snapshotID
        self.savedRevision = savedRevision
        self.readerSessionID = readerSessionID
    }
}
