import Foundation

/// 端侧本地模型生命周期与推理状态 (ModelState)
public enum ModelState: String, Codable, Sendable {
    case idle
    case loading
    case ready
    case error
    case unloaded
}

/// 端侧本地运行时引擎类型 (LocalRuntimeKind)
public enum LocalRuntimeKind: String, Codable, Sendable, CaseIterable {
    case mock
    case coreML
    case onDeviceEngine
}

/// 端侧模型配置定义 (LocalModelConfig)
public struct LocalModelConfig: Codable, Sendable, Hashable {
    public let modelID: String
    public let modelPath: String?
    public let contextWindow: Int
    public let temperature: Double
    public let maxTokens: Int?
    public let quantization: String?
    public let isOfflineOnly: Bool
    public let runtimeKind: LocalRuntimeKind

    public init(
        modelID: String = "local-distill-q4",
        modelPath: String? = nil,
        contextWindow: Int = 4096,
        temperature: Double = 0.7,
        maxTokens: Int? = 2048,
        quantization: String? = "q4_k_m",
        isOfflineOnly: Bool = true,
        runtimeKind: LocalRuntimeKind = .mock
    ) {
        self.modelID = modelID
        self.modelPath = modelPath
        self.contextWindow = contextWindow
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.quantization = quantization
        self.isOfflineOnly = isOfflineOnly
        self.runtimeKind = runtimeKind
    }
}

/// 端侧模型推理就绪与运行状态 (LocalModelInferenceStatus)
public struct LocalModelInferenceStatus: Codable, Sendable, Hashable {
    public let isReady: Bool
    public let state: ModelState
    public let memoryUsageBytes: Int64?
    public let loadedModelID: String?
    public let errorMessage: String?
    public let runtimeKind: LocalRuntimeKind

    public init(
        isReady: Bool,
        state: ModelState,
        memoryUsageBytes: Int64? = nil,
        loadedModelID: String? = nil,
        errorMessage: String? = nil,
        runtimeKind: LocalRuntimeKind = .mock
    ) {
        self.isReady = isReady
        self.state = state
        self.memoryUsageBytes = memoryUsageBytes
        self.loadedModelID = loadedModelID
        self.errorMessage = errorMessage
        self.runtimeKind = runtimeKind
    }
}

/// 端侧模型沙盒资源包元数据 (ModelPackageMetadata, R14)
public struct ModelPackageMetadata: Identifiable, Codable, Sendable, Hashable {
    public var id: String { packageID }
    public let packageID: String
    public let modelName: String
    public let format: String
    public let fileSizeBytes: Int64
    public var isDownloaded: Bool
    public let isQuantized: Bool
    public let minMemoryRequirementBytes: Int64
    public let sha256Checksum: String?
    public let runtimeKind: LocalRuntimeKind
    public let version: String

    public init(
        packageID: String,
        modelName: String,
        format: String = "mlpackage",
        fileSizeBytes: Int64 = 0,
        isDownloaded: Bool = false,
        isQuantized: Bool = true,
        minMemoryRequirementBytes: Int64 = 512 * 1024 * 1024,
        sha256Checksum: String? = nil,
        runtimeKind: LocalRuntimeKind = .mock,
        version: String = "1.0.0"
    ) {
        self.packageID = packageID
        self.modelName = modelName
        self.format = format
        self.fileSizeBytes = fileSizeBytes
        self.isDownloaded = isDownloaded
        self.isQuantized = isQuantized
        self.minMemoryRequirementBytes = minMemoryRequirementBytes
        self.sha256Checksum = sha256Checksum
        self.runtimeKind = runtimeKind
        self.version = version
    }
}

/// 弱网与网络弹性重试策略定义 (RetryPolicy, R12)
public struct RetryPolicy: Sendable {
    public let maxAttempts: Int
    public let initialDelaySeconds: TimeInterval
    public let backoffMultiplier: Double
    public let maxDelaySeconds: TimeInterval
    public let jitterFactor: Double
    public let retryablePredicate: (@Sendable (Error) -> Bool)?

