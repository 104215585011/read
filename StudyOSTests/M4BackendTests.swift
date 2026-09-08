import XCTest
import CryptoKit
@testable import StudyOS

// MARK: - M4 Backend Test Helpers & Mocks

/// 专为 M4 后端测试设计的云端 LLM Provider 模拟桩
private final class M4MockCloudLLMProvider: LLMProviderProtocol, @unchecked Sendable {
    let profileID: String
    var snapshot: ProviderSnapshot
    private let lock = NSLock()

    private var _streamHandler: (@Sendable ([LLMMessage], LLMCompletionOptions) async throws -> AsyncThrowingStream<LLMChunk, Error>)?
    private var _callCount: Int = 0

    init(
        profileID: String = "m4-mock-cloud",
        snapshot: ProviderSnapshot? = nil
    ) {
        self.profileID = profileID
        self.snapshot = snapshot ?? ProviderSnapshot(
            profileID: profileID,
            configRevision: 1,
            endpoint: "https://api.mock.cloud/v1",
            model: "mock-gpt-4o"
        )
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _callCount
    }

    func setStreamHandler(_ handler: @escaping @Sendable ([LLMMessage], LLMCompletionOptions) async throws -> AsyncThrowingStream<LLMChunk, Error>) {
        lock.lock()
        _streamHandler = handler
        lock.unlock()
    }

    private func incrementCallCountAndGetHandler() -> (@Sendable ([LLMMessage], LLMCompletionOptions) async throws -> AsyncThrowingStream<LLMChunk, Error>)? {
        lock.lock()
        defer { lock.unlock() }
        _callCount += 1
        return _streamHandler
    }

    func streamCompletion(
        messages: [LLMMessage],
        options: LLMCompletionOptions
    ) async throws -> AsyncThrowingStream<LLMChunk, Error> {
        let handler = incrementCallCountAndGetHandler()

        if let handler = handler {
            return try await handler(messages, options)
        }

        return AsyncThrowingStream { continuation in
            continuation.yield(LLMChunk(delta: "Cloud generated stream chunk"))
            continuation.finish()
        }
    }
}

/// 专为 M4 测试设计的模拟端侧离线 Provider 桩，支持可控就绪状态
private actor M4MockLocalProvider: LocalLLMProviderProtocol {
    nonisolated let profileID: String
    nonisolated let localConfig: LocalModelConfig
    private var _ready: Bool
    private var _streamCallCount: Int = 0

    init(
        profileID: String = "m4-mock-local",
        localConfig: LocalModelConfig = LocalModelConfig(),
        isReady: Bool = true
    ) {
        self.profileID = profileID
        self.localConfig = localConfig
        self._ready = isReady
    }

    nonisolated var snapshot: ProviderSnapshot {
        ProviderSnapshot(
            profileID: profileID,
            endpoint: "offline://local-engine",
            model: localConfig.modelID
        )
    }

    nonisolated var runtimeKind: LocalRuntimeKind {
        localConfig.runtimeKind
    }

    var inferenceStatus: LocalModelInferenceStatus {
        LocalModelInferenceStatus(
            isReady: _ready,
            state: _ready ? .ready : .unloaded,
            memoryUsageBytes: _ready ? 256 * 1024 * 1024 : 0,
            loadedModelID: _ready ? localConfig.modelID : nil,
            runtimeKind: localConfig.runtimeKind
        )
    }

    func loadModel() async throws {
        _ready = true
    }

    func unloadModel() async {
        _ready = false
    }

    func isReady() async -> Bool {
        _ready
    }

    func setReady(_ ready: Bool) {
        self._ready = ready
    }

    var streamCallCount: Int {
        _streamCallCount
    }

    func streamCompletion(
        messages: [LLMMessage],
        options: LLMCompletionOptions
    ) async throws -> AsyncThrowingStream<LLMChunk, Error> {
        _streamCallCount += 1
        return AsyncThrowingStream { continuation in
            continuation.yield(LLMChunk(delta: "Local offline generated response"))
            continuation.finish()
        }
    }
}

// MARK: - 1. NetworkResilienceTests (弱网弹性重试恢复引擎测试套件)

/// 弱网与网络弹性重试引擎自动化测试套件 (R12 / NetworkResilienceRetryEngine)
final class NetworkResilienceTests: XCTestCase {

    private var engine: NetworkResilienceRetryEngine!

    override func setUp() async throws {
        try await super.setUp()
        self.engine = NetworkResilienceRetryEngine()
    }

    override func tearDown() async throws {
        self.engine = nil
        try await super.tearDown()
    }

    // MARK: - RetryPolicy 基础配置与默认值测试

    /// 测试 RetryPolicy 默认配置参数
    func testRetryPolicyDefaultValues() {
        let policy = RetryPolicy.default
        XCTAssertEqual(policy.maxAttempts, 3)
        XCTAssertEqual(policy.initialDelaySeconds, 0.5, accuracy: 0.001)
        XCTAssertEqual(policy.backoffMultiplier, 2.0, accuracy: 0.001)
        XCTAssertEqual(policy.maxDelaySeconds, 8.0, accuracy: 0.001)
        XCTAssertEqual(policy.jitterFactor, 0.2, accuracy: 0.001)
    }

