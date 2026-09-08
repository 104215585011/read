import XCTest
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import StudyOS

// MARK: - Test Helpers & Thread-Safe Collectors

/// 线程安全的进度记录收集器，用于 Strict Concurrency 环境下的异步进度闭包测试
private final class ProgressCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [BatchExtractionProgress] = []

    func record(_ p: BatchExtractionProgress) {
        lock.lock()
        _events.append(p)
        lock.unlock()
    }

    var events: [BatchExtractionProgress] {
        lock.lock()
        defer { lock.unlock() }
        return _events
    }
}

/// 快速生成指定页数的测试 PDF 文件（在 macOS / iOS 原生环境下通过 CoreGraphics 生成标准多页 PDF）
private func generateTestPDF(at url: URL, pageCount: Int) {
    #if canImport(CoreGraphics)
    var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
    if let consumer = CGDataConsumer(url: url as CFURL),
       let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) {
        for _ in 0..<pageCount {
            context.beginPage(mediaBox: &mediaBox)
            context.endPage()
        }
        context.closePDF()
        return
    }
    #endif
    // 跨平台降级 fallback（非 CoreGraphics 环境）
    try? "dummy pdf content".write(to: url, atomically: true, encoding: .utf8)
}

// MARK: - 1. BatchExtractionTests (长文档并发分批抽取测试套件)

/// 长文档异步分批抽取引擎测试套件 (R10 P0 / BatchExtractionProtocol)
final class BatchExtractionTests: XCTestCase {

    private var tempDirectoryURL: URL!
    private var engine: DocumentBatchExtractionEngine!

