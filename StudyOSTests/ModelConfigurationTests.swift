import XCTest
@testable import StudyOS

// MARK: - 1. ModelProfileTests (AIModelProfile 实体与预设模型测试套件)

/// AIModelProfile 数据实体、编解码与默认 6 款模型预设测试套件
final class ModelProfileTests: XCTestCase {

    /// 测试 6 款默认模型预设数量、ID 唯一性与默认激活项
    func testDefaultProfilesCountAndUniqueness() {
        let profiles = AIModelProfile.defaultProfiles
        XCTAssertEqual(profiles.count, 6, "预设模型必须严格包含 6 款")

        // 验证 ID 唯一性
        let ids = Set(profiles.map { $0.id })
        XCTAssertEqual(ids.count, 6, "模型 ID 必须全局唯一")

        // 验证包含全部核心提供商预设
        let expectedIDs: Set<String> = [
            "deepseek-r1",
            "openai-gpt4o",
            "anthropic-claude-35-sonnet",
            "google-gemini-15-pro",
            "chatgpt-plus-web",
            "on-device-coreml"
        ]
        XCTAssertEqual(ids, expectedIDs)

        // 验证仅且唯有一款默认激活模型
        let defaultActiveProfiles = profiles.filter { $0.isDefault }
        XCTAssertEqual(defaultActiveProfiles.count, 1, "默认激活模型必须仅有 1 个")
        XCTAssertEqual(defaultActiveProfiles.first?.id, "deepseek-r1")
        XCTAssertEqual(defaultActiveProfiles.first?.providerKind, .deepseek)
        XCTAssertTrue(defaultActiveProfiles.first?.isReasoningModel ?? false)
    }

    /// 测试预设模型提供商类型与鉴权方式属性映射
    func testDefaultProfilesAttributesIntegrity() {
        let profiles = Dictionary(uniqueKeysWithValues: AIModelProfile.defaultProfiles.map { ($0.id, $0) })

        // DeepSeek-R1
        let deepseek = profiles["deepseek-r1"]!
        XCTAssertEqual(deepseek.providerKind, .deepseek)
        XCTAssertEqual(deepseek.authMethod, .apiKey)
        XCTAssertTrue(deepseek.isReasoningModel)
        XCTAssertEqual(deepseek.modelIdentifier, "deepseek-reasoner")

        // OpenAI GPT-4o
        let gpt4o = profiles["openai-gpt4o"]!
        XCTAssertEqual(gpt4o.providerKind, .openai)
        XCTAssertEqual(gpt4o.authMethod, .apiKey)
        XCTAssertFalse(gpt4o.isReasoningModel)
        XCTAssertEqual(gpt4o.modelIdentifier, "gpt-4o")

        // Claude 3.5 Sonnet
        let claude = profiles["anthropic-claude-35-sonnet"]!
        XCTAssertEqual(claude.providerKind, .anthropic)
        XCTAssertEqual(claude.authMethod, .apiKey)
        XCTAssertEqual(claude.contextWindowTokens, 200_000)

        // Gemini 1.5 Pro
        let gemini = profiles["google-gemini-15-pro"]!
        XCTAssertEqual(gemini.providerKind, .gemini)
        XCTAssertEqual(gemini.authMethod, .apiKey)
        XCTAssertEqual(gemini.contextWindowTokens, 1_000_000)

        // ChatGPT Plus Web
        let web = profiles["chatgpt-plus-web"]!
        XCTAssertEqual(web.providerKind, .chatgptWeb)
        XCTAssertEqual(web.authMethod, .webSession)
        XCTAssertNil(web.apiKeyStorageKey)

        // iPad 本地 CoreML
        let coreML = profiles["on-device-coreml"]!
        XCTAssertEqual(coreML.providerKind, .onDeviceCoreML)
        XCTAssertEqual(coreML.authMethod, .none)
        XCTAssertNil(coreML.apiKeyStorageKey)
        XCTAssertEqual(coreML.endpoint, "offline://apple-neural-engine")
    }

