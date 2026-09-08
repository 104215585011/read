import Foundation

/// 端侧本地模型生命周期与推理状态 (ModelState)
public enum ModelState: String, Codable, Sendable {
    case idle
    case loading
    case ready
    case error
    case unloaded
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

    public init(
        modelID: String = "local-distill-q4",
        modelPath: String? = nil,
        contextWindow: Int = 4096,
        temperature: Double = 0.7,
        maxTokens: Int? = 2048,
        quantization: String? = "q4_k_m",
        isOfflineOnly: Bool = true
    ) {
        self.modelID = modelID
        self.modelPath = modelPath
        self.contextWindow = contextWindow
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.quantization = quantization
        self.isOfflineOnly = isOfflineOnly
    }
}

/// 端侧模型推理就绪与运行状态 (LocalModelInferenceStatus)
public struct LocalModelInferenceStatus: Codable, Sendable, Hashable {
    public let isReady: Bool
    public let state: ModelState
    public let memoryUsageBytes: Int64?
    public let loadedModelID: String?
    public let errorMessage: String?

    public init(
        isReady: Bool,
        state: ModelState,
        memoryUsageBytes: Int64? = nil,
        loadedModelID: String? = nil,
        errorMessage: String? = nil
    ) {
        self.isReady = isReady
        self.state = state
        self.memoryUsageBytes = memoryUsageBytes
        self.loadedModelID = loadedModelID
        self.errorMessage = errorMessage
    }
}

/// 端侧/本地离线 LLM Provider 抽象协议 (LocalLLMProviderProtocol)
public protocol LocalLLMProviderProtocol: LLMProviderProtocol {
    /// 本地模型配置
    var localConfig: LocalModelConfig { get }

    /// 当前推理状态快照
    var inferenceStatus: LocalModelInferenceStatus { get async }

    /// 加载端侧离线模型
    func loadModel() async throws

    /// 卸载端侧模型以释放内存
    func unloadModel() async

    /// 检查推理引擎是否就绪
    func isReady() async -> Bool
}