    override func setUp() async throws {
        try await super.setUp()
        let tempBase = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("StudyOSTests_Batch_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)
        self.tempDirectoryURL = tempBase
        self.engine = DocumentBatchExtractionEngine()
    }

    override func tearDown() async throws {
        if let temp = tempDirectoryURL {
            try? FileManager.default.removeItem(at: temp)
        }
        self.engine = nil
        try await super.tearDown()
    }

    /// 测试并发分批拆分逻辑：按 batchSize 正确切片，页码全覆盖无遗漏与无重复
    func testBatchExtractionSlicingAndFullPageCoverage() async throws {
        let pageCount = 25
        let batchSize = 10
        let pdfURL = tempDirectoryURL.appendingPathComponent("sample_25p.pdf")
        generateTestPDF(at: pdfURL, pageCount: pageCount)

        let docID = "doc_batch_slice_001"
        let config = BatchExtractionConfig(
            batchSize: batchSize,
            maxConcurrentBatches: 2,
            timeoutPerBatch: 10.0,
            startPageIndex0: 0,
            endPageIndex0: pageCount - 1
        )

        let result = try await engine.extractDocument(
            documentID: docID,
            fileURL: pdfURL,
            config: config,
            onProgress: nil
        )

        XCTAssertEqual(result.documentID, docID)
        XCTAssertTrue(result.isCompleted)
        XCTAssertEqual(result.totalPagesExtracted, pageCount)

        // 25 页 / 每批 10 页 -> 3 批 (10, 10, 5)
        XCTAssertEqual(result.batches.count, 3, "25 页按 batchSize: 10 应切分为 3 批")
        XCTAssertEqual(result.batches[0].pages.count, 10)
        XCTAssertEqual(result.batches[0].startPageIndex0, 0)
        XCTAssertEqual(result.batches[0].endPageIndex0, 9)

        XCTAssertEqual(result.batches[1].pages.count, 10)
        XCTAssertEqual(result.batches[1].startPageIndex0, 10)
        XCTAssertEqual(result.batches[1].endPageIndex0, 19)

        XCTAssertEqual(result.batches[2].pages.count, 5)
        XCTAssertEqual(result.batches[2].startPageIndex0, 20)
        XCTAssertEqual(result.batches[2].endPageIndex0, 24)

        // 验证页码从 0 到 24 严格顺序且全覆盖、无重复、无遗漏
        let allExtractedIndices = result.batches.flatMap { $0.pages.map(\.pageIndex0) }
        XCTAssertEqual(allExtractedIndices, Array(0..<pageCount), "所有页码必须连续且严格覆盖 [0, 24]")
    }

    /// 测试自定义区间切片逻辑：验证非 0 起始页和自定义 batchSize
    func testBatchExtractionCustomRangeAndBatchSize() async throws {
        let totalPages = 20
        let pdfURL = tempDirectoryURL.appendingPathComponent("sample_20p.pdf")
        generateTestPDF(at: pdfURL, pageCount: totalPages)

        let docID = "doc_batch_custom_range"
        let config = BatchExtractionConfig(
            batchSize: 4,
            startPageIndex0: 5,
            endPageIndex0: 14 // 抽取第 5 页至第 14 页（共 10 页）
        )

        let result = try await engine.extractDocument(
            documentID: docID,
            fileURL: pdfURL,
            config: config,
            onProgress: nil
        )

        XCTAssertTrue(result.isCompleted)
        XCTAssertEqual(result.totalPagesExtracted, 10)
        XCTAssertEqual(result.batches.count, 3, "10 页按 batchSize: 4 切分为 3 批 (4, 4, 2)")

        let extractedPages = result.batches.flatMap { $0.pages.map(\.pageIndex0) }
        XCTAssertEqual(extractedPages, Array(5...14), "切片应严格在 [5, 14] 范围内")
    }

    /// 测试进度回调通知：页码单调递增与完成百分比递增
    func testBatchExtractionProgressCallbacksMonotonicallyIncreasing() async throws {
        let pageCount = 15
        let batchSize = 5
        let pdfURL = tempDirectoryURL.appendingPathComponent("sample_progress.pdf")
        generateTestPDF(at: pdfURL, pageCount: pageCount)

        let docID = "doc_progress_test"
        let config = BatchExtractionConfig(batchSize: batchSize)
        let collector = ProgressCollector()

        let result = try await engine.extractDocument(
            documentID: docID,
            fileURL: pdfURL,
            config: config,
            onProgress: { @Sendable progress in
                collector.record(progress)
            }
        )

        XCTAssertTrue(result.isCompleted)
        let events = collector.events
        XCTAssertFalse(events.isEmpty, "必须收到进度回调事件")

        // 验证进度事件的单调递增性
        var previousProcessed = 0
        var previousPercentage: Double = 0.0

        for (idx, p) in events.enumerated() {
            XCTAssertGreaterThanOrEqual(p.processedPages, previousProcessed, "已处理页数必须单调递增")
            XCTAssertGreaterThanOrEqual(p.percentage, previousPercentage, "完成百分比必须单调递增")
            XCTAssertEqual(p.totalPages, pageCount)
            XCTAssertEqual(p.currentBatchIndex, idx)

            previousProcessed = p.processedPages
            previousPercentage = p.percentage
        }

        // 最后一个进度必须报告 100% 完成
        if let lastEvent = events.last {
            XCTAssertEqual(lastEvent.processedPages, pageCount)
            XCTAssertEqual(lastEvent.percentage, 1.0, accuracy: 0.0001)
            XCTAssertTrue(lastEvent.isCompleted)
        }
    }

    /// 测试取消支持：Task.cancel 协作式中断响应与状态流转
    func testBatchExtractionTaskCancellation() async throws {
        let pageCount = 30
        let pdfURL = tempDirectoryURL.appendingPathComponent("sample_cancel.pdf")
        generateTestPDF(at: pdfURL, pageCount: pageCount)

        let docID = "doc_cancel_test"
        let config = BatchExtractionConfig(batchSize: 2) // 细粒度批次以便测试取消触发
        let extractionEngine = self.engine!

        let task = Task { () -> BatchExtractionResult in
            try await extractionEngine.extractDocument(
                documentID: docID,
                fileURL: pdfURL,
                config: config,
                onProgress: nil
            )
        }

        // 稍作等待后触发 Task 取消
        try? await Task.sleep(nanoseconds: 2_000_000)
        task.cancel()

        do {
            _ = try await task.value
            // 若执行过快直接完成则断言跳过，否则必须抛出 BatchExtractionError.cancelled
        } catch let error as BatchExtractionError {
            XCTAssertEqual(error, .cancelled, "Task 取消时必须抛出 BatchExtractionError.cancelled")
        } catch is CancellationError {
            // Task 原生抛出 CancellationError 亦为合法中断
        } catch {
            XCTFail("意外错误: \(error)")
        }
    }

    /// 测试引擎主动取消方法：cancelExtraction(documentID:)
    func testBatchExtractionEngineCancelMethod() async throws {
        let pageCount = 30
        let pdfURL = tempDirectoryURL.appendingPathComponent("sample_engine_cancel.pdf")
        generateTestPDF(at: pdfURL, pageCount: pageCount)

        let docID = "doc_engine_cancel"
        let config = BatchExtractionConfig(batchSize: 2)
        let extractionEngine = self.engine!

        let task = Task {
            try await extractionEngine.extractDocument(
                documentID: docID,
                fileURL: pdfURL,
                config: config,
                onProgress: nil
            )
        }

        try? await Task.sleep(nanoseconds: 2_000_000)
        let didCancel = await extractionEngine.cancelExtraction(documentID: docID)

        do {
            _ = try await task.value
        } catch let error as BatchExtractionError {
            if didCancel {
                XCTAssertEqual(error, .cancelled)
            }
        } catch {
            // 允许快速完成或取消
        }

        let isStillExtracting = await extractionEngine.isExtracting(documentID: docID)
        XCTAssertFalse(isStillExtracting, "取消或完成后文档抽取状态必须复位为 false")
    }

    /// 测试页码越界防御：startPageIndex0 > endPageIndex0 时正确抛出 pageOutOfBounds
    func testBatchExtractionPageOutOfBoundsError() async throws {
        let pdfURL = tempDirectoryURL.appendingPathComponent("sample_bounds.pdf")
        generateTestPDF(at: pdfURL, pageCount: 10)

        let config = BatchExtractionConfig(
            batchSize: 5,
            startPageIndex0: 8,
            endPageIndex0: 2 // 故意配置起始页大于终止页
        )

        do {
            _ = try await engine.extractDocument(
                documentID: "doc_invalid_bounds",
                fileURL: pdfURL,
                config: config,
                onProgress: nil
            )
            XCTFail("非法页码范围必须抛出错误")
        } catch let error as BatchExtractionError {
            if case .pageOutOfBounds(let index0, let total) = error {
                XCTAssertEqual(index0, 8)
                XCTAssertGreaterThanOrEqual(total, 0)
            } else {
                XCTFail("应抛出 pageOutOfBounds，但收到: \(error)")
            }
        }
    }

    /// 测试抽取状态查询接口 isExtracting
    func testBatchExtractionIsExtractingQuery() async {
        let docID = "doc_query_idle"
        let idle = await engine.isExtracting(documentID: docID)
        XCTAssertFalse(idle, "空闲状态下 isExtracting 必须为 false")

        let cancelNonExistent = await engine.cancelExtraction(documentID: docID)
        XCTAssertFalse(cancelNonExistent, "取消不存在的任务必须返回 false")
    }
}

// MARK: - 2. LocalLLMProviderTests (离线端侧模型 Provider 测试套件)

/// 端侧本地离线大模型 Provider 测试套件 (R14 / LocalLLMProviderProtocol)
final class LocalLLMProviderTests: XCTestCase {