    /// 测试 RetryPolicy.none 无重试策略
    func testRetryPolicyNone() {
        let policy = RetryPolicy.none
        XCTAssertEqual(policy.maxAttempts, 1)
        XCTAssertEqual(policy.initialDelaySeconds, 0.0)
        XCTAssertEqual(policy.delay(forAttempt: 1), 0.0)
    }

    // MARK: - 指数退避与 Jitter 算法验证

    /// 测试确定性指数退避计算（关闭 Jitter 因子）
    func testExponentialBackoffDeterministicCalculation() {
        let policy = RetryPolicy(
            maxAttempts: 5,
            initialDelaySeconds: 1.0,
            backoffMultiplier: 2.0,
            maxDelaySeconds: 10.0,
            jitterFactor: 0.0
        )

        XCTAssertEqual(policy.delay(forAttempt: 0), 0.0)
        XCTAssertEqual(policy.delay(forAttempt: 1), 1.0, accuracy: 0.001) // 1.0 * 2^0 = 1.0
        XCTAssertEqual(policy.delay(forAttempt: 2), 2.0, accuracy: 0.001) // 1.0 * 2^1 = 2.0
        XCTAssertEqual(policy.delay(forAttempt: 3), 4.0, accuracy: 0.001) // 1.0 * 2^2 = 4.0
        XCTAssertEqual(policy.delay(forAttempt: 4), 8.0, accuracy: 0.001) // 1.0 * 2^3 = 8.0
        XCTAssertEqual(policy.delay(forAttempt: 5), 10.0, accuracy: 0.001) // 1.0 * 2^4 = 16.0 -> 截断至 maxDelay 10.0
        XCTAssertEqual(policy.delay(forAttempt: 6), 10.0, accuracy: 0.001)
    }

    /// 测试抗雷崩 Jitter 随机抖动边界在指定百分比区间内
    func testJitterBoundsWithinExpectedFactor() {
        let jitter = 0.2
        let initial = 2.0
        let policy = RetryPolicy(
            maxAttempts: 3,
            initialDelaySeconds: initial,
            backoffMultiplier: 1.0,
            maxDelaySeconds: 10.0,
            jitterFactor: jitter
        )

        let minExpected = initial * (1.0 - jitter) // 1.6
        let maxExpected = initial * (1.0 + jitter) // 2.4

        for _ in 0..<30 {
            let delay = policy.delay(forAttempt: 1)
            XCTAssertGreaterThanOrEqual(delay, minExpected - 0.0001, "延迟值不应低于下界")
            XCTAssertLessThanOrEqual(delay, maxExpected + 0.0001, "延迟值不应高于上界")
        }
    }

    // MARK: - 错误类型重试判定判定准则测试

