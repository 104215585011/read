import Foundation

/// 页面文本提取状态
public enum PageTextState: String, Codable, Sendable {
    case unextracted
    case extracting
    case ready
    case failed
    case empty
}

/// 页面领域记录（以 0-based pageIndex0 标识）
public struct Page: Identifiable, Codable, Sendable, Hashable {
    public var id: String {
        "\(documentID)_\(documentRevision)_\(pageIndex0)"
    }

    public let documentID: String
    public let documentRevision: Int
    public let pageIndex0: Int
    public var displayLabel: String?
    public var cropBox: CodableRect
    public var rotation: Int
    public var textState: PageTextState
    public var paragraphIDs: [String]

    public init(
        documentID: String,
        documentRevision: Int,
        pageIndex0: Int,
        displayLabel: String? = nil,
        cropBox: CodableRect,
        rotation: Int = 0,
        textState: PageTextState = .unextracted,
        paragraphIDs: [String] = []
    ) {
        self.documentID = documentID
        self.documentRevision = documentRevision
        self.pageIndex0 = pageIndex0
        self.displayLabel = displayLabel
        self.cropBox = cropBox
        self.rotation = rotation
        self.textState = textState
        self.paragraphIDs = paragraphIDs
    }
}
