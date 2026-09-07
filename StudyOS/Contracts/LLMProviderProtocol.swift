import Foundation

/// LLM 消息角色
public enum LLMRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

/// LLM 消息结构
public struct LLMMessage: Codable, Sendable, Hashable {
    public let role: LLMRole
    public let content: String

    public init(role: LLMRole, content: String) {
        self.role = role
        self.content = content
    }
}

/// 流式吐字分块结构
public struct LLMChunk: Sendable, Hashable {
    public let delta: String
    public let finishReason: String?
    public let usageEstimate: Int?

    public init(delta: String, finishReason: String? = nil, usageEstimate: Int? = nil) {
        self.delta = delta
        self.finishReason = finishReason
        self.usageEstimate = usageEstimate
    }
}

/// LLM 生成调用选项
public struct LLMCompletionOptions: Sendable {
    public let temperature: Double
    public let maxTokens: Int?
    public let topP: Double?
    public let timeoutInterval: TimeInterval

    public init(
        temperature: Double = 0.7,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        timeoutInterval: TimeInterval = 30.0
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.timeoutInterval = timeoutInterval
    }
}

/// 结构化 LLM Provider 错误分型 (契约对齐)
public enum LLMProviderError: Error, Sendable, Hashable, LocalizedError {
    case unauthorized(String)
    case rateLimited(retryAfterSeconds: Int?, String)
    case serverError(statusCode: Int, String)
    case networkError(String)
    case cancelled
    case timeout
    case unsupportedCapability(String)
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized(let msg):
            return "鉴权失败: \(msg)"
        case .rateLimited(let sec, let msg):
            if let s = sec {
                return "请求过于频繁 (请在 \(s) 秒后重试): \(msg)"
            }
            return "请求过于频繁: \(msg)"
        case .serverError(let code, let msg):
            return "服务异常 [\(code)]: \(msg)"
        case .networkError(let msg):
            return "网络通信异常: \(msg)"
        case .cancelled:
            return "请求已取消"
        case .timeout:
            return "请求响应超时"
        case .unsupportedCapability(let cap):
            return "不支持的能力特性: \(cap)"
        case .invalidResponse(let msg):
            return "服务响应格式损坏: \(msg)"
        }
    }
}

/// LLM Provider 抽象协议
public protocol LLMProviderProtocol: Sendable {
    /// 唯一标识
    var profileID: String { get }
    /// Provider 配置快照
    var snapshot: ProviderSnapshot { get }

    /// 流式补全
    func streamCompletion(
        messages: [LLMMessage],
        options: LLMCompletionOptions
    ) async throws -> AsyncThrowingStream<LLMChunk, Error>
}