    /// 测试典型网络故障与超时的可重试判定
    func testRetryableErrorsClassification() {
        let policy = RetryPolicy.default

        // LLMProviderError 可重试集合
        XCTAssertTrue(policy.canRetry(error: LLMProviderError.networkError("连接断开")))
        XCTAssertTrue(policy.canRetry(error: LLMProviderError.timeout))
        XCTAssertTrue(policy.canRetry(error: LLMProviderError.rateLimited(retryAfterSeconds: 3, "限频")))
        XCTAssertTrue(policy.canRetry(error: LLMProviderError.serverError(statusCode: 500, "Internal Server Error")))
        XCTAssertTrue(policy.canRetry(error: LLMProviderError.serverError(statusCode: 502, "Bad Gateway")))
        XCTAssertTrue(policy.canRetry(error: LLMProviderError.serverError(statusCode: 503, "Service Unavailable")))
        XCTAssertTrue(policy.canRetry(error: LLMProviderError.serverError(statusCode: 504, "Gateway Timeout")))

        // NSURLErrorDomain 常见网络临时故障
        let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let cannotConnectError = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost)
        let connectionLostError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost)
        let notConnectedError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        let dnsError = NSError(domain: NSURLErrorDomain, code: NSURLErrorDNSLookupFailed)

        XCTAssertTrue(policy.canRetry(error: timeoutError))
        XCTAssertTrue(policy.canRetry(error: cannotConnectError))
        XCTAssertTrue(policy.canRetry(error: connectionLostError))
        XCTAssertTrue(policy.canRetry(error: notConnectedError))
        XCTAssertTrue(policy.canRetry(error: dnsError))
    }

    /// 测试不可重试终态错误的精准拦截（杜绝盲目重试）
    func testNonRetryableTerminalErrorsClassification() {
        let policy = RetryPolicy.default

        // 终态错误与鉴权错误不可重试
        XCTAssertFalse(policy.canRetry(error: LLMProviderError.unauthorized("API Key 无效")))
        XCTAssertFalse(policy.canRetry(error: LLMProviderError.cancelled))
        XCTAssertFalse(policy.canRetry(error: LLMProviderError.unsupportedCapability("Vision 不支持")))
        XCTAssertFalse(policy.canRetry(error: LLMProviderError.invalidResponse("返回畸形 JSON")))

        // 4xx 客户端错误不可重试
        XCTAssertFalse(policy.canRetry(error: LLMProviderError.serverError(statusCode: 400, "Bad Request")))
        XCTAssertFalse(policy.canRetry(error: LLMProviderError.serverError(statusCode: 401, "Unauthorized")))
        XCTAssertFalse(policy.canRetry(error: LLMProviderError.serverError(statusCode: 403, "Forbidden")))
        XCTAssertFalse(policy.canRetry(error: LLMProviderError.serverError(statusCode: 404, "Not Found")))

        // 用户主动取消的 URL 请求不可重试
        let cancelledURL = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        XCTAssertFalse(policy.canRetry(error: cancelledURL))

        // 未知领域错误不可重试
        let customDomainError = NSError(domain: "CustomDomain", code: 999)
        XCTAssertFalse(policy.canRetry(error: customDomainError))
    }

    /// 测试自定义可重试断言闭包扩展能力
    func testCustomRetryablePredicate() {
        let policy = RetryPolicy(
            maxAttempts: 3,
            initialDelaySeconds: 0.01,
            retryablePredicate: { error in
                if let llm = error as? LLMProviderError, case .unsupportedCapability = llm {
                    return true // 特殊定制允许重试
                }
                return false
            }
        )

        XCTAssertTrue(policy.canRetry(error: LLMProviderError.unsupportedCapability("test")))
        XCTAssertFalse(policy.canRetry(error: LLMProviderError.networkError("test")))
    }

    // MARK: - RetryEngine 执行机制与统计验证

    /// 测试无故障时一次执行成功，无额外重试开销
    func testRetryEngineSuccessWithoutRetry() async throws {
        let fastPolicy = RetryPolicy(maxAttempts: 3, initialDelaySeconds: 0.001)

        let result = try await engine.execute(policy: fastPolicy, operationID: "op-1") {
            return "SUCCESS_VALUE"
        }

        XCTAssertEqual(result, "SUCCESS_VALUE")
        let stats = await engine.getStats()
        XCTAssertEqual(stats.totalOperations, 1)
        XCTAssertEqual(stats.totalRetries, 0)
        XCTAssertEqual(stats.successfulRetries, 0)
        XCTAssertEqual(stats.nonRetryableFailures, 0)
        XCTAssertEqual(stats.exhaustedFailures, 0)
    }

    /// 测试瞬态故障在第 3 次尝试时成功恢复
    func testRetryEngineTransientFailureRecoversOnRetry() async throws {
        let fastPolicy = RetryPolicy(
            maxAttempts: 4,
            initialDelaySeconds: 0.005,
            backoffMultiplier: 1.5,
            jitterFactor: 0.0
        )

        final class AttemptCounter: @unchecked Sendable {
            private let lock = NSLock()
            private var count = 0
            func increment() -> Int {
                lock.lock()
                defer { lock.unlock() }
                count += 1
                return count
            }
        }

        let counter = AttemptCounter()

        let result = try await engine.execute(policy: fastPolicy, operationID: "op-retry-success") {
            let attempt = counter.increment()
            if attempt < 3 {
                throw LLMProviderError.networkError("临时网络闪断 attempt=\(attempt)")
            }
            return "RECOVERED_VALUE"
        }

        XCTAssertEqual(result, "RECOVERED_VALUE")
        let stats = await engine.getStats()
        XCTAssertEqual(stats.totalOperations, 1)
        XCTAssertEqual(stats.totalRetries, 2, "经历了两次重试")
        XCTAssertEqual(stats.successfulRetries, 1, "最终重试成功归正")
        XCTAssertEqual(stats.exhaustedFailures, 0)
    }

    /// 测试不可重试错误立即抛出阻断，不发生多余重试
    func testRetryEngineNonRetryableFailsImmediately() async throws {
        let fastPolicy = RetryPolicy(maxAttempts: 3, initialDelaySeconds: 0.005)

        final class AttemptCounter: @unchecked Sendable {
            private let lock = NSLock()
            private var count = 0
            func increment() -> Int {
                lock.lock()
                defer { lock.unlock() }
                count += 1
                return count
            }
            var currentCount: Int {
                lock.lock()
                defer { lock.unlock() }
                return count
            }
        }

        let counter = AttemptCounter()

        do {
            _ = try await engine.execute(policy: fastPolicy, operationID: "op-unauth") {
                _ = counter.increment()
                throw LLMProviderError.unauthorized("未授权的 Token")
            }
            XCTFail("应立即抛出不可重试异常")
        } catch let error as LLMProviderError {
            if case .unauthorized = error {
                // 正确拦截
            } else {
                XCTFail("非预期的错误类型: \(error)")
            }
        }

        XCTAssertEqual(counter.currentCount, 1, "不可重试错误下仅应执行 1 次")
        let stats = await engine.getStats()
        XCTAssertEqual(stats.totalOperations, 1)
        XCTAssertEqual(stats.totalRetries, 0, "不可重试错误不应触发任何重试")
        XCTAssertEqual(stats.nonRetryableFailures, 1)
    }

    /// 测试达到最大重试次数后耗尽抛出异常
    func testRetryEngineExhaustedRetriesThrows() async throws {
        let maxAttempts = 3
        let fastPolicy = RetryPolicy(maxAttempts: maxAttempts, initialDelaySeconds: 0.002, jitterFactor: 0.0)

        final class AttemptCounter: @unchecked Sendable {
            private let lock = NSLock()
            private var count = 0
            func increment() -> Int {
                lock.lock()
                defer { lock.unlock() }
                count += 1
                return count
            }
            var currentCount: Int {
                lock.lock()
                defer { lock.unlock() }
                return count
            }
        }

        let counter = AttemptCounter()

        do {
            _ = try await engine.execute(policy: fastPolicy, operationID: "op-exhausted") {
                _ = counter.increment()
                throw LLMProviderError.timeout
            }
            XCTFail("重试耗尽后应抛出超时异常")
        } catch let error as LLMProviderError {
            if case .timeout = error {
                // 正确抛出终态
            } else {
                XCTFail("非预期错误: \(error)")
            }
        }

        XCTAssertEqual(counter.currentCount, 3, "应当严格重试到第 3 次")
        let stats = await engine.getStats()
        XCTAssertEqual(stats.totalOperations, 1)
        XCTAssertEqual(stats.totalRetries, 2, "第 1 次失败后重试 1 次，第 2 次失败后重试第 2 次")
        XCTAssertEqual(stats.exhaustedFailures, 1)
    }

    /// 测试 Task 取消能够敏捷中断重试休眠循环
    func testRetryEngineTaskCancellationInterrupts() async throws {
        let longDelayPolicy = RetryPolicy(maxAttempts: 5, initialDelaySeconds: 10.0)

        let task = Task {
            try await engine.execute(policy: longDelayPolicy, operationID: "op-cancel") {
                throw LLMProviderError.networkError("持续失败")
            }
        }

        // 短暂等待启动后立即取消
        try? await Task.sleep(nanoseconds: 20_000_000)
        task.cancel()

        let result = await task.result
        switch result {
        case .success:
            XCTFail("任务被取消时不应成功返回")
        case .failure(let error):
            XCTAssertTrue(error is CancellationError || (error as? LLMProviderError) == .cancelled || Task.isCancelled)
        }
    }

    /// 测试统计数据重置能力
    func testRetryEngineResetStats() async throws {
        let fastPolicy = RetryPolicy(maxAttempts: 2, initialDelaySeconds: 0.001)

        _ = try? await engine.execute(policy: fastPolicy, operationID: "op-to-reset") {
            throw LLMProviderError.timeout
        }

        var stats = await engine.getStats()
        XCTAssertGreaterThan(stats.totalOperations, 0)

        await engine.resetStats()
        stats = await engine.getStats()
        XCTAssertEqual(stats.totalOperations, 0)
        XCTAssertEqual(stats.totalRetries, 0)
        XCTAssertEqual(stats.successfulRetries, 0)
        XCTAssertEqual(stats.nonRetryableFailures, 0)
        XCTAssertEqual(stats.exhaustedFailures, 0)
    }
}

