import Foundation

/// 本地端侧离线 Mock Provider 实现 (LocalMockLLMProvider)
/// 零外部依赖，纯原生 Swift Concurrency，模拟离线端侧模型推理与加载状态机
public final class LocalMockLLMProvider: LocalLLMProviderProtocol, @unchecked Sendable {
    public let profileID: String
    public let localConfig: LocalModelConfig

    private let lock = NSLock()
    private var _state: ModelState = .ready
    private var _errorMessage: String?

    public init(
        profileID: String = "local-mock-provider",
        localConfig: LocalModelConfig = LocalModelConfig()
    ) {
        self.profileID = profileID
        self.localConfig = localConfig
    }

    public var snapshot: ProviderSnapshot {
        ProviderSnapshot(
            profileID: profileID,
            endpoint: "offline://local-device-inference",
            model: localConfig.modelID
        )
    }

    public var inferenceStatus: LocalModelInferenceStatus {
        get async {
            lock.lock()
            defer { lock.unlock() }
            return LocalModelInferenceStatus(
                isReady: _state == .ready,
                state: _state,
                memoryUsageBytes: _state == .ready ? 512 * 1024 * 1024 : 0,
                loadedModelID: _state == .ready ? localConfig.modelID : nil,
                errorMessage: _errorMessage
            )
        }
    }

    public func loadModel() async throws {
        lock.lock()
        _state = .loading
        _errorMessage = nil
        lock.unlock()

        // 模拟端侧模型载入内存过程
        try? await Task.sleep(nanoseconds: 20_000_000)

        lock.lock()
        _state = .ready
        lock.unlock()
    }

    public func unloadModel() async {
        lock.lock()
        _state = .unloaded
        _errorMessage = nil
        lock.unlock()
    }

    public func isReady() async -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _state == .ready
    }

    /// 模拟流式生成
    public func streamCompletion(
        messages: [LLMMessage],
        options: LLMCompletionOptions
    ) async throws -> AsyncThrowingStream<LLMChunk, Error> {
        let ready = await isReady()
        if !ready {
            // 若处于未就绪状态，尝试按需自动拉起
            try await loadModel()
        }

        // 构造端侧离线结构化助学回答
        let userPrompt = messages.last(where: { $0.role == .user })?.content ?? ""
        let fullResponse: String

        if userPrompt.contains("全文") || userPrompt.contains("大纲") || userPrompt.contains("概括") {
            fullResponse = """
            【离线端侧核心研读解析】
            本文档系统阐述了核心理论框架，关键概念节点清晰。主要内容可分为三个重点维度：
            1. 基础架构与定义：明确核心边界与前提条件。
            2. 关键难点分析：重点在跨模块协同与边界校验逻辑。
            3. 实践考点提示：建议重点关注相关推导及典型示例。
            """
        } else if userPrompt.contains("难点") || userPrompt.contains("考点") {
            fullResponse = """
            【端侧离线难点解析】
            依据本地上下文知识提取：
            - 核心难点：主要在于边界处理与并发保护。
            - 推荐策略：采用不变性约束与分批处理模式确保稳定可靠。
            """
        } else {
            fullResponse = """
            【离线助学解答】
            针对您提出的内容：「\(userPrompt.prefix(50))」
            基于端侧本地离线模型研读，核心要点如下：
            1. 概念清晰，遵循原文锚点定义的逻辑链路；
            2. 关联论证充分，可作为进一步深入学习的基石。
            """
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                let chunkSize = 4
                var currentIndex = fullResponse.startIndex

                while currentIndex < fullResponse.endIndex {
                    if Task.isCancelled {
                        continuation.finish(throwing: LLMProviderError.cancelled)
                        return
                    }

                    let nextIndex = fullResponse.index(
                        currentIndex,
                        offsetBy: chunkSize,
                        limitedBy: fullResponse.endIndex
                    ) ?? fullResponse.endIndex
                    let delta = String(fullResponse[currentIndex..<nextIndex])
                    currentIndex = nextIndex

                    continuation.yield(LLMChunk(delta: delta))

                    // 微小流式间隔
                    try? await Task.sleep(nanoseconds: 10_000_000)
                }

                continuation.yield(LLMChunk(delta: "", finishReason: "stop", usageEstimate: fullResponse.count / 3))
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
