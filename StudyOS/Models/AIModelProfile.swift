import Foundation

/// 模型提供商类型
public enum ProviderKind: String, Codable, Sendable, CaseIterable {
    case deepseek
    case openai
    case anthropic
    case gemini
    case ollama
    case custom
    case chatgptWeb
    case onDeviceCoreML
}

/// 认证鉴权方式
public enum AuthMethod: String, Codable, Sendable, CaseIterable {
    case apiKey
    case webSession
    case none
}

/// AI 模型配置实体 (AIModelProfile)
public struct AIModelProfile: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public var displayName: String
    public var providerKind: ProviderKind
    public var endpoint: String
    public var modelIdentifier: String
    public var isReasoningModel: Bool
    public var authMethod: AuthMethod
    public var apiKeyStorageKey: String?
    public var contextWindowTokens: Int
    public var isDefault: Bool

    public init(
        id: String = UUID().uuidString,
        displayName: String,
        providerKind: ProviderKind,
        endpoint: String,
        modelIdentifier: String,
        isReasoningModel: Bool = false,
        authMethod: AuthMethod = .apiKey,
        apiKeyStorageKey: String? = nil,
        contextWindowTokens: Int = 128_000,
        isDefault: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.providerKind = providerKind
        self.endpoint = endpoint
        self.modelIdentifier = modelIdentifier
        self.isReasoningModel = isReasoningModel
        self.authMethod = authMethod
        self.apiKeyStorageKey = apiKeyStorageKey ?? "keychain_apikey_\(id)"
        self.contextWindowTokens = contextWindowTokens
        self.isDefault = isDefault
    }

    /// 内置默认模型配置清单 (Model Hub 默认提供)
    public static let defaultProfiles: [AIModelProfile] = [
        AIModelProfile(
            id: "deepseek-r1",
            displayName: "DeepSeek-R1 (深度推理版)",
            providerKind: .deepseek,
            endpoint: "https://api.deepseek.com",
            modelIdentifier: "deepseek-reasoner",
            isReasoningModel: true,
            authMethod: .apiKey,
            apiKeyStorageKey: "keychain_apikey_deepseek",
            contextWindowTokens: 64_000,
            isDefault: true
        ),
        AIModelProfile(
            id: "openai-gpt4o",
            displayName: "OpenAI GPT-4o (全能通用版)",
            providerKind: .openai,
            endpoint: "https://api.openai.com/v1",
            modelIdentifier: "gpt-4o",
            isReasoningModel: false,
            authMethod: .apiKey,
            apiKeyStorageKey: "keychain_apikey_openai",
            contextWindowTokens: 128_000,
            isDefault: false
        ),
        AIModelProfile(
            id: "anthropic-claude-35-sonnet",
            displayName: "Claude 3.5 Sonnet (学术分析旗舰)",
            providerKind: .anthropic,
            endpoint: "https://api.anthropic.com/v1",
            modelIdentifier: "claude-3-5-sonnet-20241022",
            isReasoningModel: false,
            authMethod: .apiKey,
            apiKeyStorageKey: "keychain_apikey_anthropic",
            contextWindowTokens: 200_000,
            isDefault: false
        ),
        AIModelProfile(
            id: "google-gemini-15-pro",
            displayName: "Google Gemini 1.5 Pro (超长上下文)",
            providerKind: .gemini,
            endpoint: "https://generativelanguage.googleapis.com/v1beta/openai",
            modelIdentifier: "gemini-1.5-pro",
            isReasoningModel: false,
            authMethod: .apiKey,
            apiKeyStorageKey: "keychain_apikey_gemini",
            contextWindowTokens: 1_000_000,
            isDefault: false
        ),
        AIModelProfile(
            id: "chatgpt-plus-web",
            displayName: "ChatGPT Plus 网页版 (免 API Key 直连)",
            providerKind: .chatgptWeb,
            endpoint: "https://chatgpt.com",
            modelIdentifier: "gpt-4o-web",
            isReasoningModel: false,
            authMethod: .webSession,
            apiKeyStorageKey: nil,
            contextWindowTokens: 32_000,
            isDefault: false
        ),
        AIModelProfile(
            id: "on-device-coreml",
            displayName: "iPad 本地离线 CoreML (零网络隐私)",
            providerKind: .onDeviceCoreML,
            endpoint: "offline://apple-neural-engine",
            modelIdentifier: "studyos-distill-q4",
            isReasoningModel: false,
            authMethod: .none,
            apiKeyStorageKey: nil,
            contextWindowTokens: 8_192,
            isDefault: false
        )
    ]
}
