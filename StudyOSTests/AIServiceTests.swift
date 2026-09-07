import XCTest
@testable import StudyOS

/// 模拟 LLM Provider，支持可配置的流式返回与异常模拟
final class MockLLMProvider: LLMProviderProtocol, @unchecked Sendable {
    let profileID: String
    var snapshot: ProviderSnapshot

    var streamHandler: (@Sendable ([LLMMessage], LLMCompletionOptions) async throws -> AsyncThrowingStream<LLMChunk, Error>)?

    init(
        profileID: String = "mock-openai",
        snapshot: ProviderSnapshot? = nil
    ) {
        self.profileID = profileID
        self.snapshot = snapshot ?? ProviderSnapshot(
            profileID: profileID,
            configRevision: 1,
            endpoint: "https://api.mock.internal/v1",
            model: "mock-gpt-4o"
        )
    }

    func streamCompletion(
        messages: [LLMMessage],
        options: LLMCompletionOptions
    ) async throws -> AsyncThrowingStream<LLMChunk, Error> {
        if let handler = streamHandler {
            return try await handler(messages, options)
        }
        return AsyncThrowingStream { continuation in
            continuation.yield(LLMChunk(delta: "Mock generated output"))
            continuation.finish()
        }
    }
}

/// M2 核心测试套件：AI 助学服务与上下文动态装配验证
/// 涵盖：
/// 1. ContextAggregator 五级上下文清单装配（selection / page / chapter / document / history 聚合与 outboundItems 生成）；
/// 2. AIService 状态机终态互斥：failed 与 cancelled 严格互斥，迟到包不覆盖终态 (alreadyTerminal)；
/// 3. MockLLMProvider 流式吐字与主动取消（Task.cancel() 与 aiService.cancel()）；
/// 4. SourceAnchor 来源有效性校验过滤。
final class AIServiceTests: XCTestCase {

    private var tempDirectoryURL: URL!
    private var sandbox: LocalSandboxManager!
    private var metadataEngine: MetadataStorageEngine!
    private var mockProvider: MockLLMProvider!
    private var aiService: AIService!

    override func setUp() async throws {
        try await super.setUp()
        let tempBase = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("StudyOS_AITests_\(UUID().uuidString)", isDirectory: true)
        self.tempDirectoryURL = tempBase
        self.sandbox = LocalSandboxManager(rootDirectoryURL: tempBase)
        self.metadataEngine = MetadataStorageEngine(sandbox: sandbox)
        self.mockProvider = MockLLMProvider()
        self.aiService = AIService(provider: mockProvider, metadataEngine: metadataEngine)
    }

    override func tearDown() async throws {
        if let temp = tempDirectoryURL {
            try? FileManager.default.removeItem(at: temp)
        }
        try await super.tearDown()
    }

    // MARK: - 1. ContextAggregator 五级上下文装配测试