    /// 测试 AIModelProfile 的 Codable 序列化与反序列化保真度
    func testCodableRoundtrip() throws {
        let original = AIModelProfile(
            id: "custom-qwen-72b",
            displayName: "通义千问 Qwen-2.5 72B",
            providerKind: .custom,
            endpoint: "https://dashscope.aliyuncs.com/compatible-mode/v1",
            modelIdentifier: "qwen-2.5-72b-instruct",
            isReasoningModel: true,
            authMethod: .apiKey,
            apiKeyStorageKey: "keychain_apikey_qwen",
            contextWindowTokens: 131_072,
            isDefault: false
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AIModelProfile.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.displayName, original.displayName)
        XCTAssertEqual(decoded.providerKind, original.providerKind)
        XCTAssertEqual(decoded.endpoint, original.endpoint)
        XCTAssertEqual(decoded.modelIdentifier, original.modelIdentifier)
        XCTAssertEqual(decoded.isReasoningModel, original.isReasoningModel)
        XCTAssertEqual(decoded.authMethod, original.authMethod)
        XCTAssertEqual(decoded.apiKeyStorageKey, original.apiKeyStorageKey)
        XCTAssertEqual(decoded.contextWindowTokens, original.contextWindowTokens)
        XCTAssertEqual(decoded.isDefault, original.isDefault)
    }

    /// 测试 Hashable 与 Equatable 契约
    func testHashableAndEquatable() {
        let p1 = AIModelProfile(
            id: "test-profile",
            displayName: "Test Name",
            providerKind: .openai,
            endpoint: "https://api.test.com",
            modelIdentifier: "model-1",
            isDefault: true
        )
        let p2 = AIModelProfile(
            id: "test-profile",
            displayName: "Test Name",
            providerKind: .openai,
            endpoint: "https://api.test.com",
            modelIdentifier: "model-1",
            isDefault: true
        )
        let p3 = AIModelProfile(
            id: "test-profile",
            displayName: "Different Name",
            providerKind: .openai,
            endpoint: "https://api.test.com",
            modelIdentifier: "model-1",
            isDefault: false
        )

        XCTAssertEqual(p1, p2)
        XCTAssertEqual(p1.hashValue, p2.hashValue)
        XCTAssertNotEqual(p1, p3)
    }

    /// 测试全部 ProviderKind 与 AuthMethod 枚举 CaseIterable 完备性
    func testEnumCasesCompleteness() {
        let allProviders = ProviderKind.allCases
        XCTAssertTrue(allProviders.contains(.deepseek))
        XCTAssertTrue(allProviders.contains(.openai))
        XCTAssertTrue(allProviders.contains(.anthropic))
        XCTAssertTrue(allProviders.contains(.gemini))
        XCTAssertTrue(allProviders.contains(.ollama))
        XCTAssertTrue(allProviders.contains(.custom))
        XCTAssertTrue(allProviders.contains(.chatgptWeb))
        XCTAssertTrue(allProviders.contains(.onDeviceCoreML))

        let allAuth = AuthMethod.allCases
        XCTAssertTrue(allAuth.contains(.apiKey))
        XCTAssertTrue(allAuth.contains(.webSession))
        XCTAssertTrue(allAuth.contains(.none))
    }
}

// MARK: - 2. KeychainStorageTests (凭据安全存取与降级保底测试套件)

/// KeychainStorageManager 安全凭据存取、内存降级与并发安全测试套件
final class KeychainStorageTests: XCTestCase {

    private var keychain: KeychainStorageManager!

    override func setUp() async throws {
        try await super.setUp()
        self.keychain = KeychainStorageManager(serviceName: "com.studyos.test.\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        await keychain.clearAll()
        self.keychain = nil
        try await super.tearDown()
    }

    /// 测试保存凭据与读取凭据
    func testSaveAndRetrieveSecret() async throws {
        let testKey = "keychain_apikey_deepseek_test"
        let secret = "sk-deepseek-mock-key-1234567890abcdef"

        try await keychain.saveSecret(secret, forKey: testKey)

        let retrieved = await keychain.getSecret(forKey: testKey)
        XCTAssertEqual(retrieved, secret)

        let nonExistent = await keychain.getSecret(forKey: "non_existent_key")
        XCTAssertNil(nonExistent)
    }

    /// 测试覆写已有凭据
    func testOverwriteExistingSecret() async throws {
        let key = "keychain_apikey_openai_test"
        try await keychain.saveSecret("initial-key", forKey: key)
        var current = await keychain.getSecret(forKey: key)
        XCTAssertEqual(current, "initial-key")

        try await keychain.saveSecret("updated-key-token-new", forKey: key)
        current = await keychain.getSecret(forKey: key)
        XCTAssertEqual(current, "updated-key-token-new")
    }

    /// 测试删除凭据
    func testDeleteSecret() async throws {
        let key = "keychain_apikey_to_delete"
        try await keychain.saveSecret("temporary-secret", forKey: key)

        let deleted = try await keychain.deleteSecret(forKey: key)
        XCTAssertTrue(deleted)

        let afterDelete = await keychain.getSecret(forKey: key)
        XCTAssertNil(afterDelete)
    }

    /// 测试清空所有内存缓存凭据
    func testClearAllSecrets() async throws {
        try await keychain.saveSecret("key-1", forKey: "k1")
        try await keychain.saveSecret("key-2", forKey: "k2")

        await keychain.clearAll()

        let r1 = await keychain.getSecret(forKey: "k1")
        let r2 = await keychain.getSecret(forKey: "k2")
        XCTAssertNil(r1)
        XCTAssertNil(r2)
    }

    /// 测试并发访问安全性（多协程并发写入与读取无死锁与数据竞争）
    func testConcurrentAccessSafety() async throws {
        let manager = self.keychain!

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    let key = "concurrent_key_\(i)"
                    let secret = "secret_val_\(i)"
                    try await manager.saveSecret(secret, forKey: key)
                    let read = await manager.getSecret(forKey: key)
                    XCTAssertEqual(read, secret)
                }
            }
            try await group.waitForAll()
        }
    }
}