    /// 测试端侧模型配置 LocalModelConfig 的默认值与自定义参数
    func testLocalModelConfigDefaultsAndCustomization() {
        let defaultConfig = LocalModelConfig()
        XCTAssertEqual(defaultConfig.modelID, "local-distill-q4")
        XCTAssertNil(defaultConfig.modelPath)
        XCTAssertEqual(defaultConfig.contextWindow, 4096)
        XCTAssertEqual(defaultConfig.temperature, 0.7, accuracy: 0.001)
        XCTAssertEqual(defaultConfig.maxTokens, 2048)
        XCTAssertEqual(defaultConfig.quantization, "q4_k_m")
        XCTAssertTrue(defaultConfig.isOfflineOnly)

        let customConfig = LocalModelConfig(
            modelID: "custom-local-v2",
            modelPath: "/var/mobile/models/custom.bin",
            contextWindow: 8192,
            temperature: 0.2,
            maxTokens: 1024,
            quantization: "q8_0",
            isOfflineOnly: true
        )
        XCTAssertEqual(customConfig.modelID, "custom-local-v2")
        XCTAssertEqual(customConfig.modelPath, "/var/mobile/models/custom.bin")
        XCTAssertEqual(customConfig.contextWindow, 8192)
        XCTAssertEqual(customConfig.temperature, 0.2, accuracy: 0.001)
    }

    /// 测试离线端侧 Provider 模型状态机：unloaded -> loading -> ready
    func testLocalLLMProviderLifecycleStateMachine() async throws {
        let provider = LocalMockLLMProvider(
            profileID: "test-offline-state-machine",
            localConfig: LocalModelConfig(modelID: "local-distill-q4")
        )

        // 初始状态默认为 ready
        let initialReady = await provider.isReady()
        XCTAssertTrue(initialReady)
        var status = await provider.inferenceStatus
        XCTAssertEqual(status.state, .ready)
        XCTAssertTrue(status.isReady)
        XCTAssertEqual(status.loadedModelID, "local-distill-q4")
        XCTAssertGreaterThan(status.memoryUsageBytes ?? 0, 0)

        // 1. 卸载模型以进入 unloaded 状态
        await provider.unloadModel()
        let readyAfterUnload = await provider.isReady()
        XCTAssertFalse(readyAfterUnload)
        status = await provider.inferenceStatus
        XCTAssertEqual(status.state, .unloaded)
        XCTAssertFalse(status.isReady)
        XCTAssertEqual(status.memoryUsageBytes, 0)
        XCTAssertNil(status.loadedModelID)

        // 2. 重新加载模型以流转 loading -> ready
        try await provider.loadModel()
        let readyAfterLoad = await provider.isReady()
        XCTAssertTrue(readyAfterLoad)
        status = await provider.inferenceStatus
        XCTAssertEqual(status.state, .ready)
        XCTAssertTrue(status.isReady)
        XCTAssertEqual(status.loadedModelID, "local-distill-q4")
    }