    /// 测试 Level 1: Selection (选区范围) 上下文聚合与清单生成
    func testContextAggregatorLevel1SelectionScope() {
        let aggregator = ContextAggregator()
        let anchor = SourceAnchor(
            documentID: "doc_test_1",
            documentRevision: 1,
            pageIndex0: 3,
            quote: "Quantum mechanics is a fundamental theory in physics."
        )

        let request = AIRequest(
            requestID: "req_sel",
            attemptID: "att_sel",
            documentID: "doc_test_1",
            documentRevision: 1,
            scope: .selection(anchor: anchor),
            mode: .ask,
            question: "这段话表达的核心概念是什么？",
            selectedAnchor: anchor,
            providerProfileID: "mock-openai"
        )

        let aggregated = aggregator.buildContext(
            request: request,
            providerSnapshot: mockProvider.snapshot,
            document: nil
        )

        let manifest = aggregated.manifest

        // 1. 验证清单基础属性
        XCTAssertEqual(manifest.documentID, "doc_test_1")
        XCTAssertEqual(manifest.documentRevision, 1)
        XCTAssertEqual(manifest.operationKind, AIMode.ask.rawValue)

        // 2. 验证 OutboundItems: 选区文本与提问文本
        let docItems = manifest.outboundItems.filter { $0.kind == .documentText }
        XCTAssertEqual(docItems.count, 1)
        guard let selItem = docItems.first else {
            XCTFail("Missing selection documentText item")
            return
        }
        XCTAssertEqual(selItem.purpose, .generation)
        XCTAssertEqual(selItem.pageCoverage, [3])
        XCTAssertTrue(selItem.payloadDigest.starts(with: "sha256_"))
        XCTAssertEqual(selItem.characterCount, anchor.quote?.count)
        XCTAssertFalse(selItem.containsHandwriting)

        let qItems = manifest.outboundItems.filter { $0.kind == .questionText }
        XCTAssertEqual(qItems.count, 1)

        // 3. 验证页面覆盖范围与 Token 估算
        XCTAssertEqual(manifest.pageCoverage, [3])
        XCTAssertGreaterThan(manifest.estimatedInputTokens, 0)
        XCTAssertEqual(manifest.reservedOutputTokens, 2048)

        // 4. 验证隐私与脱敏状态
        if case .excluded = manifest.originalFileInclusion {
            // PASS: 默认不外发原始 PDF
        } else {
            XCTFail("originalFileInclusion should be excluded")
        }
        if case .excluded = manifest.pageImageInclusion {
            // PASS
        } else {
            XCTFail("pageImageInclusion should be excluded")
        }
        if case .excluded = manifest.handwritingInclusion {
            // PASS
        } else {
            XCTFail("handwritingInclusion should be excluded")
        }
        if case .excluded = manifest.annotationInclusion {
            // PASS: 未勾选批注
        } else {
            XCTFail("annotationInclusion should be excluded")
        }

        // 5. 验证组装的上下文与 Prompt
        XCTAssertTrue(aggregated.assembledText.contains("Quantum mechanics is a fundamental theory in physics."))
        XCTAssertTrue(aggregated.systemPrompt.contains("StudyOS 原生 iPad 阅读学习助学专家"))
        XCTAssertTrue(aggregated.userPrompt.contains("这段话表达的核心概念是什么？"))
    }

    /// 测试 Level 2: Page (单页正文) 上下文聚合
    func testContextAggregatorLevel2PageScope() {
        let aggregator = ContextAggregator()
        let pageTexts: [Int: String] = [
            2: "Chapter 1: The Principle of Least Action. In physics, the path taken by a particle..."
        ]

        let request = AIRequest(
            requestID: "req_page",
            attemptID: "att_page",
            documentID: "doc_test_2",
            documentRevision: 1,
            scope: .page(index0: 2),
            mode: .ask,
            question: "总结这一页的主旨",
            providerProfileID: "mock-openai"
        )

        let aggregated = aggregator.buildContext(
            request: request,
            providerSnapshot: mockProvider.snapshot,
            document: nil,
            pageTexts: pageTexts
        )

        let manifest = aggregated.manifest
        XCTAssertEqual(manifest.pageCoverage, [2])

        let docItems = manifest.outboundItems.filter { $0.kind == .documentText }
        XCTAssertEqual(docItems.count, 1)
        XCTAssertEqual(docItems.first?.sourceIDs, ["page_2"])
        XCTAssertTrue(aggregated.assembledText.contains("The Principle of Least Action"))
    }

    /// 测试 Level 3: Chapter (跨起止页章节) 上下文聚合
    func testContextAggregatorLevel3ChapterScope() {
        let aggregator = ContextAggregator()
        let pageTexts: [Int: String] = [
            10: "Introduction to Thermodynamics. Heat and work are interrelated.",
            11: "The First Law of Thermodynamics: Energy cannot be created or destroyed.",
            12: "The Second Law of Thermodynamics: Entropy of an isolated system always increases."
        ]

        let request = AIRequest(
            requestID: "req_ch",
            attemptID: "att_ch",
            documentID: "doc_test_3",
            documentRevision: 1,
            scope: .chapter(chapterID: "chap_thermo", startPageIndex0: 10, endPageIndex0: 12),
            mode: .guide,
            providerProfileID: "mock-openai"
        )

        let aggregated = aggregator.buildContext(
            request: request,
            providerSnapshot: mockProvider.snapshot,
            document: nil,
            pageTexts: pageTexts
        )

        let manifest = aggregated.manifest
        XCTAssertEqual(manifest.pageCoverage, [10, 11, 12])

        let docItems = manifest.outboundItems.filter { $0.kind == .documentText }
        XCTAssertEqual(docItems.count, 3)

        // 验证每一页文本均被包含
        XCTAssertTrue(aggregated.assembledText.contains("Introduction to Thermodynamics"))
        XCTAssertTrue(aggregated.assembledText.contains("The First Law of Thermodynamics"))
        XCTAssertTrue(aggregated.assembledText.contains("The Second Law of Thermodynamics"))
    }