// MARK: - 3. ModelProviderRegistryTests (动态多模型注册表与工厂测试套件)

/// ModelProviderRegistry 动态注册表、活动模型切换与 Provider 动态拉起测试套件
final class ModelProviderRegistryTests: XCTestCase {

    private var tempDirectoryURL: URL!
    private var sandbox: LocalSandboxManager!
    private var keychain: KeychainStorageManager!
    private var registry: ModelProviderRegistry!

    override func setUp() async throws {
        try await super.setUp()
        let tempBase = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("StudyOS_ModelRegistryTests_\(UUID().uuidString)", isDirectory: true)
        self.tempDirectoryURL = tempBase
        self.sandbox = LocalSandboxManager(rootDirectoryURL: tempBase)
        self.keychain = KeychainStorageManager(serviceName: "com.studyos.test.reg.\(UUID().uuidString)")
        self.registry = ModelProviderRegistry(keychain: keychain, sandbox: sandbox)
    }

    override func tearDown() async throws {
        if let temp = tempDirectoryURL {
            try? FileManager.default.removeItem(at: temp)
        }
        await keychain.clearAll()
        self.registry = nil
        self.keychain = nil
        self.sandbox = nil
        try await super.tearDown()
    }

    /// 测试注册表初始化包含 6 款默认模型，且默认激活 DeepSeek-R1
    func testRegistryInitializationWithDefaults() async {
        let profiles = await registry.listProfiles()
        XCTAssertEqual(profiles.count, 6)

        let active = await registry.getActiveProfile()
        XCTAssertEqual(active.id, "deepseek-r1")
        XCTAssertEqual(active.providerKind, .deepseek)
        XCTAssertTrue(active.isDefault)
    }

    /// 测试切换当前激活模型 (setActiveProfile) 状态联动
    func testSetActiveProfile() async throws {
        // 切换至 OpenAI GPT-4o
        try await registry.setActiveProfile(id: "openai-gpt4o")

        let active = await registry.getActiveProfile()
        XCTAssertEqual(active.id, "openai-gpt4o")
        XCTAssertTrue(active.isDefault)

        // 验证原默认模型 isDefault 变为 false
        let all = await registry.listProfiles()
        let oldDefault = all.first(where: { $0.id == "deepseek-r1" })
        XCTAssertFalse(oldDefault?.isDefault ?? true)

        // 尝试激活不存在的模型应抛错
        do {
            try await registry.setActiveProfile(id: "non-existent-id")
            XCTFail("激活不存在的模型 ID 应抛出异常")
        } catch let error as LLMProviderError {
            if case .invalidResponse = error {
                // 正确拦截
            } else {
                XCTFail("非预期的错误类型: \(error)")
            }
        }
    }

    /// 测试保存自定义模型配置与沙盒冷启动恢复持久化
    func testSaveCustomProfileAndSandboxPersistence() async throws {
        let customProfile = AIModelProfile(
            id: "ollama-qwen-7b",
            displayName: "Ollama 本地千问 7B",
            providerKind: .ollama,
            endpoint: "http://127.0.0.1:11434/v1",
            modelIdentifier: "qwen2.5:7b",
            isDefault: false
        )

        try await registry.saveProfile(customProfile)

        let profiles = await registry.listProfiles()
        XCTAssertEqual(profiles.count, 7)
        let found = profiles.first(where: { $0.id == "ollama-qwen-7b" })
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.displayName, "Ollama 本地千问 7B")