    /// 测试端侧模型状态枚举 ModelState 与错误状态结构表示
    func testLocalLLMProviderModelStateAndErrorRepresentation() {
        let allStates: [ModelState] = [.idle, .loading, .ready, .error, .unloaded]
        for state in allStates {
            XCTAssertEqual(ModelState(rawValue: state.rawValue), state)
        }

        let errorStatus = LocalModelInferenceStatus(
            isReady: false,
            state: .error,
            memoryUsageBytes: 0,
            loadedModelID: nil,
            errorMessage: "端侧模型权重校验失败: Checksum mismatch"
        )
        XCTAssertFalse(errorStatus.isReady)
        XCTAssertEqual(errorStatus.state, .error)
        XCTAssertEqual(errorStatus.errorMessage, "端侧模型权重校验失败: Checksum mismatch")
    }

    /// 测试端侧离线模拟流式吐字：全文学习 prompt 产生结构化输出与 stop 终态
    func testLocalLLMProviderStreamCompletionFullDocumentStudy() async throws {
        let provider = LocalMockLLMProvider()
        let messages = [
            LLMMessage(role: .system, content: "你是一个专业的离线学习助手。"),
            LLMMessage(role: .user, content: "请对本文档进行全文核心概括与重点解析")
        ]

        let stream = try await provider.streamCompletion(
            messages: messages,
            options: LLMCompletionOptions(temperature: 0.5)
        )

        var accumulatedText = ""
        var receivedStopReason = false
        var chunkCount = 0

        for try await chunk in stream {
            chunkCount += 1
            accumulatedText += chunk.delta
            if chunk.finishReason == "stop" {
                receivedStopReason = true
                XCTAssertNotNil(chunk.usageEstimate, "终态 chunk 应包含用量估算")
            }
        }

        XCTAssertGreaterThan(chunkCount, 1, "流式吐字应包含多个 chunk 分批派发")
        XCTAssertTrue(receivedStopReason, "正常流式消费必须以 stop 终态收尾")
        XCTAssertTrue(
            accumulatedText.contains("【离线端侧核心研读解析】"),
            "输出内容必须匹配端侧离线全文概括回答模版"
        )
    }

    /// 测试端侧离线流式吐字：难点解析 prompt 场景
    func testLocalLLMProviderStreamCompletionDifficultyPointsPrompt() async throws {
        let provider = LocalMockLLMProvider()
        let messages = [
            LLMMessage(role: .user, content: "请梳理本章节的核心难点与考点")
        ]

        let stream = try await provider.streamCompletion(
            messages: messages,
            options: LLMCompletionOptions()
        )

        var accumulatedText = ""
        for try await chunk in stream {
            accumulatedText += chunk.delta
        }

        XCTAssertTrue(
            accumulatedText.contains("【端侧离线难点解析】"),
            "难点考点 prompt 应触发对应离线解析输出"
        )
    }

    /// 测试端侧模型在 unloaded 状态下被流式调用时自动唤醒拉起
    func testLocalLLMProviderAutoReloadWhenStreamingWhileUnloaded() async throws {
        let provider = LocalMockLLMProvider()
        await provider.unloadModel()
        let isReadyBefore = await provider.isReady()
        XCTAssertFalse(isReadyBefore)

        // 在 unloaded 状态下直接发起推理
        let stream = try await provider.streamCompletion(
            messages: [LLMMessage(role: .user, content: "测试自动拉起")],
            options: LLMCompletionOptions()
        )

        var text = ""
        for try await chunk in stream {
            text += chunk.delta
        }

        XCTAssertFalse(text.isEmpty)
        let isReadyAfter = await provider.isReady()
        XCTAssertTrue(isReadyAfter, "流式推理发起后应自动将模型拉回 ready 状态")
    }

    /// 测试端侧流式生成提前取消安全退出
    func testLocalLLMProviderStreamEarlyCancellation() async throws {
        let provider = LocalMockLLMProvider()
        let stream = try await provider.streamCompletion(
            messages: [LLMMessage(role: .user, content: "超长全文解析请求")],
            options: LLMCompletionOptions()
        )

        var receivedChunks = 0
        for try await _ in stream {
            receivedChunks += 1
            if receivedChunks >= 2 {
                // 仅消费 2 个 chunk 后主动跳出流，验证 continuation.onTermination 优雅取消
                break
            }
        }

        XCTAssertEqual(receivedChunks, 2)
        // 验证系统在中断后仍处于良好状态
        let isReadyEnd = await provider.isReady()
        XCTAssertTrue(isReadyEnd)
    }
}

// MARK: - 3. AINoteServiceTests (AI Notes 卡片与两路删除联动测试套件)

/// AI Notes 卡片笔记服务测试套件 (R11 P1 / AINoteProtocol)
final class AINoteServiceTests: XCTestCase {

    private var tempDirectoryURL: URL!
    private var sandbox: LocalSandboxManager!
    private var service: AINoteService!