    public init(
        maxAttempts: Int = 3,
        initialDelaySeconds: TimeInterval = 0.5,
        backoffMultiplier: Double = 2.0,
        maxDelaySeconds: TimeInterval = 8.0,
        jitterFactor: Double = 0.2,
        retryablePredicate: (@Sendable (Error) -> Bool)? = nil
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.initialDelaySeconds = max(0.0, initialDelaySeconds)
        self.backoffMultiplier = max(1.0, backoffMultiplier)
        self.maxDelaySeconds = max(initialDelaySeconds, maxDelaySeconds)
        self.jitterFactor = min(max(0.0, jitterFactor), 1.0)
        self.retryablePredicate = retryablePredicate
    }

    public static let `default` = RetryPolicy()
    public static let none = RetryPolicy(maxAttempts: 1, initialDelaySeconds: 0, backoffMultiplier: 1.0, maxDelaySeconds: 0, jitterFactor: 0)

    /// 判断指定错误是否可重试
    public func canRetry(error: Error) -> Bool {
        if let custom = retryablePredicate {
            return custom(error)
        }
        return Self.defaultIsRetryable(error: error)
    }

    /// 契约规定的默认重试判断规则：
    /// 严密区分可重试错误（networkError, timeout, 5xx serverError）与不可重试终态（cancelled, unauthorized, alreadyTerminal）
    public static func defaultIsRetryable(error: Error) -> Bool {
        if let llmError = error as? LLMProviderError {
            switch llmError {
            case .networkError, .timeout:
                return true
            case .serverError(let statusCode, _):
                // 5xx 是典型的服务端临时故障，支持指数退避重试
                return statusCode >= 500 && statusCode < 600
            case .rateLimited:
                return true
            case .unauthorized, .cancelled, .unsupportedCapability, .invalidResponse:
                return false
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut,
                 NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorDNSLookupFailed,
                 NSURLErrorNotConnectedToInternet,
                 NSURLErrorInternationalRoamingOff,
                 NSURLErrorCallIsActive,
                 NSURLErrorDataNotAllowed:
                return true
            case NSURLErrorCancelled:
                return false
            default:
                return false
            }
        }
        return false
    }

    /// 计算第 attempt 次重试的延时（指数退避 + Jitter）
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        let exponential = initialDelaySeconds * pow(backoffMultiplier, Double(attempt - 1))
        let bounded = min(exponential, maxDelaySeconds)
        if jitterFactor > 0 {
            let randomFraction = Double.random(in: -jitterFactor...jitterFactor)
            let jittered = bounded * (1.0 + randomFraction)
            return max(0.0, jittered)
        }
        return bounded
    }
}

/// 离线与端侧调度决策结果 (OfflineFallbackDecision)
public enum OfflineFallbackDecision: Codable, Sendable, Hashable {
    case useCloud
    case fallbackToLocal(reason: String)
    case failImmediately(reason: String = "")

    public static let failImmediately: OfflineFallbackDecision = .failImmediately(reason: "")
}

/// 网络连通性状态
public enum NetworkReachabilityState: String, Codable, Sendable, CaseIterable {
    case reachable
    case weak
    case unreachable
}

/// 设备内存压力状态
public enum DeviceMemoryPressure: String, Codable, Sendable, CaseIterable {
    case normal
    case warning
    case critical
}

/// 模型包完整性校验结果
public struct PackageIntegrityResult: Codable, Sendable, Hashable {
    public let packageID: String
    public let isValid: Bool
    public let expectedChecksum: String?
    public let actualChecksum: String?
    public let fileSizeBytes: Int64
    public let message: String