        // 模拟冷启动：使用相同沙盒创建全新 Registry 实例
        let coldRegistry = ModelProviderRegistry(keychain: keychain, sandbox: sandbox)
        let coldProfiles = await coldRegistry.listProfiles()
        XCTAssertEqual(coldProfiles.count, 7, "冷启动后自定义模型应通过沙盒持久化恢复")
        XCTAssertTrue(coldProfiles.contains(where: { $0.id == "ollama-qwen-7b" }))
    }

    /// 测试删除自定义模型配置及禁止删除默认激活模型保护
    func testDeleteProfileValidations() async throws {
        let tempProfile = AIModelProfile(
            id: "temp-to-delete",
            displayName: "临时待删模型",
            providerKind: .custom,
            endpoint: "https://api.temp.com/v1",
            modelIdentifier: "temp-model",
            isDefault: false
        )
        try await registry.saveProfile(tempProfile)

        // 删除自定义非默认模型应成功
        let deleted = try await registry.deleteProfile(id: "temp-to-delete")
        XCTAssertTrue(deleted)
        let afterList = await registry.listProfiles()
        XCTAssertFalse(afterList.contains(where: { $0.id == "temp-to-delete" }))

        // 尝试删除默认激活模型必须被安全阻断
        let active = await registry.getActiveProfile()
        do {
            _ = try await registry.deleteProfile(id: active.id)
            XCTFail("删除当前默认模型必须抛出保护异常")
        } catch let error as LLMProviderError {
            if case .invalidResponse(let msg) = error {
                XCTAssertTrue(msg.contains("禁止删除"))
            } else {
                XCTFail("非预期的错误: \(error)")
            }
        }

        // 尝试删除不存在的模型返回 false
        let deleteNonExistent = try await registry.deleteProfile(id: "not-found-id")
        XCTAssertFalse(deleteNonExistent)
    }

    /// 测试动态根据 profile 拉起对应类型的 Provider（多态工厂验证）
    func testDynamicProviderInstantiation() async throws {
        // 1. 端侧 CoreML 模型 -> LocalMockLLMProvider
        let coreMLProfile = (await registry.listProfiles()).first(where: { $0.id == "on-device-coreml" })!
        let coreMLProvider = try await registry.getProvider(for: coreMLProfile)
        XCTAssertTrue(coreMLProvider is LocalMockLLMProvider || coreMLProvider is LocalLLMProviderProtocol)
        XCTAssertEqual(coreMLProvider.snapshot.profileID, "on-device-coreml")

        // 2. ChatGPT Plus Web 会话 -> ChatGPTWebStreamingProvider
        let webProfile = (await registry.listProfiles()).first(where: { $0.id == "chatgpt-plus-web" })!
        let webProvider = try await registry.getProvider(for: webProfile)
        XCTAssertTrue(webProvider is ChatGPTWebStreamingProvider)
        XCTAssertEqual(webProvider.snapshot.profileID, "chatgpt-plus-web")
        XCTAssertEqual(webProvider.snapshot.endpoint, "https://chatgpt.com")

        // 3. OpenAI / DeepSeek / Anthropic -> OpenAICompatibleProvider
        let deepseekProfile = (await registry.listProfiles()).first(where: { $0.id == "deepseek-r1" })!
        let deepseekProvider = try await registry.getProvider(for: deepseekProfile)
        XCTAssertTrue(deepseekProvider is OpenAICompatibleProvider)
        XCTAssertEqual(deepseekProvider.snapshot.profileID, "deepseek-r1")
        XCTAssertEqual(deepseekProvider.snapshot.model, "deepseek-reasoner")

        // 验证 Provider 缓存机制（二次获取返回同一实例引用或有效缓存）
        let cachedDeepseekProvider = try await registry.getProvider(for: deepseekProfile)
        XCTAssertEqual(cachedDeepseekProvider.profileID, deepseekProvider.profileID)
    }

    /// 测试 getActiveProvider 随 activeProfile 联动
    func testGetActiveProviderLinkage() async throws {
        try await registry.setActiveProfile(id: "chatgpt-plus-web")
        let activeProvider = try await registry.getActiveProvider()
        XCTAssertEqual(activeProvider.profileID, "chatgpt-plus-web")
        XCTAssertTrue(activeProvider is ChatGPTWebStreamingProvider)

        try await registry.setActiveProfile(id: "on-device-coreml")
        let coreMLProvider = try await registry.getActiveProvider()
        XCTAssertEqual(coreMLProvider.profileID, "on-device-coreml")
    }

    /// 测试 ChatGPTWebStreamingProvider 流式吐字生成
    func testChatGPTWebStreamingProviderExecution() async throws {
        let provider = ChatGPTWebStreamingProvider()
        let messages = [LLMMessage(role: .user, content: "请解释贝叶斯定理")]
        let stream = try await provider.streamCompletion(messages: messages, options: LLMCompletionOptions())

        var fullOutput = ""
        for try await chunk in stream {
            fullOutput += chunk.delta
        }

        XCTAssertTrue(fullOutput.contains("ChatGPT Plus"))
        XCTAssertTrue(fullOutput.contains("贝叶斯定理"))
    }
}