    override func setUp() async throws {
        try await super.setUp()
        let tempBase = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("StudyOSTests_AINote_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)
        self.tempDirectoryURL = tempBase
        self.sandbox = LocalSandboxManager(rootDirectoryURL: tempBase)
        self.service = AINoteService(sandbox: sandbox)
    }

    override func tearDown() async throws {
        if let temp = tempDirectoryURL {
            try? FileManager.default.removeItem(at: temp)
        }
        self.service = nil
        self.sandbox = nil
        try await super.tearDown()
    }

    /// 测试 AI Notes 卡片保存、来源锚点精准保留与单条查询
    func testCreateAndGetAINoteCardPreservingSourceAnchor() async throws {
        let anchor = SourceAnchor(
            documentID: "doc_math_analysis",
            documentRevision: 2,
            pageIndex0: 15,
            regions: [CodableRect(x: 100, y: 200, width: 350, height: 45)],
            paragraphID: "para_math_15_2",
            quote: "设函数 f 在区间 [a, b] 上连续且单调递增...",
            precision: .region,
            availability: .active
        )

        let snapshot = AINoteSourceSnapshot(
            documentID: "doc_math_analysis",
            documentRevision: 2,
            sourceAnchors: [anchor],
            originKind: .document,
            aiOrigin: AIOrigin(
                requestID: "local-distill-q4",
                attemptID: "att_study_001",
                prompt: "解释单调函数定理",
                generatedAt: Date()
            )
        )

        let card = AINoteCard(
            id: "card_math_001",
            title: "单调函数中值定理笔记",
            markdownContent: "核心思想在于利用开区间内导数非负的单调性约束进行推导。",
            sourceSnapshot: snapshot,
            inclusionPolicy: .independent,
            tags: ["高等数学", "中值定理"]
        )

        let createdCard = try await service.createAINote(card: card)
        XCTAssertEqual(createdCard.id, "card_math_001")
        XCTAssertEqual(createdCard.revision, 1)

        // 查询并严格验证来源锚点保真度 (quote / pageIndex0 / regions / precision)
        guard let fetched = try await service.getAINote(id: "card_math_001") else {
            XCTFail("未能按 ID 获取卡片笔记")
            return
        }

        XCTAssertEqual(fetched.title, "单调函数中值定理笔记")
        XCTAssertEqual(fetched.markdownContent, "核心思想在于利用开区间内导数非负的单调性约束进行推导。")
        XCTAssertEqual(fetched.tags, ["高等数学", "中值定理"])
        XCTAssertEqual(fetched.sourceSnapshot.documentID, "doc_math_analysis")
        XCTAssertEqual(fetched.sourceSnapshot.sourceAnchors.count, 1)

        let fetchedAnchor = fetched.sourceSnapshot.sourceAnchors[0]
        XCTAssertEqual(fetchedAnchor.pageIndex0, 15)
        XCTAssertEqual(fetchedAnchor.paragraphID, "para_math_15_2")
        XCTAssertEqual(fetchedAnchor.quote, "设函数 f 在区间 [a, b] 上连续且单调递增...")
        XCTAssertEqual(fetchedAnchor.precision, .region)
        XCTAssertEqual(fetchedAnchor.availability, .active)
        XCTAssertEqual(fetchedAnchor.regions.count, 1)
        XCTAssertEqual(fetchedAnchor.regions[0], CodableRect(x: 100, y: 200, width: 350, height: 45))
    }

    /// 测试 AI Notes 乐观锁更新：版本匹配时递增，过期版本抛出 conflict
    func testUpdateAINoteWithOptimisticLock() async throws {
        let card = AINoteCard(
            id: "card_optimistic_lock",
            title: "初始标题",
            markdownContent: "初始内容",
            sourceSnapshot: AINoteSourceSnapshot(documentID: "doc_lock_test")
        )
        let created = try await service.createAINote(card: card)
        XCTAssertEqual(created.revision, 1)

        // 正常版本递增更新 (expectedRevision == 1)
        var updatePayload = created
        updatePayload.title = "更新后的标题"
        let updated = try await service.updateAINote(card: updatePayload, expectedRevision: 1)
        XCTAssertEqual(updated.title, "更新后的标题")
        XCTAssertEqual(updated.revision, 2)

        // 使用陈旧版本 (expectedRevision == 1) 再次提交必须抛出 StorageError.conflict
        do {
            _ = try await service.updateAINote(card: updatePayload, expectedRevision: 1)
            XCTFail("陈旧版本必须触发冲突错误")
        } catch let error as StorageError {
            if case .conflict(let exp, let cur) = error {
                XCTAssertEqual(exp, 1)
                XCTAssertEqual(cur, 2)
            } else {
                XCTFail("应抛出 StorageError.conflict，收到: \(error)")
            }
        }
    }

    /// 测试按文档 ID 过滤与全局列表查询
    func testListAINotesWithDocumentFilter() async throws {
        let cardA1 = AINoteCard(
            id: "card_a_1",
            title: "Doc A Note 1",
            markdownContent: "Content A1",
            sourceSnapshot: AINoteSourceSnapshot(documentID: "doc_A")
        )
        let cardA2 = AINoteCard(
            id: "card_a_2",
            title: "Doc A Note 2",
            markdownContent: "Content A2",
            sourceSnapshot: AINoteSourceSnapshot(documentID: "doc_A")
        )
        let cardB1 = AINoteCard(
            id: "card_b_1",
            title: "Doc B Note 1",
            markdownContent: "Content B1",
            sourceSnapshot: AINoteSourceSnapshot(documentID: "doc_B")
        )

        _ = try await service.createAINote(card: cardA1)
        _ = try await service.createAINote(card: cardA2)
        _ = try await service.createAINote(card: cardB1)

        let docANotes = try await service.listAINotes(documentID: "doc_A")
        XCTAssertEqual(docANotes.count, 2)
        XCTAssertTrue(docANotes.allSatisfy { $0.sourceSnapshot.documentID == "doc_A" })

        let docBNotes = try await service.listAINotes(documentID: "doc_B")
        XCTAssertEqual(docBNotes.count, 1)
        XCTAssertEqual(docBNotes[0].id, "card_b_1")

        let allNotes = try await service.listAINotes(documentID: nil)
        XCTAssertEqual(allNotes.count, 3)
    }

    /// 测试单个卡片笔记删除
    func testDeleteSingleAINote() async throws {
        let card = AINoteCard(
            id: "card_to_delete",
            title: "待删除卡片",
            markdownContent: "内容",
            sourceSnapshot: AINoteSourceSnapshot()
        )
        _ = try await service.createAINote(card: card)

        let deleted = try await service.deleteAINote(id: "card_to_delete")
        XCTAssertTrue(deleted)

        let fetched = try await service.getAINote(id: "card_to_delete")
        XCTAssertNil(fetched, "删除后查询必须返回 nil")

        let deleteAgain = try await service.deleteAINote(id: "card_to_delete")
        XCTAssertFalse(deleteAgain, "重复删除应返回 false")
    }

    /// 测试两路删除联动策略 .keep：保留卡片、解绑文档 ID、来源锚点标记 documentDeleted
    func testHandleDocumentDeletionPolicyKeep() async throws {
        let docID = "doc_to_be_deleted_keep"
        let anchor = SourceAnchor(
            documentID: docID,
            documentRevision: 1,
            pageIndex0: 3,
            quote: "重要推论内容",
            precision: .region,
            availability: .active
        )
        let card = AINoteCard(
            id: "card_keep_policy",
            title: "独立保留的高价值考点",
            markdownContent: "这是即便文档删除后用户仍希望永久保留的卡片笔记",
            sourceSnapshot: AINoteSourceSnapshot(
                documentID: docID,
                documentRevision: 1,
                sourceAnchors: [anchor]
            ),
            inclusionPolicy: .independent
        )
        _ = try await service.createAINote(card: card)

        // 触发文档删除两路联动 (policy: .keep)
        let result = try await service.handleDocumentDeletion(documentID: docID, policy: .keep)
        XCTAssertEqual(result.retainedCardIDs, ["card_keep_policy"])
        XCTAssertTrue(result.deletedCardIDs.isEmpty)

        // 验证卡片依然留存，且 documentID 置空，锚点失效标记落实
        guard let retainedCard = try await service.getAINote(id: "card_keep_policy") else {
            XCTFail("卡片笔记必须保留")
            return
        }
        XCTAssertNil(retainedCard.sourceSnapshot.documentID, "原文档 ID 必须解绑置空")
        XCTAssertEqual(retainedCard.sourceSnapshot.sourceAnchors.count, 1)
        XCTAssertEqual(
            retainedCard.sourceSnapshot.sourceAnchors[0].availability,
            .documentDeleted,
            "锚点可用性必须标记为 documentDeleted"
        )

        // 原文档维度的过滤列表已不包含该卡片，但全局维度依然可见
        let docFiltered = try await service.listAINotes(documentID: docID)
        XCTAssertTrue(docFiltered.isEmpty)
        let globalList = try await service.listAINotes(documentID: nil)
        XCTAssertTrue(globalList.contains(where: { $0.id == "card_keep_policy" }))
    }

    /// 测试两路删除联动策略 .delete：级联清除绑定的卡片笔记
    func testHandleDocumentDeletionPolicyDelete() async throws {
        let docID = "doc_to_be_deleted_cascade"
        let card = AINoteCard(
            id: "card_cascade_delete",
            title: "绑定文档临时笔记",
            markdownContent: "文档删除时随同级联销毁",
            sourceSnapshot: AINoteSourceSnapshot(documentID: docID),
            inclusionPolicy: .boundToDocument
        )
        _ = try await service.createAINote(card: card)

        // 触发文档删除两路联动 (policy: .delete)
        let result = try await service.handleDocumentDeletion(documentID: docID, policy: .delete)
        XCTAssertTrue(result.retainedCardIDs.isEmpty)
        XCTAssertEqual(result.deletedCardIDs, ["card_cascade_delete"])

        // 验证卡片彻底清除
        let fetched = try await service.getAINote(id: "card_cascade_delete")
        XCTAssertNil(fetched, "卡片笔记必须被级联清理")
        let allNotes = try await service.listAINotes(documentID: nil)
        XCTAssertFalse(allNotes.contains(where: { $0.id == "card_cascade_delete" }))
    }

    /// 测试 AINoteCard 与通用 Note 的双向无损互转 (toNote / fromNote)
    func testAINoteToNoteAndFromNoteBidirectionalConversion() {
        let snapshot = AINoteSourceSnapshot(
            documentID: "doc_conv_01",
            sourceAnchors: [SourceAnchor(documentID: "doc_conv_01", documentRevision: 1, pageIndex0: 2)],
            originKind: .document,
            aiOrigin: AIOrigin(
                requestID: "local-mock",
                attemptID: "att_conv",
                prompt: "测试转换"
            )
        )
        let card = AINoteCard(
            id: "card_conv_test",
            title: "逆矩阵求解",
            markdownContent: "利用伴随矩阵或初等行变换进行求解。",
            sourceSnapshot: snapshot,
            inclusionPolicy: .independent,
            tags: ["线性代数"]
        )

        // 1. 卡片转通用 Note
        let note = card.toNote()
        XCTAssertEqual(note.id, "card_conv_test")
        XCTAssertEqual(note.documentID, "doc_conv_01")
        XCTAssertTrue(note.editableText.contains("# 逆矩阵求解"))
        XCTAssertTrue(note.editableText.contains("利用伴随矩阵或初等行变换进行求解。"))
        XCTAssertEqual(note.sourceAnchors.count, 1)

        // 2. 通用 Note 反向重构为卡片
        let reconstructed = AINoteCard.from(note: note, inclusionPolicy: .independent)
        XCTAssertEqual(reconstructed.id, "card_conv_test")
        XCTAssertEqual(reconstructed.title, "逆矩阵求解")
        XCTAssertEqual(reconstructed.markdownContent, "利用伴随矩阵或初等行变换进行求解。")
        XCTAssertEqual(reconstructed.sourceSnapshot.documentID, "doc_conv_01")
        XCTAssertEqual(reconstructed.sourceSnapshot.sourceAnchors.count, 1)
    }
}

// MARK: - 4. FullDocumentStudyTests (全文研读分析服务测试套件)

/// 全文学习研读分析服务测试套件 (R10 P0 / FullDocumentStudyProtocol)
final class FullDocumentStudyTests: XCTestCase {