// MARK: - 2. OfflineResourceManagerTests (端侧离线资源管理器测试套件)

/// 端侧离线资源管理器与沙盒 SHA-256 校验测试套件 (R14 / OfflineResourceManager)
final class OfflineResourceManagerTests: XCTestCase {

    private var tempDirectoryURL: URL!
    private var sandbox: LocalSandboxManager!
    private var manager: OfflineResourceManager!

    override func setUp() async throws {
        try await super.setUp()
        let tempBase = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("StudyOS_M4_OfflineResource_\(UUID().uuidString)", isDirectory: true)
        self.tempDirectoryURL = tempBase
        self.sandbox = LocalSandboxManager(rootDirectoryURL: tempBase)
        self.manager = OfflineResourceManager(sandbox: sandbox)
    }

    override func tearDown() async throws {
        if let temp = tempDirectoryURL {
            try? FileManager.default.removeItem(at: temp)
        }
        self.manager = nil
        self.sandbox = nil
        try await super.tearDown()
    }

    // MARK: - 模型元数据注册与基础管理

    /// 测试模型包元数据注册、查询与列表
    func testRegisterAndGetPackage() async throws {
        let metadata = ModelPackageMetadata(
            packageID: "phi-3-mini-q4",
            modelName: "Phi-3 Mini 4K Instruct",
            format: "mlpackage",
            fileSizeBytes: 2_400_000_000,
            isDownloaded: false,
            isQuantized: true,
            minMemoryRequirementBytes: 3 * 1024 * 1024 * 1024,
            sha256Checksum: "abcdef123456",
            runtimeKind: .coreML,
            version: "1.2.0"
        )

        try await manager.registerPackage(metadata)

        let fetched = await manager.getPackage(id: "phi-3-mini-q4")
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.packageID, "phi-3-mini-q4")
        XCTAssertEqual(fetched?.modelName, "Phi-3 Mini 4K Instruct")
        XCTAssertEqual(fetched?.runtimeKind, .coreML)
        XCTAssertEqual(fetched?.version, "1.2.0")