// MARK: - 4. ConnectionHandshakeTests (连接握手与 Key 校验测试套件)

/// ModelProviderRegistry.testConnection 探测握手与错误提示测试套件
final class ConnectionHandshakeTests: XCTestCase {

    private var tempDirectoryURL: URL!
    private var sandbox: LocalSandboxManager!
    private var keychain: KeychainStorageManager!
    private var registry: ModelProviderRegistry!

    override func setUp() async throws {
        try await super.setUp()
        let tempBase = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("StudyOS_HandshakeTests_\(UUID().uuidString)", isDirectory: true)
        self.tempDirectoryURL = tempBase
        self.sandbox = LocalSandboxManager(rootDirectoryURL: tempBase)
        self.keychain = KeychainStorageManager(serviceName: "com.studyos.test.hs.\(UUID().uuidString)")
        self.registry = ModelProviderRegistry(keychain: keychain, sandbox: sandbox)
    }

    override func tearDown() async throws {
        if let temp = tempDirectoryURL {
            try? FileManager.default.removeItem(at: temp)
        }
        await keychain.clearAll()
        self.registry = nil
        self.keychain = nil
        self.sandbox = nil
        try await super.tearDown()
    }

    /// 测试端侧离线 CoreML 模型握手（零网络立即成功）
    func testConnectionOnDeviceCoreML() async throws {
        let coreMLProfile = AIModelProfile(
            id: "test-coreml",
            displayName: "端侧神经引擎",
            providerKind: .onDeviceCoreML,
            endpoint: "offline://apple-neural-engine",
            modelIdentifier: "distill-q4",
            authMethod: .none
        )

        let result = try await registry.testConnection(profile: coreMLProfile, apiKey: nil)
        XCTAssertTrue(result.success, "端侧模型握手必须成功")
        XCTAssertLessThanOrEqual(result.latencyMs, 10, "端侧模型握手延迟应在 10ms 以内")
        XCTAssertTrue(result.message.contains("CoreML"))
        XCTAssertTrue(result.message.contains("就绪"))
    }

    /// 测试 ChatGPT Plus Web 会话探测（内置会话连通正常）
    func testConnectionChatGPTWebSession() async throws {
        let webProfile = AIModelProfile(
            id: "test-web",
            displayName: "ChatGPT Plus Web",
            providerKind: .chatgptWeb,
            endpoint: "https://chatgpt.com",
            modelIdentifier: "gpt-4o-web",
            authMethod: .webSession
        )

        let result = try await registry.testConnection(profile: webProfile, apiKey: nil)
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.message.contains("ChatGPT Plus"))
        XCTAssertTrue(result.message.contains("连通正常"))
    }

    /// 测试未配置 API Key 时的优雅阻断提示
    func testConnectionMissingApiKeyGracefulMessage() async throws {
        let cloudProfile = AIModelProfile(
            id: "test-openai-nokey",
            displayName: "OpenAI GPT-4o",
            providerKind: .openai,
            endpoint: "https://api.openai.com/v1",
            modelIdentifier: "gpt-4o",
            authMethod: .apiKey,
            apiKeyStorageKey: "empty_key_storage"
        )

        // 未存入任何 key，且 apiKey 参数传入 nil
        let result = try await registry.testConnection(profile: cloudProfile, apiKey: nil)
        XCTAssertFalse(result.success, "未提供 Key 时握手必须返回失败")
        XCTAssertEqual(result.latencyMs, 0)
        XCTAssertTrue(result.message.contains("未配置 API Key"))
    }

    /// 测试非法端点 URL 握手拦截
    func testConnectionInvalidEndpointURL() async throws {
        let invalidProfile = AIModelProfile(
            id: "test-invalid-url",
            displayName: "Invalid URL Model",
            providerKind: .custom,
            endpoint: "",
            modelIdentifier: "custom-model",
            authMethod: .apiKey
        )

        let result = try await registry.testConnection(profile: invalidProfile, apiKey: "sk-mock-key")
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.message.contains("非法") || result.message.contains("失败"))
    }
}