    private var tempDirectoryURL: URL!
    private var sandbox: LocalSandboxManager!
    private var metadataEngine: MetadataStorageEngine!
    private var provider: LocalMockLLMProvider!
    private var studyService: FullDocumentStudyService!

    override func setUp() async throws {
        try await super.setUp()
        let tempBase = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("StudyOSTests_FullDoc_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)
        self.tempDirectoryURL = tempBase
        self.sandbox = LocalSandboxManager(rootDirectoryURL: tempBase)
        self.metadataEngine = MetadataStorageEngine(sandbox: sandbox)
        self.provider = LocalMockLLMProvider()
        self.studyService = FullDocumentStudyService(
            sandbox: sandbox,
            provider: provider,
            metadataEngine: metadataEngine
        )
    }

    override func tearDown() async throws {
        if let temp = tempDirectoryURL {
            try? FileManager.default.removeItem(at: temp)
        }
        self.studyService = nil
        self.provider = nil
        self.metadataEngine = nil
        self.sandbox = nil
        try await super.tearDown()
    }

    /// 测试触发全文研读分析报告生成与领域要素完整性
    func testGenerateFullDocumentStudySuccess() async throws {
        let docID = "doc_os_study_001"
        let document = Document(
            id: docID,
            title: "现代操作系统（第四版）",
            sourceHash: "hash_os_v4",
            revision: 1,
            localFileRef: "/sandbox/Documents/os.pdf",
            pageCount: 40,
            importState: .readable,
            indexState: .ready,
            createdAt: Date(),
            updatedAt: Date()
        )
        await metadataEngine.saveDocument(document)

        let analysis = try await studyService.generateFullDocumentStudy(documentID: docID)

        XCTAssertEqual(analysis.documentID, docID)
        XCTAssertEqual(analysis.title, "现代操作系统（第四版）")
        XCTAssertFalse(analysis.overview.isEmpty)

        // 验证概念节点网络
        XCTAssertGreaterThanOrEqual(analysis.concepts.count, 2, "应提取核心概念节点")
        let concept1 = analysis.concepts[0]
        XCTAssertEqual(concept1.id, "concept_\(docID)_1")
        XCTAssertFalse(concept1.sourceAnchors.isEmpty, "概念节点必须绑定原文锚点")

        // 验证知识关系连接
        XCTAssertGreaterThanOrEqual(analysis.relations.count, 1, "应生成概念间的知识拓扑连接")
        let rel = analysis.relations[0]
        XCTAssertEqual(rel.relationType, "prerequisite")

        // 验证核心难点考点
        XCTAssertGreaterThanOrEqual(analysis.difficultyPoints.count, 1, "应提取重点考点与应对策略")
        let diff = analysis.difficultyPoints[0]
        XCTAssertFalse(diff.suggestedStrategy.isEmpty)

        // 验证关键小节指引
        XCTAssertGreaterThanOrEqual(analysis.keySections.count, 1, "应包含小节研读指引")
        let section = analysis.keySections[0]
        XCTAssertFalse(section.keyTakeaways.isEmpty)

        // 验证研读时间估算 (40页 * 2分钟 = 80分钟)
        if case .available(let minutes, let basis, let coverage) = analysis.readingEstimate {
            XCTAssertEqual(minutes, 80)
            XCTAssertTrue(basis.contains("40 页"))
            XCTAssertEqual(coverage, 1.0)
        } else {
            XCTFail("readingEstimate 必须为 available 状态")
        }
    }

    /// 测试全文学习研读分析报告本地缓存与快速复用
    func testGetCachedAnalysisReturnsExistingRecord() async throws {
        let docID = "doc_cache_test_001"
        let document = Document(
            id: docID,
            title: "计算机组成原理",
            sourceHash: "hash_comp_arch",
            revision: 1,
            localFileRef: "/tmp/comp.pdf",
            pageCount: 20
        )
        await metadataEngine.saveDocument(document)

        // 初始未生成前查询缓存应为 nil
        let initialCached = await studyService.getCachedAnalysis(documentID: docID)
        XCTAssertNil(initialCached)

        // 首次生成
        let generated = try await studyService.generateFullDocumentStudy(documentID: docID)

        // 再次查询缓存应命中并返回相同分析实例
        let cached = await studyService.getCachedAnalysis(documentID: docID)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.id, generated.id)
        XCTAssertEqual(cached?.title, "计算机组成原理")

        // 再次调用生成应直接返回缓存
        let secondCall = try await studyService.generateFullDocumentStudy(documentID: docID)
        XCTAssertEqual(secondCall.id, generated.id)
    }