        let allPackages = await manager.listPackages()
        XCTAssertEqual(allPackages.count, 1)
        XCTAssertEqual(allPackages.first?.packageID, "phi-3-mini-q4")
    }

    /// 测试删除模型包并物理清理沙盒目录
    func testDeletePackageAndPurgeSandbox() async throws {
        let packageID = "tiny-llama-q4"
        let metadata = ModelPackageMetadata(
            packageID: packageID,
            modelName: "TinyLlama 1.1B",
            format: "bin"
        )

        try await manager.registerPackage(metadata)
        _ = try await manager.storeModelFile(
            packageID: packageID,
            fileName: "weights.bin",
            data: Data([0x01, 0x02, 0x03, 0x04])
        )

        let packageDir = sandbox.modelPackageDirectory(packageID: packageID)
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageDir.path))

        let deleted = try await manager.deletePackage(id: packageID)
        XCTAssertTrue(deleted)

        let fetchedAfter = await manager.getPackage(id: packageID)
        XCTAssertNil(fetchedAfter)
        XCTAssertFalse(FileManager.default.fileExists(atPath: packageDir.path), "沙盒物理文件应被彻底清除")

        let deleteAgain = try await manager.deletePackage(id: packageID)
        XCTAssertFalse(deleteAgain, "二次删除应返回 false")
    }

    // MARK: - 模型文件存储与分块合并测试

    /// 测试单文件直接存储
    func testStoreModelFile() async throws {
        let packageID = "single-file-pkg"
        let metadata = ModelPackageMetadata(packageID: packageID, modelName: "Test Single File")
        try await manager.registerPackage(metadata)

        let payload = Data("TEST_MODEL_BINARY_WEIGHTS".utf8)
        let fileURL = try await manager.storeModelFile(packageID: packageID, fileName: "weights.bin", data: payload)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        let savedData = try Data(contentsOf: fileURL)
        XCTAssertEqual(savedData, payload)

        let updatedMeta = await manager.getPackage(id: packageID)
        XCTAssertEqual(updatedMeta?.isDownloaded, true)
        XCTAssertEqual(updatedMeta?.fileSizeBytes, Int64(payload.count))
    }

    /// 测试多切片按序分块存储并自动原子合并至 weights.bin
    func testStoreModelChunksAndAutomaticMerge() async throws {
        let packageID = "chunked-package-test"
        let metadata = ModelPackageMetadata(
            packageID: packageID,
            modelName: "Chunked Model 1B",
            isDownloaded: false
        )
        try await manager.registerPackage(metadata)

        let chunk0 = Data("CHUNK_0_HEADER_DATA_".utf8)
        let chunk1 = Data("CHUNK_1_BODY_WEIGHTS_".utf8)
        let chunk2 = Data("CHUNK_2_TAIL_TENSORS".utf8)
        let totalChunks = 3

        // 写入分块 0
        try await manager.storeModelChunk(packageID: packageID, chunkIndex: 0, totalChunks: totalChunks, data: chunk0)
        var package = await manager.getPackage(id: packageID)
        XCTAssertFalse(package?.isDownloaded ?? true, "未全部写入时不应标记为 isDownloaded")

        // 写入分块 1
        try await manager.storeModelChunk(packageID: packageID, chunkIndex: 1, totalChunks: totalChunks, data: chunk1)

        // 写入分块 2（最后一块触发自动合并）
        try await manager.storeModelChunk(packageID: packageID, chunkIndex: 2, totalChunks: totalChunks, data: chunk2)

        package = await manager.getPackage(id: packageID)
        XCTAssertTrue(package?.isDownloaded ?? false, "全部分块就绪后必须标记为已下载")

        let expectedFullData = chunk0 + chunk1 + chunk2
        XCTAssertEqual(package?.fileSizeBytes, Int64(expectedFullData.count))

        // 验证合并后的 weights.bin 内容
        let packageDir = sandbox.modelPackageDirectory(packageID: packageID)
        let mergedURL = packageDir.appendingPathComponent("weights.bin")
        XCTAssertTrue(FileManager.default.fileExists(atPath: mergedURL.path), "合并文件 weights.bin 必须存在")
        let mergedData = try Data(contentsOf: mergedURL)
        XCTAssertEqual(mergedData, expectedFullData, "合并二进制内容必须与分块拼接完全一致")

        // 验证切片临时文件已被清理
        for i in 0..<totalChunks {
            let partURL = packageDir.appendingPathComponent("chunk_\(i).part")
            XCTAssertFalse(FileManager.default.fileExists(atPath: partURL.path), "切片临时文件 chunk_\(i).part 应被清除")
        }
    }

    // MARK: - CryptoKit SHA-256 完整性校验比对测试

    /// 测试真实 SHA-256 指纹校验通过
    func testVerifyPackageIntegritySuccess() async throws {
        let packageID = "sha-pass-package"
        let payload = Data("HIGH_PRECISION_NEURAL_WEIGHTS_DATA_SEED_2026".utf8)
        let computedSHA256 = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()

        let metadata = ModelPackageMetadata(
            packageID: packageID,
            modelName: "Secure Local Model",
            sha256Checksum: computedSHA256
        )
        try await manager.registerPackage(metadata)
        _ = try await manager.storeModelFile(packageID: packageID, fileName: "weights.bin", data: payload)

        let result = try await manager.verifyPackageIntegrity(packageID: packageID)
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.expectedChecksum, computedSHA256)
        XCTAssertEqual(result.actualChecksum, computedSHA256)
        XCTAssertEqual(result.fileSizeBytes, Int64(payload.count))
        XCTAssertTrue(result.message.contains("通过"))

        let isReady = await manager.isPackageReady(packageID: packageID)
        XCTAssertTrue(isReady)
    }

    /// 测试被篡改或损坏的文件 SHA-256 校验拦截失败
    func testVerifyPackageIntegrityTamperedFails() async throws {
        let packageID = "sha-fail-package"
        let validPayload = Data("ORIGINAL_WEIGHTS".utf8)
        let originalSHA256 = SHA256.hash(data: validPayload).map { String(format: "%02x", $0) }.joined()

        let metadata = ModelPackageMetadata(
            packageID: packageID,
            modelName: "Tampered Local Model",
            sha256Checksum: originalSHA256
        )
        try await manager.registerPackage(metadata)

        // 写入被篡改的数据
        let tamperedPayload = Data("CORRUPTED_TAMPERED_WEIGHTS".utf8)
        _ = try await manager.storeModelFile(packageID: packageID, fileName: "weights.bin", data: tamperedPayload)

        let result = try await manager.verifyPackageIntegrity(packageID: packageID)
        XCTAssertFalse(result.isValid, "篡改文件哈希不匹配必须判定为无效")
        XCTAssertEqual(result.expectedChecksum, originalSHA256)
        XCTAssertNotEqual(result.actualChecksum, originalSHA256)
        XCTAssertTrue(result.message.contains("校验失败"))
    }

    /// 测试未注册模型包校验返回优雅错误
    func testVerifyPackageIntegrityUnregistered() async throws {
        let result = try await manager.verifyPackageIntegrity(packageID: "non-existent-pkg")
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.message.contains("未注册"))
    }

    /// 测试注册了但尚未写入权重文件的完整性校验
    func testVerifyPackageIntegrityMissingWeights() async throws {
        let packageID = "missing-weights-pkg"
        let metadata = ModelPackageMetadata(
            packageID: packageID,
            modelName: "Missing Weights",
            sha256Checksum: "somehash"
        )
        try await manager.registerPackage(metadata)

        let result = try await manager.verifyPackageIntegrity(packageID: packageID)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.message.contains("缺失") || result.message.contains("不存在"))
    }

    // MARK: - 沙盒存储用量与就绪检查

    /// 测试端侧模型沙盒总磁盘占用量统计
    func testTotalStorageBytesUsed() async throws {
        let pkg1 = ModelPackageMetadata(packageID: "pkg-1", modelName: "Pkg 1")
        let pkg2 = ModelPackageMetadata(packageID: "pkg-2", modelName: "Pkg 2")

        try await manager.registerPackage(pkg1)
        try await manager.registerPackage(pkg2)

        let data1 = Data(repeating: 0xAA, count: 1024)
        let data2 = Data(repeating: 0xBB, count: 2048)

        _ = try await manager.storeModelFile(packageID: "pkg-1", fileName: "weights.bin", data: data1)
        _ = try await manager.storeModelFile(packageID: "pkg-2", fileName: "weights.bin", data: data2)

        let totalBytes = await manager.totalStorageBytesUsed()
        // 包含元数据 json 和 weights.bin，至少大于等于两权重之和
        XCTAssertGreaterThanOrEqual(totalBytes, Int64(data1.count + data2.count))
    }
}