    public init(
        packageID: String,
        isValid: Bool,
        expectedChecksum: String?,
        actualChecksum: String?,
        fileSizeBytes: Int64,
        message: String
    ) {
        self.packageID = packageID
        self.isValid = isValid
        self.expectedChecksum = expectedChecksum
        self.actualChecksum = actualChecksum
        self.fileSizeBytes = fileSizeBytes
        self.message = message
    }
}

/// 端侧/本地离线 LLM Provider 抽象协议 (LocalLLMProviderProtocol)
public protocol LocalLLMProviderProtocol: LLMProviderProtocol {
    /// 本地模型配置
    var localConfig: LocalModelConfig { get }

    /// 端侧运行时引擎类型
    var runtimeKind: LocalRuntimeKind { get }

    /// 当前推理状态快照
    var inferenceStatus: LocalModelInferenceStatus { get async }

    /// 加载端侧离线模型
    func loadModel() async throws

    /// 卸载端侧模型以释放内存
    func unloadModel() async

    /// 检查推理引擎是否就绪
    func isReady() async -> Bool
}

public extension LocalLLMProviderProtocol {
    var runtimeKind: LocalRuntimeKind { .mock }
}

/// 弱网重试引擎统计快照
public struct RetryEngineStats: Codable, Sendable, Hashable {
    public let totalOperations: Int
    public let totalRetries: Int
    public let successfulRetries: Int
    public let nonRetryableFailures: Int
    public let exhaustedFailures: Int

    public init(
        totalOperations: Int = 0,
        totalRetries: Int = 0,
        successfulRetries: Int = 0,
        nonRetryableFailures: Int = 0,
        exhaustedFailures: Int = 0
    ) {
        self.totalOperations = totalOperations
        self.totalRetries = totalRetries
        self.successfulRetries = successfulRetries
        self.nonRetryableFailures = nonRetryableFailures
        self.exhaustedFailures = exhaustedFailures
    }
}

/// 网络弹性重试引擎服务协议 (NetworkResilienceRetryEngineProtocol)
public protocol NetworkResilienceRetryEngineProtocol: Sendable {
    func execute<T: Sendable>(
        policy: RetryPolicy,
        operationID: String,
        operation: @Sendable () async throws -> T
    ) async throws -> T

    func canRetry(error: Error, policy: RetryPolicy) -> Bool
    func getStats() async -> RetryEngineStats
    func resetStats() async
}

/// 端侧离线资源管理器协议 (OfflineResourceManagerProtocol)
public protocol OfflineResourceManagerProtocol: Sendable {
    func registerPackage(_ metadata: ModelPackageMetadata) async throws
    func getPackage(id: String) async -> ModelPackageMetadata?
    func listPackages() async -> [ModelPackageMetadata]
    func deletePackage(id: String) async throws -> Bool
    func storeModelChunk(packageID: String, chunkIndex: Int, totalChunks: Int, data: Data) async throws
    func storeModelFile(packageID: String, fileName: String, data: Data) async throws -> URL
    func verifyPackageIntegrity(packageID: String) async throws -> PackageIntegrityResult
    func isPackageReady(packageID: String) async -> Bool
    func totalStorageBytesUsed() async -> Int64
}

/// 本地模型包调度管理协议 (LocalModelPackageManagerProtocol)
public protocol LocalModelPackageManagerProtocol: Sendable {
    var networkState: NetworkReachabilityState { get async }
    var memoryPressure: DeviceMemoryPressure { get async }

    func updateNetworkState(_ state: NetworkReachabilityState) async
    func updateMemoryPressure(_ pressure: DeviceMemoryPressure) async
    func evaluateFallback(preferredLocalPackageID: String?) async -> OfflineFallbackDecision
    func registerPackage(_ metadata: ModelPackageMetadata) async throws
    func getPackage(id: String) async -> ModelPackageMetadata?
    func listPackages() async -> [ModelPackageMetadata]
    func getActivePackage() async -> ModelPackageMetadata?
    func setActivePackage(id: String) async throws
    func selectOptimalRuntime() async -> LocalRuntimeKind
}
