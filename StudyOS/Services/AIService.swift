import Foundation

/// 正在执行的 AI 尝试上下文状态
private enum AttemptState: Sendable {
    case running(task: Task<Void, Never>, continuation: AsyncThrowingStream<LLMChunk, Error>.Continuation)
    case terminal(AIResultStatus) // completed, failed, cancelled
}

/// 核心 AI 助学服务实现 (Actor 隔离，严格保证状态机终态与并发安全)
public actor AIService: AIServiceProtocol {
    private let provider: LLMProviderProtocol
    private let metadataEngine: MetadataStorageEngine
    private var attempts: [String: AttemptState] = [:] // key: "\(requestID)_\(attemptID)"

    public init(
        provider: LLMProviderProtocol,
        metadataEngine: MetadataStorageEngine
    ) {
        self.provider = provider
        self.metadataEngine = metadataEngine
    }

    // MARK: - AIServiceProtocol

    public func generateStream(
        request: AIRequest,
        manifest: ContextManifest
    ) async throws -> AsyncThrowingStream<LLMChunk, Error> {
        let key = "\(request.requestID)_\(request.attemptID)"

        // 终态检查：若该 attempt 已经进入终态，禁止重复触发
        if let existing = attempts[key] {
            switch existing {
            case .terminal(let status):
                throw LLMProviderError.invalidResponse("Attempt \(request.attemptID) 已进入终态 (\(status.rawValue))，禁止重复执行")
            case .running:
                throw LLMProviderError.invalidResponse("Attempt \(request.attemptID) 正在运行中")
            }
        }

        // 1. 组装 LLM 输入消息
        let aggregator = ContextAggregator()
        let aggregated = aggregator.buildContext(
            request: request,
            providerSnapshot: provider.snapshot,
            document: await metadataEngine.getDocument(id: request.documentID)
        )

        let messages: [LLMMessage] = [
            LLMMessage(role: .system, content: aggregated.systemPrompt),
            LLMMessage(role: .user, content: aggregated.userPrompt)
        ]

        let options = LLMCompletionOptions(temperature: 0.7, timeoutInterval: 45.0)

        // 2. 调用底座 Provider 获取底层流
        let underlyingStream = try await provider.streamCompletion(messages: messages, options: options)

        // 3. 包装返回上层安全流，并在 Actor 内记录 Task 与终态裁决
        return AsyncThrowingStream<LLMChunk, Error> { continuation in
            let streamingTask = Task {
                var isTerminalRecorded = false

                do {
                    for try await chunk in underlyingStream {
                        // 如果被取消或进入终态，停止产出
                        if Task.isCancelled {
                            await self.markTerminal(key: key, status: .cancelled)
                            isTerminalRecorded = true
                            continuation.finish(throwing: LLMProviderError.cancelled)
                            return
                        }

                        // 检查 Actor 内部当前 attempt 是否被外部标记为 cancelled
                        if await self.isAttemptCancelled(key: key) {
                            isTerminalRecorded = true
                            continuation.finish(throwing: LLMProviderError.cancelled)
                            return
                        }

                        continuation.yield(chunk)
                    }

                    // 正常流结束，标记为 completed
                    await self.markTerminal(key: key, status: .completed)
                    isTerminalRecorded = true
                    continuation.finish()
                } catch is CancellationError {
                    await self.markTerminal(key: key, status: .cancelled)
                    isTerminalRecorded = true
                    continuation.finish(throwing: LLMProviderError.cancelled)
                } catch {
                    // 任何网络或服务端异常，标记为 failed（failed 与 cancelled 互斥）
                    let currentStatus = await self.currentStatus(key: key)
                    if currentStatus != .cancelled {
                        await self.markTerminal(key: key, status: .failed)
                    }
                    isTerminalRecorded = true
                    continuation.finish(throwing: error)
                }
            }

            self.registerAttempt(key: key, task: streamingTask, continuation: continuation)

            continuation.onTermination = { @Sendable _ in
                streamingTask.cancel()
                Task {
                    await self.handleStreamTermination(key: key)
                }
            }
        }
    }

    /// 取消指定的 AI 尝试 (支持 alreadyTerminal 防御)
    public func cancel(requestID: String, attemptID: String) async -> Bool {
        let key = "\(requestID)_\(attemptID)"
        guard let state = attempts[key] else {
            // 未找到该 attempt，直接记录为 cancelled
            attempts[key] = .terminal(.cancelled)
            return true
        }

        switch state {
        case .terminal:
            // 契约规定：已终态的取消属于 alreadyTerminal，不覆写已有 failed 或 completed
            return false
        case .running(let task, let continuation):
            attempts[key] = .terminal(.cancelled)
            task.cancel()
            continuation.finish(throwing: LLMProviderError.cancelled)
            return true
        }
    }

    /// 校验提取来源锚点有效性
    public func validateSources(sources: [SourceAnchor]) async -> [SourceAnchor] {
        var validated: [SourceAnchor] = []
        for anchor in sources {
            guard anchor.availability == .active else { continue }
            guard let doc = await metadataEngine.getDocument(id: anchor.documentID) else { continue }
            guard doc.revision == anchor.documentRevision else { continue }
            guard anchor.pageIndex0 >= 0, anchor.pageIndex0 < doc.pageCount else { continue }
            validated.append(anchor)
        }
        return validated
    }

    // MARK: - 内部辅助方法

    private func registerAttempt(key: String, task: Task<Void, Never>, continuation: AsyncThrowingStream<LLMChunk, Error>.Continuation) {
        // 如果外部已标记取消，则直接 cancel task 与 continuation
        if let existing = attempts[key], case .terminal(.cancelled) = existing {
            task.cancel()
            continuation.finish(throwing: LLMProviderError.cancelled)
            return
        }
        attempts[key] = .running(task: task, continuation: continuation)
    }

    private func handleStreamTermination(key: String) {
        guard let state = attempts[key] else { return }
        switch state {
        case .running:
            attempts[key] = .terminal(.cancelled)
        case .terminal:
            break
        }
    }

    private func markTerminal(key: String, status: AIResultStatus) {
        guard let current = attempts[key] else {
            attempts[key] = .terminal(status)
            return
        }
        switch current {
        case .terminal:
            // alreadyTerminal: 保持首次终态，不被后续迟到事件覆写
            break
        case .running:
            attempts[key] = .terminal(status)
        }
    }

    private func isAttemptCancelled(key: String) -> Bool {
        guard let state = attempts[key] else { return false }
        if case .terminal(.cancelled) = state {
            return true
        }
        return false
    }

    private func currentStatus(key: String) -> AIResultStatus? {
        guard let state = attempts[key] else { return nil }
        switch state {
        case .running:
            return .running
        case .terminal(let status):
            return status
        }
    }
}