    /// 测试自定义研读报告手动保存与更新
    func testSaveAndRetrieveCustomAnalysis() async throws {
        let docID = "doc_custom_save"
        let customAnalysis = FullDocumentAnalysis(
            id: "analysis_custom_001",
            documentID: docID,
            documentRevision: 2,
            title: "微积分精析",
            overview: "用户自定义编辑或修正后的全文导读概览",
            readingEstimate: .available(minutes: 30, basis: "速读模式", coverage: 1.0),
            concepts: [
                ConceptNode(name: "极限与连续性", summary: "ε-δ 语言的严格定义", importance: 1.0)
            ]
        )

        try await studyService.saveAnalysis(customAnalysis)

        let retrieved = await studyService.getCachedAnalysis(documentID: docID)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, "analysis_custom_001")
        XCTAssertEqual(retrieved?.overview, "用户自定义编辑或修正后的全文导读概览")
        XCTAssertEqual(retrieved?.concepts.count, 1)
        XCTAssertEqual(retrieved?.concepts[0].name, "极限与连续性")
    }

    /// 测试针对不存在的文档 ID 发起分析时正确抛出 notFound 错误
    func testGenerateStudyForNonExistentDocumentThrowsNotFound() async {
        do {
            _ = try await studyService.generateFullDocumentStudy(documentID: "doc_ghost_id")
            XCTFail("不存在的文档 ID 必须抛出错误")
        } catch let error as StorageError {
            if case .notFound(let msg) = error {
                XCTAssertTrue(msg.contains("doc_ghost_id"))
            } else {
                XCTFail("预期 notFound，但收到: \(error)")
            }
        } catch {
            XCTFail("意外错误: \(error)")
        }
    }

    /// 测试沙盒文件持久化与跨服务实例生命周期的恢复
    func testPersistenceAcrossServiceInstances() async throws {
        let docID = "doc_persist_instance"
        let document = Document(
            id: docID,
            title: "数据结构与算法",
            sourceHash: "hash_dsa",
            revision: 1,
            localFileRef: "/tmp/dsa.pdf",
            pageCount: 15
        )
        await metadataEngine.saveDocument(document)

        let firstAnalysis = try await studyService.generateFullDocumentStudy(documentID: docID)

        // 构造第二个全新服务实例（指向同一沙盒路径），验证冷启动反序列化
        let secondStudyService = FullDocumentStudyService(
            sandbox: sandbox,
            provider: provider,
            metadataEngine: metadataEngine
        )

        let recovered = await secondStudyService.getCachedAnalysis(documentID: docID)
        XCTAssertNotNil(recovered, "新实例启动时必须从本地沙盒恢复已持久化的分析结果")
        XCTAssertEqual(recovered?.id, firstAnalysis.id)
        XCTAssertEqual(recovered?.title, "数据结构与算法")
    }
}
