import Foundation

/// 端侧本地模型包与热降级调度管理器实现 (LocalModelPackageManager)
/// 支持根据网络可用性（R12）与设备内存压力（R14）进行动态调度决策与无缝端侧热降级
public actor LocalModelPackageManager: LocalModelPackageManagerProtocol {
    private var _networkState: NetworkReachabilityState = .reachable
    private var _memoryPressure: DeviceMemoryPressure = .normal
    private var packages: [String: ModelPackageMetadata] = [:]
    private var activePackageID: String?
    private let offlineResourceManager: OfflineResourceManagerProtocol?

    public init(
        initialNetworkState: NetworkReachabilityState = .reachable,
        initialMemoryPressure: DeviceMemoryPressure = .normal,
        offlineResourceManager: OfflineResourceManagerProtocol? = nil
    ) {
        self._networkState = initialNetworkState
        self._memoryPressure = initialMemoryPressure
        self.offlineResourceManager = offlineResourceManager
    }

    // MARK: - 状态查询与更新

    public var networkState: NetworkReachabilityState {
        _networkState
    }

    public var memoryPressure: DeviceMemoryPressure {
        _memoryPressure
    }

    public func updateNetworkState(_ state: NetworkReachabilityState) async {
        self._networkState = state
    }

    public func updateMemoryPressure(_ pressure: DeviceMemoryPressure) async {
        self._memoryPressure = pressure
    }

    // MARK: - 包管理

    public func registerPackage(_ metadata: ModelPackageMetadata) async throws {
        packages[metadata.packageID] = metadata
        if activePackageID == nil {
            activePackageID = metadata.packageID
        }
        try await offlineResourceManager?.registerPackage(metadata)
    }

    public func getPackage(id: String) async -> ModelPackageMetadata? {
        if let memoryMeta = packages[id] {
            return memoryMeta
        }
        return await offlineResourceManager?.getPackage(id: id)
    }

    public func listPackages() async -> [ModelPackageMetadata] {
        if let rm = offlineResourceManager {
            return await rm.listPackages()
        }
        return Array(packages.values)
    }

    public func getActivePackage() async -> ModelPackageMetadata? {
        guard let id = activePackageID else {
            return packages.values.first(where: { $0.isDownloaded })
        }
        return await getPackage(id: id)
    }

    public func setActivePackage(id: String) async throws {
        guard let package = await getPackage(id: id) else {
            throw LLMProviderError.invalidResponse("未找到模型包: \(id)")
        }
        self.activePackageID = package.packageID
    }

    // MARK: - 降级决策评估与运行时选择

    /// 评估是否降级至端侧离线模型
    public func evaluateFallback(preferredLocalPackageID: String? = nil) async -> OfflineFallbackDecision {
        // 1. 网络畅通且无弱网时
        if _networkState == .reachable {
            return .useCloud
        }

        // 2. 网络处于弱网或不可用时，检查端侧资源与内存可用性
        if _memoryPressure == .critical {
            return .failImmediately(reason: "网络不可用且设备内存处于严重告警状态，抑制端侧模型载入")
        }

        let targetID = preferredLocalPackageID ?? activePackageID
        var candidatePackage: ModelPackageMetadata?

        if let id = targetID {
            candidatePackage = await getPackage(id: id)
        }
        if candidatePackage == nil {
            candidatePackage = await getActivePackage()
        }

        // 如果配置了端侧资源管理器，进一步校验模型就绪状态
        if let package = candidatePackage {
            let isReady: Bool
            if let rm = offlineResourceManager {
                isReady = await rm.isPackageReady(packageID: package.packageID)
            } else {
                isReady = package.isDownloaded
            }

            if isReady {
                let reason = "网络处于 \(_networkState.rawValue) 状态，自动热降级至端侧本地模型 [\(package.modelName)]"
                return .fallbackToLocal(reason: reason)
            }
        }

        // 默认内置 Mock 端侧引擎保底支持
        return .fallbackToLocal(reason: "网络不可用，自动切换至端侧本地保底推理引擎")
    }

    /// 依据当前设备与活跃模型配置推选最佳端侧运行时
    public func selectOptimalRuntime() async -> LocalRuntimeKind {
        if let active = await getActivePackage() {
            return active.runtimeKind
        }
        return .mock
    }

    // MARK: - 无缝本地热降级执行器

    /// 带弱网弹性重试与无缝本地热降级的流式调度执行
    public func executeWithHotFallback(
        messages: [LLMMessage],
        options: LLMCompletionOptions,
        cloudProvider: LLMProviderProtocol,
        localProvider: LocalLLMProviderProtocol,
        retryPolicy: RetryPolicy = .default,
        retryEngine: NetworkResilienceRetryEngineProtocol? = nil
    ) async throws -> AsyncThrowingStream<LLMChunk, Error> {
        let decision = await evaluateFallback()

        switch decision {
        case .fallbackToLocal:
            // 直接采用本地模型
            return try await localProvider.streamCompletion(messages: messages, options: options)

        case .failImmediately(let reason):
            throw LLMProviderError.networkError("无法发起生成: \(reason)")

        case .useCloud:
            // 尝试云端请求
            do {
                if let engine = retryEngine {
                    return try await engine.execute(policy: retryPolicy, operationID: UUID().uuidString) {
                        try await cloudProvider.streamCompletion(messages: messages, options: options)
                    }
                } else {
                    return try await cloudProvider.streamCompletion(messages: messages, options: options)
                }
            } catch {
                // 如果云端请求因网络原因或超时失败，且本地模型可保底，执行热降级
                if retryPolicy.canRetry(error: error) && (await localProvider.isReady()) {
                    return try await localProvider.streamCompletion(messages: messages, options: options)
                }
                throw error
            }
        }
    }
}