// MARK: - 3. LocalModelPackageManagerTests (端侧模型调度与动态降级测试套件)

/// 端侧本地模型包与动态降级调度器测试套件 (R12 / R14 / LocalModelPackageManager)
final class LocalModelPackageManagerTests: XCTestCase {

    private var tempDirectoryURL: URL!
    private var sandbox: LocalSandboxManager!
    private var offlineResourceManager: OfflineResourceManager!
    private var packageManager: LocalModelPackageManager!

    override func setUp() async throws {
        try await super.setUp()
        let tempBase = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("StudyOS_M4_PackageManager_\(UUID().uuidString)", isDirectory: true)
        self.tempDirectoryURL = tempBase
        self.sandbox = LocalSandboxManager(rootDirectoryURL: tempBase)
        self.offlineResourceManager = OfflineResourceManager(sandbox: sandbox)
        self.packageManager = LocalModelPackageManager(
            initialNetworkState: .reachable,
            initialMemoryPressure: .normal,
            offlineResourceManager: offlineResourceManager
        )
    }

    override func tearDown() async throws {
        if let temp = tempDirectoryURL {
            try? FileManager.default.removeItem(at: temp)
        }
        self.packageManager = nil
        self.offlineResourceManager = nil
        self.sandbox = nil
        try await super.tearDown()
    }