    /// 测试 Level 4: Document (全篇范围 - 包含章节大纲与元数据回退)
    func testContextAggregatorLevel4DocumentScope() {
        let aggregator = ContextAggregator()

        // 场景 A: 存在章节列表，聚合大纲摘要
        let chapters = [
            Chapter(documentID: "doc_full", documentRevision: 1, title: "第一章 基础概念", startPageIndex0: 0, endPageIndex0: 4),
            Chapter(documentID: "doc_full", documentRevision: 1, title: "第二章 核心推导", startPageIndex0: 5, endPageIndex0: 15)
        ]

        let reqA = AIRequest(
            documentID: "doc_full",
            documentRevision: 1,
            scope: .document,
            mode: .guide,
            providerProfileID: "mock-openai"
        )

        let aggA = aggregator.buildContext(
            request: reqA,
            providerSnapshot: mockProvider.snapshot,
            document: nil,
            chapters: chapters
        )

        let outlineItems = aggA.manifest.outboundItems.filter { $0.sourceIDs.contains("outline_summary") }
        XCTAssertEqual(outlineItems.count, 1)
        XCTAssertTrue(aggA.assembledText.contains("第一章 基础概念 (第 1 ~ 5 页)"))
        XCTAssertTrue(aggA.assembledText.contains("第二章 核心推导 (第 6 ~ 16 页)"))
        XCTAssertEqual(aggA.manifest.pageCoverage, Array(0...15))

        // 场景 B: 章节为空，回退到 Document 元数据摘要
        let docMeta = Document(
            id: "doc_meta",
            title: "高等电磁理论",
            sourceHash: "hash_abc",
            revision: 2,
            localFileRef: "docs/doc_meta.pdf",
            pageCount: 120
        )

        let reqB = AIRequest(
            documentID: "doc_meta",
            documentRevision: 2,
            scope: .document,
            mode: .ask,
            question: "本书概览",
            providerProfileID: "mock-openai"
        )

        let aggB = aggregator.buildContext(
            request: reqB,
            providerSnapshot: mockProvider.snapshot,
            document: docMeta,
            chapters: []
        )

        let metaItems = aggB.manifest.outboundItems.filter { $0.sourceIDs.contains("document_meta") }
        XCTAssertEqual(metaItems.count, 1)
        XCTAssertTrue(aggB.assembledText.contains("文档标题: 高等电磁理论, 总页数: 120"))
    }

    /// 测试 Level 5: Conversation (多轮问答历史与批注显式勾选)
    func testContextAggregatorLevel5HistoryAndAnnotations() {
        let aggregator = ContextAggregator()
        let history: [LLMMessage] = [
            LLMMessage(role: .user, content: "什么是薛定谔方程？"),
            LLMMessage(role: .assistant, content: "薛定谔方程是量子力学中描述微观粒子状态随时间演化的基本方程。")
        ]

        let request = AIRequest(
            documentID: "doc_5",
            documentRevision: 1,
            scope: .page(index0: 1),
            mode: .ask,
            question: "它的定态形式是什么？",
            annotationIDs: ["anno_101", "anno_102"],
            providerProfileID: "mock-openai"
        )

        let aggregated = aggregator.buildContext(
            request: request,
            providerSnapshot: mockProvider.snapshot,
            document: nil,
            conversationHistory: history
        )

        let manifest = aggregated.manifest

        // 验证多轮历史 OutboundItem
        let historyItems = manifest.outboundItems.filter { $0.kind == .conversationText }
        XCTAssertEqual(historyItems.count, 1)
        XCTAssertEqual(historyItems.first?.sourceIDs, ["conversation_history"])

        // 验证批注勾选状态
        if case .included(let itemIDs) = manifest.annotationInclusion {
            XCTAssertEqual(itemIDs, ["anno_101", "anno_102"])
        } else {
            XCTFail("annotationInclusion should include anno_101 and anno_102")
        }
    }

