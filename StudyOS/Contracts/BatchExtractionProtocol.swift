import Foundation

/// 分批抽取进度汇报 (BatchExtractionProgress)
public struct BatchExtractionProgress: Codable, Sendable, Hashable {
    public let processedPages: Int
    public let totalPages: Int
    public let currentBatchIndex: Int
    public let totalBatches: Int
    public let percentage: Double
    public let isCompleted: Bool

    public init(
        processedPages: Int,
        totalPages: Int,
        currentBatchIndex: Int,
        totalBatches: Int,
        percentage: Double,
        isCompleted: Bool = false
    ) {
        self.processedPages = processedPages
        self.totalPages = totalPages
        self.currentBatchIndex = currentBatchIndex
        self.totalBatches = totalBatches
        self.percentage = percentage
        self.isCompleted = isCompleted
    }
}

/// 分批抽取配置 (BatchExtractionConfig)
public struct BatchExtractionConfig: Codable, Sendable, Hashable {
    public let batchSize: Int
    public let maxConcurrentBatches: Int
    public let timeoutPerBatch: TimeInterval
    public let extractImages: Bool
    public let startPageIndex0: Int?
    public let endPageIndex0: Int?

    public init(
        batchSize: Int = 10,
        maxConcurrentBatches: Int = 2,
        timeoutPerBatch: TimeInterval = 30.0,
        extractImages: Bool = false,
        startPageIndex0: Int? = nil,
        endPageIndex0: Int? = nil
    ) {
        self.batchSize = max(1, batchSize)
        self.maxConcurrentBatches = max(1, maxConcurrentBatches)
        self.timeoutPerBatch = max(1.0, timeoutPerBatch)
        self.extractImages = extractImages
        self.startPageIndex0 = startPageIndex0
        self.endPageIndex0 = endPageIndex0
    }
}

/// 单批提取出的页面集合 (PageExtractionBatch)
public struct PageExtractionBatch: Codable, Sendable, Hashable {
    public let batchIndex: Int
    public let startPageIndex0: Int
    public let endPageIndex0: Int
    public let pages: [Page]
    public let extractedAt: Date

    public init(
        batchIndex: Int,
        startPageIndex0: Int,
        endPageIndex0: Int,
        pages: [Page],
        extractedAt: Date = Date()
    ) {
        self.batchIndex = batchIndex
        self.startPageIndex0 = startPageIndex0
        self.endPageIndex0 = endPageIndex0
        self.pages = pages
        self.extractedAt = extractedAt
    }
}

/// 长文档分批抽取总结果 (BatchExtractionResult)
public struct BatchExtractionResult: Codable, Sendable, Hashable {
    public let documentID: String
    public let batches: [PageExtractionBatch]
    public let totalPagesExtracted: Int
    public let isCompleted: Bool
    public let duration: TimeInterval

    public init(
        documentID: String,
        batches: [PageExtractionBatch],
        totalPagesExtracted: Int,
        isCompleted: Bool,
        duration: TimeInterval
    ) {
        self.documentID = documentID
        self.batches = batches
        self.totalPagesExtracted = totalPagesExtracted
        self.isCompleted = isCompleted
        self.duration = duration
    }
}

/// 分批抽取错误类型
public enum BatchExtractionError: Error, Sendable, Hashable, LocalizedError {
    case documentNotFound(String)
    case invalidPDF(String)
    case pageOutOfBounds(index0: Int, totalPages: Int)
    case batchTimeout(batchIndex: Int)
    case cancelled
    case extractionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .documentNotFound(let id):
            return "文档未找到: \(id)"
        case .invalidPDF(let msg):
            return "无效或损坏的 PDF 文档: \(msg)"
        case .pageOutOfBounds(let index0, let total):
            return "页码越界: 第 \(index0) 页 (总计 \(total) 页)"
        case .batchTimeout(let idx):
            return "批次 \(idx) 抽取超时"
        case .cancelled:
            return "抽取任务已取消"
        case .extractionFailed(let msg):
            return "抽取失败: \(msg)"
        }
    }
}

/// 长文档异步分批抽取协议 (BatchExtractionProtocol)
public protocol BatchExtractionProtocol: Sendable {
    /// 异步分批抽取长文档
    func extractDocument(
        documentID: String,
        fileURL: URL,
        config: BatchExtractionConfig,
        onProgress: (@Sendable (BatchExtractionProgress) -> Void)?
    ) async throws -> BatchExtractionResult

    /// 取消指定文档的抽取任务
    func cancelExtraction(documentID: String) async -> Bool

    /// 查询文档是否处于抽取中
    func isExtracting(documentID: String) async -> Bool
}