    // MARK: - 网络与设备状态感知与更新

    /// 测试网络状态与内存压力状态更新
    func testNetworkAndMemoryStateUpdates() async {
        let initialNetwork = await packageManager.networkState
        let initialMemory = await packageManager.memoryPressure
        XCTAssertEqual(initialNetwork, .reachable)
        XCTAssertEqual(initialMemory, .normal)

        await packageManager.updateNetworkState(.unreachable)
        await packageManager.updateMemoryPressure(.warning)

        let updatedNetwork = await packageManager.networkState
        let updatedMemory = await packageManager.memoryPressure
        XCTAssertEqual(updatedNetwork, .unreachable)
        XCTAssertEqual(updatedMemory, .warning)
    }

    // MARK: - 动态降级决策评估 (evaluateFallback)

    /// 决策 1：网络畅通 (.reachable) 时推选云端 (.useCloud)
    func testEvaluateFallbackReachablePrefersCloud() async {
        await packageManager.updateNetworkState(.reachable)
        await packageManager.updateMemoryPressure(.normal)

        let decision = await packageManager.evaluateFallback()
        XCTAssertEqual(decision, .useCloud)
    }

    /// 决策 2：网络断网 (.unreachable) 时自动降级至已就绪端侧模型 (.fallbackToLocal)
    func testEvaluateFallbackUnreachableFallbacksToLocal() async throws {
        // 注册并写入离线模型
        let packageID = "local-distill-q4"
        let metadata = ModelPackageMetadata(
            packageID: packageID,
            modelName: "Local Distill 3B",
            isDownloaded: true
        )
        try await packageManager.registerPackage(metadata)
        _ = try await offlineResourceManager.storeModelFile(
            packageID: packageID,
            fileName: "weights.bin",
            data: Data("WEIGHTS_READY".utf8)
        )

        await packageManager.updateNetworkState(.unreachable)
        await packageManager.updateMemoryPressure(.normal)

        let decision = await packageManager.evaluateFallback(preferredLocalPackageID: packageID)

        switch decision {
        case .fallbackToLocal(let reason):
            XCTAssertTrue(reason.contains("自动热降级") || reason.contains("端侧本地"))
            XCTAssertTrue(reason.contains("Local Distill 3B"))
        default:
            XCTFail("断网环境下应做出 .fallbackToLocal 决策，实际得到: \(decision)")
        }
    }

    /// 决策 3：弱网 (.weak) 状态下自动决策热降级
    func testEvaluateFallbackWeakNetworkFallbacksToLocal() async throws {
        await packageManager.updateNetworkState(.weak)
        await packageManager.updateMemoryPressure(.normal)

        let decision = await packageManager.evaluateFallback()
        switch decision {
        case .fallbackToLocal:
            // 通过验证
            break
        default:
            XCTFail("弱网环境下应触发本地降级，实际得到: \(decision)")
        }
    }

    /// 决策 4：内存处于严重告警 (.critical) 时抑制端侧模型，避免造成 OOM 崩溃 (.failImmediately)
    func testEvaluateFallbackCriticalMemorySuppressesLocalToPreventOOM() async throws {
        await packageManager.updateNetworkState(.unreachable)
        await packageManager.updateMemoryPressure(.critical)

        let decision = await packageManager.evaluateFallback()

        switch decision {
        case .failImmediately(let reason):
            XCTAssertTrue(reason.contains("严重告警") || reason.contains("抑制端侧模型"))
        default:
            XCTFail("内存严重告警下应立即阻断以防 OOM，实际得到: \(decision)")
        }
    }

    // MARK: - 模型包管理与活跃运行时推选

    /// 测试活跃模型包切换与最优运行时推选
    func testActivePackageAndSelectOptimalRuntime() async throws {
        let metaMock = ModelPackageMetadata(
            packageID: "mock-pkg",
            modelName: "Mock Small",
            runtimeKind: .mock
        )
        let metaCoreML = ModelPackageMetadata(
            packageID: "coreml-pkg",
            modelName: "CoreML Engine",
            runtimeKind: .coreML
        )

        try await packageManager.registerPackage(metaMock)
        try await packageManager.registerPackage(metaCoreML)

        try await packageManager.setActivePackage(id: "coreml-pkg")
        let active = await packageManager.getActivePackage()
        XCTAssertEqual(active?.packageID, "coreml-pkg")

        let runtime = await packageManager.selectOptimalRuntime()
        XCTAssertEqual(runtime, .coreML)
    }