    // MARK: - 2. AIService 状态机终态互斥测试 (failed 与 cancelled 互斥 & alreadyTerminal 防御)

    /// 测试正常流式消费：完整逐 chunk 吐字与 completed 终态，并验证已完成请求不可再取消
    func testAIServiceStreamingSuccessAndTerminalCompleted() async throws {
        let chunks = [
            LLMChunk(delta: "第一段内容。"),
            LLMChunk(delta: "第二段推导。"),
            LLMChunk(delta: "总结完毕。", finishReason: "stop", usageEstimate: 25)
        ]

        mockProvider.streamHandler = { @Sendable _, _ in
            AsyncThrowingStream { continuation in
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }

        let request = AIRequest(
            requestID: "req_norm",
            attemptID: "att_norm_1",
            documentID: "doc_norm",
            documentRevision: 1,
            scope: .page(index0: 0),
            mode: .ask,
            question: "正常生成测试",
            providerProfileID: "mock-openai"
        )

        let manifest = ContextManifest(
            documentID: "doc_norm",
            documentRevision: 1,
            operationKind: "ask",
            providerSnapshot: mockProvider.snapshot
        )

        let stream = try await aiService.generateStream(request: request, manifest: manifest)

        var receivedDeltas: [String] = []
        for try await chunk in stream {
            receivedDeltas.append(chunk.delta)
        }

        XCTAssertEqual(receivedDeltas, ["第一段内容。", "第二段推导。", "总结完毕。"])

        // 1. alreadyTerminal 防御：已完成的请求，调用 cancel 必须返回 false
        let cancelResult = await aiService.cancel(requestID: "req_norm", attemptID: "att_norm_1")
        XCTAssertFalse(cancelResult, "Completed attempt cannot be cancelled (alreadyTerminal)")

        // 2. 禁止同一 attempt 重复进入
        do {
            _ = try await aiService.generateStream(request: request, manifest: manifest)
            XCTFail("Duplicate generateStream on completed attempt must throw")
        } catch let LLMProviderError.invalidResponse(msg) {
            XCTAssertTrue(msg.contains("completed") && msg.contains("禁止重复执行"))
        }
    }

    /// 测试流式异常失败：failed 终态确定，且与 cancelled 严格互斥，迟到 cancel 不得覆写
    func testAIServiceStreamingFailureTerminalExclusivity() async throws {
        mockProvider.streamHandler = { @Sendable _, _ in
            AsyncThrowingStream { continuation in
                continuation.yield(LLMChunk(delta: "Partially emitted text."))
                continuation.finish(throwing: LLMProviderError.serverError(statusCode: 503, "Service Unavailable"))
            }
        }

        let request = AIRequest(
            requestID: "req_fail",
            attemptID: "att_fail_1",
            documentID: "doc_fail",
            documentRevision: 1,
            scope: .page(index0: 0),
            mode: .ask,
            question: "异常失败测试",
            providerProfileID: "mock-openai"
        )

        let manifest = ContextManifest(
            documentID: "doc_fail",
            documentRevision: 1,
            operationKind: "ask",
            providerSnapshot: mockProvider.snapshot
        )

        let stream = try await aiService.generateStream(request: request, manifest: manifest)

        var caughtError: Error?
        do {
            for try await chunk in stream {
                XCTAssertEqual(chunk.delta, "Partially emitted text.")
            }
        } catch {
            caughtError = error
        }

        guard let caughtError = caughtError as? LLMProviderError else {
            XCTFail("Expected LLMProviderError, got: \(String(describing: caughtError))")
            return
        }

        if case .serverError(let code, _) = caughtError {
            XCTAssertEqual(code, 503)
        } else {
            XCTFail("Expected serverError 503, got \(caughtError)")
        }

        // 契约验证：已失败的 attempt 调用 cancel 必须返回 false（严防 cancelled 覆写 failed）
        let cancelAfterFailure = await aiService.cancel(requestID: "req_fail", attemptID: "att_fail_1")
        XCTAssertFalse(cancelAfterFailure, "Failed attempt must not be overwritten by cancel (alreadyTerminal)")

        // 验证内部记录的终态仍为 failed
        do {
            _ = try await aiService.generateStream(request: request, manifest: manifest)
            XCTFail("Duplicate generateStream on failed attempt must throw")
        } catch let LLMProviderError.invalidResponse(msg) {
            XCTAssertTrue(msg.contains("failed") && msg.contains("禁止重复执行"))
        }
    }

    /// 测试主动取消机制：cancel(requestID:attemptID:) 触发 cancelled 终态与二次取消拦截
    func testAIServiceCancelMidStreamExclusivity() async throws {
        // 创建一个会延迟吐字的流
        mockProvider.streamHandler = { @Sendable _, _ in
            AsyncThrowingStream { continuation in
                let task = Task {
                    continuation.yield(LLMChunk(delta: "Chunk before cancel"))
                    do {
                        // 挂起等待外部取消
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                        continuation.yield(LLMChunk(delta: "Late chunk after sleep"))
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: LLMProviderError.cancelled)
                    }
                }
                continuation.onTermination = { @Sendable _ in
                    task.cancel()
                }
            }
        }

        let request = AIRequest(
            requestID: "req_cancel",
            attemptID: "att_cancel_1",
            documentID: "doc_cancel",
            documentRevision: 1,
            scope: .page(index0: 0),
            mode: .ask,
            question: "取消测试",
            providerProfileID: "mock-openai"
        )

        let manifest = ContextManifest(
            documentID: "doc_cancel",
            documentRevision: 1,
            operationKind: "ask",
            providerSnapshot: mockProvider.snapshot
        )

        let service = self.aiService!
        let stream = try await service.generateStream(request: request, manifest: manifest)

        // 异步等待流首包吐字后主动触发取消
        let cancelTask = Task { () -> (Bool, Bool) in
            // 给流足够的时间开始吐字并注册 running attempt
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            let firstCancel = await service.cancel(requestID: "req_cancel", attemptID: "att_cancel_1")
            // 二次取消：触发 alreadyTerminal 防御
            let secondCancel = await service.cancel(requestID: "req_cancel", attemptID: "att_cancel_1")
            return (firstCancel, secondCancel)
        }

        var streamCancelledError: Error?
        do {
            for try await _ in stream {
                // 读取 chunk
            }
        } catch {
            streamCancelledError = error
        }

        let (firstCancel, secondCancel) = await cancelTask.value
        XCTAssertTrue(firstCancel, "First cancel on running attempt must succeed")
        XCTAssertFalse(secondCancel, "Second cancel on already cancelled attempt must return false")

        guard let err = streamCancelledError as? LLMProviderError, case .cancelled = err else {
            XCTFail("Expected LLMProviderError.cancelled, got \(String(describing: streamCancelledError))")
            return
        }

        // 终态验证：已 cancelled 的 attempt 再次触发必须抛出已进入终态 (cancelled)
        do {
            _ = try await aiService.generateStream(request: request, manifest: manifest)
            XCTFail("Duplicate generateStream on cancelled attempt must throw")
        } catch let LLMProviderError.invalidResponse(msg) {
            XCTAssertTrue(msg.contains("cancelled") && msg.contains("禁止重复执行"))
        }
    }

