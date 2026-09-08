import Foundation

#if canImport(PDFKit)
import PDFKit
#endif

/// 长文档异步分批抽取引擎 (DocumentBatchExtractionEngine)
/// 落实 R10 P0 后端支撑：按 batchSize 安全拆分，流式派发，支持 Actor 隔离与 Task 取消
public actor DocumentBatchExtractionEngine: BatchExtractionProtocol {
    private var activeDocumentIDs: Set<String> = []
    private var cancellationFlags: [String: Bool] = [:]

    public init() {}

    /// 异步分批抽取长文档
    public func extractDocument(
        documentID: String,
        fileURL: URL,
        config: BatchExtractionConfig,
        onProgress: (@Sendable (BatchExtractionProgress) -> Void)?
    ) async throws -> BatchExtractionResult {
        let startTime = Date()
        cancellationFlags[documentID] = false
        activeDocumentIDs.insert(documentID)

        defer {
            activeDocumentIDs.remove(documentID)
            cancellationFlags.removeValue(forKey: documentID)
        }

        // 1. 加载或检测文档物理页数
        let totalDocumentPages: Int
        #if canImport(PDFKit)
        guard let pdfDoc = PDFDocument(url: fileURL) else {
            throw BatchExtractionError.invalidPDF("无法加载 PDF 文件: \(fileURL.lastPathComponent)")
        }
        totalDocumentPages = pdfDoc.pageCount
        #else
        // 平台降级或无真实 PDFKit 时的基础支持
        totalDocumentPages = 20
        #endif

        guard totalDocumentPages > 0 else {
            throw BatchExtractionError.invalidPDF("文档页数为 0")
        }

        // 2. 计算抽取起止页码范围 (0-based)
        let startIndex = max(0, config.startPageIndex0 ?? 0)
        let endIndex = min(totalDocumentPages - 1, config.endPageIndex0 ?? (totalDocumentPages - 1))

        guard startIndex <= endIndex else {
            throw BatchExtractionError.pageOutOfBounds(index0: startIndex, totalPages: totalDocumentPages)
        }

        let targetIndices = Array(startIndex...endIndex)
        let totalPagesToProcess = targetIndices.count

        // 3. 按 batchSize 分块
        var batches: [PageExtractionBatch] = []
        let batchChunks = stride(from: 0, to: totalPagesToProcess, by: config.batchSize).map { startOffset in
            let endOffset = min(startOffset + config.batchSize, totalPagesToProcess)
            return Array(targetIndices[startOffset..<endOffset])
        }

        var processedCount = 0
        let totalBatchCount = batchChunks.count

        // 4. 逐批执行抽取与进度派发
        for (batchIdx, pageIndices) in batchChunks.enumerated() {
            // 检查取消态
            if Task.isCancelled || cancellationFlags[documentID] == true {
                throw BatchExtractionError.cancelled
            }

            var batchPages: [Page] = []

            for pageIndex0 in pageIndices {
                if Task.isCancelled || cancellationFlags[documentID] == true {
                    throw BatchExtractionError.cancelled
                }

                #if canImport(PDFKit)
                let pdfPage = pdfDoc.page(at: pageIndex0)
                let text = pdfPage?.string ?? ""
                let bounds = pdfPage?.bounds(for: .cropBox)
                let rect = CodableRect(
                    x: Double(bounds?.origin.x ?? 0),
                    y: Double(bounds?.origin.y ?? 0),
                    width: Double(bounds?.size.width ?? 612),
                    height: Double(bounds?.size.height ?? 792)
                )
                #else
                let text = "第 \(pageIndex0 + 1) 页文本内容示例"
                let rect = CodableRect(x: 0, y: 0, width: 612, height: 792)
                #endif

                let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                var paragraphIDs: [String] = []

                if !cleanedText.isEmpty {
                    let lines = cleanedText.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    for (lineIdx, line) in lines.enumerated() {
                        let paraID = "para_\(documentID)_\(pageIndex0)_\(lineIdx)"
                        paragraphIDs.append(paraID)
                    }
                }

                let pageRecord = Page(
                    documentID: documentID,
                    documentRevision: 1,
                    pageIndex0: pageIndex0,
                    displayLabel: "\(pageIndex0 + 1)",
                    cropBox: rect,
                    rotation: 0,
                    textState: cleanedText.isEmpty ? .empty : .ready,
                    paragraphIDs: paragraphIDs
                )
                batchPages.append(pageRecord)
                processedCount += 1
            }

            let startP = pageIndices.first ?? startIndex
            let endP = pageIndices.last ?? endIndex
            let batch = PageExtractionBatch(
                batchIndex: batchIdx,
                startPageIndex0: startP,
                endPageIndex0: endP,
                pages: batchPages,
                extractedAt: Date()
            )
            batches.append(batch)

            // 派发进度
            let progress = BatchExtractionProgress(
                processedPages: processedCount,
                totalPages: totalPagesToProcess,
                currentBatchIndex: batchIdx,
                totalBatches: totalBatchCount,
                percentage: Double(processedCount) / Double(totalPagesToProcess),
                isCompleted: processedCount >= totalPagesToProcess
            )
            onProgress?(progress)

            // 批次间让出执行域，确保 UI 与其他并发 Task 响应
            await Task.yield()
        }

        let duration = Date().timeIntervalSince(startTime)
        return BatchExtractionResult(
            documentID: documentID,
            batches: batches,
            totalPagesExtracted: processedCount,
            isCompleted: true,
            duration: duration
        )
    }

    /// 取消指定文档的抽取任务
    public func cancelExtraction(documentID: String) async -> Bool {
        guard activeDocumentIDs.contains(documentID) else {
            return false
        }
        cancellationFlags[documentID] = true
        activeDocumentIDs.remove(documentID)
        return true
    }

    /// 查询文档是否处于抽取中
    public func isExtracting(documentID: String) async -> Bool {
        activeDocumentIDs.contains(documentID)
    }
}