    // MARK: - 无缝本地热降级执行管道 (executeWithHotFallback)

    /// 测试断网状态下 executeWithHotFallback 直接直通本地 Provider
    func testExecuteWithHotFallbackDirectLocalWhenOffline() async throws {
        await packageManager.updateNetworkState(.unreachable)

        let mockCloud = M4MockCloudLLMProvider()
        let mockLocal = M4MockLocalProvider(isReady: true)

        let messages = [LLMMessage(role: .user, content: "请总结本文核心")]
        let stream = try await packageManager.executeWithHotFallback(
            messages: messages,
            options: LLMCompletionOptions(),
            cloudProvider: mockCloud,
            localProvider: mockLocal
        )

        var output = ""
        for try await chunk in stream {
            output += chunk.delta
        }

        XCTAssertTrue(output.contains("Local offline generated response"))
        XCTAssertEqual(mockCloud.callCount, 0, "断网时不应请求云端")
        let localCalls = await mockLocal.streamCallCount
        XCTAssertEqual(localCalls, 1, "本地 Provider 应被执行")
    }

    /// 测试网络畅通状态下 executeWithHotFallback 优先使用云端
    func testExecuteWithHotFallbackCloudSuccessWhenReachable() async throws {
        await packageManager.updateNetworkState(.reachable)

        let mockCloud = M4MockCloudLLMProvider()
        let mockLocal = M4MockLocalProvider(isReady: true)

        let messages = [LLMMessage(role: .user, content: "云端请求测试")]
        let stream = try await packageManager.executeWithHotFallback(
            messages: messages,
            options: LLMCompletionOptions(),
            cloudProvider: mockCloud,
            localProvider: mockLocal
        )

        var output = ""
        for try await chunk in stream {
            output += chunk.delta
        }

        XCTAssertTrue(output.contains("Cloud generated stream chunk"))
        XCTAssertEqual(mockCloud.callCount, 1)
        let localCalls = await mockLocal.streamCallCount
        XCTAssertEqual(localCalls, 0, "云端成功时不应触发本地 Provider")
    }

    /// 测试云端请求遭遇超时网络故障时，流式执行管道自动无缝热降级至本地离线 Provider 保底
    func testExecuteWithHotFallbackCloudFailureSeamlesslySwitchesToLocal() async throws {
        await packageManager.updateNetworkState(.reachable)

        let mockCloud = M4MockCloudLLMProvider()
        mockCloud.setStreamHandler { @Sendable _, _ in
            throw LLMProviderError.networkError("云端网关超时")
        }

        let mockLocal = M4MockLocalProvider(isReady: true)
        let fastPolicy = RetryPolicy(maxAttempts: 1, initialDelaySeconds: 0.001)

        let messages = [LLMMessage(role: .user, content: "网络断连容灾测试")]
        let stream = try await packageManager.executeWithHotFallback(
            messages: messages,
            options: LLMCompletionOptions(),
            cloudProvider: mockCloud,
            localProvider: mockLocal,
            retryPolicy: fastPolicy
        )

        var output = ""
        for try await chunk in stream {
            output += chunk.delta
        }

        XCTAssertTrue(output.contains("Local offline generated response"), "云端失败后应无缝热降级至端侧离线输出")
        XCTAssertEqual(mockCloud.callCount, 1)
        let localCalls = await mockLocal.streamCallCount
        XCTAssertEqual(localCalls, 1)
    }

    /// 测试在使用 RetryEngine 且重试耗尽后，executeWithHotFallback 依然能够可靠降级至端侧离线 Provider
    func testExecuteWithHotFallbackCloudRetryEngineExhaustedAndFallsBackToLocal() async throws {
        await packageManager.updateNetworkState(.reachable)

        let mockCloud = M4MockCloudLLMProvider()
        mockCloud.setStreamHandler { @Sendable _, _ in
            throw LLMProviderError.timeout
        }

        let mockLocal = M4MockLocalProvider(isReady: true)
        let retryEngine = NetworkResilienceRetryEngine()
        let policy = RetryPolicy(maxAttempts: 2, initialDelaySeconds: 0.001, jitterFactor: 0.0)

        let messages = [LLMMessage(role: .user, content: "重试耗尽降级")]
        let stream = try await packageManager.executeWithHotFallback(
            messages: messages,
            options: LLMCompletionOptions(),
            cloudProvider: mockCloud,
            localProvider: mockLocal,
            retryPolicy: policy,
            retryEngine: retryEngine
        )

        var output = ""
        for try await chunk in stream {
            output += chunk.delta
        }

        XCTAssertTrue(output.contains("Local offline generated response"))
        XCTAssertEqual(mockCloud.callCount, 2, "经历了 2 次重试尝试")
        let localCalls = await mockLocal.streamCallCount
        XCTAssertEqual(localCalls, 1)

        let stats = await retryEngine.getStats()
        XCTAssertEqual(stats.totalOperations, 1)
        XCTAssertEqual(stats.exhaustedFailures, 1)
    }
}