    /// 测试 Task.cancel() 上层流取消级联
    func testAIServiceTaskCancellationTriggersCancelled() async throws {
        mockProvider.streamHandler = { @Sendable _, _ in
            AsyncThrowingStream { continuation in
                let task = Task {
                    continuation.yield(LLMChunk(delta: "Chunk 1"))
                    do {
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                        continuation.yield(LLMChunk(delta: "Chunk 2"))
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: LLMProviderError.cancelled)
                    }
                }
                continuation.onTermination = { @Sendable _ in
                    task.cancel()
                }
            }
        }

        let request = AIRequest(
            requestID: "req_task_cancel",
            attemptID: "att_task_cancel_1",
            documentID: "doc_tc",
            documentRevision: 1,
            scope: .page(index0: 0),
            mode: .ask,
            question: "Task 取消测试",
            providerProfileID: "mock-openai"
        )

        let manifest = ContextManifest(
            documentID: "doc_tc",
            documentRevision: 1,
            operationKind: "ask",
            providerSnapshot: mockProvider.snapshot
        )

        let service = self.aiService!
        let consumerTask = Task<Error?, Never> {
            do {
                let stream = try await service.generateStream(request: request, manifest: manifest)
                for try await _ in stream {
                    // 读取首包后外部将取消
                    try Task.checkCancellation()
                }
                try Task.checkCancellation()
                return nil
            } catch {
                return error
            }
        }

        // 稍作等待让流建立并产出首包
        try await Task.sleep(nanoseconds: 50_000_000)
        consumerTask.cancel()

        let caughtError = await consumerTask.value
        guard let err = caughtError as? LLMProviderError, case .cancelled = err else {
            XCTAssertTrue(caughtError is CancellationError || caughtError is LLMProviderError)
            return
        }

        // 验证终态已置为 cancelled，调用 cancel 返回 false
        let cancelRes = await aiService.cancel(requestID: "req_task_cancel", attemptID: "att_task_cancel_1")
        XCTAssertFalse(cancelRes, "Already cancelled task cannot be cancelled again")
    }

    /// 测试并发重复触发正在运行中的相同 attempt 被拒绝
    func testAIServiceDuplicateRunningAttemptRejected() async throws {
        mockProvider.streamHandler = { @Sendable _, _ in
            AsyncThrowingStream { continuation in
                let task = Task {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                    continuation.finish()
                }
                continuation.onTermination = { @Sendable _ in
                    task.cancel()
                }
            }
        }

        let request = AIRequest(
            requestID: "req_dup",
            attemptID: "att_dup_1",
            documentID: "doc_dup",
            documentRevision: 1,
            scope: .page(index0: 0),
            mode: .ask,
            question: "并发测试",
            providerProfileID: "mock-openai"
        )

        let manifest = ContextManifest(
            documentID: "doc_dup",
            documentRevision: 1,
            operationKind: "ask",
            providerSnapshot: mockProvider.snapshot
        )

        let _ = try await aiService.generateStream(request: request, manifest: manifest)

        // 在同一 attempt 仍在运行中时再次发起
        do {
            _ = try await aiService.generateStream(request: request, manifest: manifest)
            XCTFail("Duplicate generateStream on running attempt must throw")
        } catch let LLMProviderError.invalidResponse(msg) {
            XCTAssertTrue(msg.contains("正在运行中"))
        }

        // 清理
        _ = await aiService.cancel(requestID: "req_dup", attemptID: "att_dup_1")
    }

    // MARK: - 3. SourceAnchor 来源校验过滤测试

    func testValidateSourcesFiltering() async {
        let validDoc = Document(
            id: "doc_valid",
            title: "有效文档",
            sourceHash: "hash_valid",
            revision: 2,
            localFileRef: "docs/valid.pdf",
            pageCount: 10
        )
        await metadataEngine.saveDocument(validDoc)

        let validAnchor = SourceAnchor(
            documentID: "doc_valid",
            documentRevision: 2,
            pageIndex0: 5,
            availability: .active
        )

        let deletedAnchor = SourceAnchor(
            documentID: "doc_valid",
            documentRevision: 2,
            pageIndex0: 5,
            availability: .documentDeleted
        )

        let nonExistentDocAnchor = SourceAnchor(
            documentID: "doc_ghost",
            documentRevision: 1,
            pageIndex0: 0,
            availability: .active
        )

        let revMismatchAnchor = SourceAnchor(
            documentID: "doc_valid",
            documentRevision: 1, // 当前为 2
            pageIndex0: 5,
            availability: .active
        )

        let pageOutOfRangeAnchorHigh = SourceAnchor(
            documentID: "doc_valid",
            documentRevision: 2,
            pageIndex0: 10, // 总页数 10，有效下标 0...9
            availability: .active
        )

        let pageOutOfRangeAnchorNegative = SourceAnchor(
            documentID: "doc_valid",
            documentRevision: 2,
            pageIndex0: -1,
            availability: .active
        )

        let inputSources = [
            validAnchor,
            deletedAnchor,
            nonExistentDocAnchor,
            revMismatchAnchor,
            pageOutOfRangeAnchorHigh,
            pageOutOfRangeAnchorNegative
        ]

        let validated = await aiService.validateSources(sources: inputSources)

        XCTAssertEqual(validated.count, 1)
        XCTAssertEqual(validated.first?.documentID, "doc_valid")
        XCTAssertEqual(validated.first?.pageIndex0, 5)
    }
}
