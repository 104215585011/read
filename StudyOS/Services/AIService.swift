import Foundation

/// 正在执行的 AI 尝试上下文状态
private enum AttemptState: Sendable {
    case preparing
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
        throw LLMProviderError.invalidResponse("仅有 Manifest 无法还原已确认正文；请传入 AggregatedContext")
    }

    public func generateStream(
        request: AIRequest,
        context: AggregatedContext
    ) async throws -> AsyncThrowingStream<LLMChunk, Error> {
        let key = attemptKey(requestID: request.requestID, attemptID: request.attemptID)
        if let existing = attempts[key] {
            switch existing {
            case .preparing, .running:
                throw LLMProviderError.invalidResponse("Attempt \(request.attemptID) 正在运行中，禁止重复执行")
            case .terminal(let status):
                throw LLMProviderError.invalidResponse("Attempt \(request.attemptID) 已进入终态 (\(status.rawValue))，禁止重复执行")
            }
        }
        // Reserve before the first suspension: actor reentrancy must not dispatch twice.
        attempts[key] = .preparing
        do {
            try Task.checkCancellation()
            guard context.capturedRequest == request,
                  context.manifest.providerSnapshot == provider.snapshot,
                  request.providerProfileID == provider.profileID else {
                throw LLMProviderError.invalidResponse("上下文请求或 Provider 已变化，请重新准备并确认")
            }
            guard let document = await metadataEngine.getDocument(id: request.documentID),
                  document.revision == request.documentRevision else {
                throw LLMProviderError.invalidResponse("文档不存在或版本已变化")
            }
            try Task.checkCancellation()
            if isAttemptCancelled(key: key) { throw LLMProviderError.cancelled }
            let pages: [Int]
            switch request.scope {
            case .selection(let anchor):
                guard anchor.documentID == request.documentID,
                      anchor.documentRevision == request.documentRevision,
                      anchor.availability == .active,
                      !(anchor.quote ?? "").isEmpty else {
                    throw LLMProviderError.invalidResponse("选区无效或没有文本")
                }
                pages = [anchor.pageIndex0]
            case .page(let index): pages = [index]
            case .chapter(_, let start, let end):
                guard start >= 0, end >= start, end < document.pageCount else {
                    throw LLMProviderError.invalidResponse("章节页范围无效")
                }
                pages = Array(start...end)
            case .document:
                throw LLMProviderError.unsupportedCapability("全文学习需独立分批任务，不能将目录当全文正文")
            }
            guard pages.allSatisfy({ $0 >= 0 && $0 < document.pageCount }),
                  pages.allSatisfy({ page in context.manifest.outboundItems.contains {
                      $0.kind == .documentText && $0.pageCoverage.contains(page) && $0.byteCount > 0
                  } }) else {
                throw LLMProviderError.invalidResponse("请求范围缺少正文，请完成文本提取后重新准备上下文")
            }
        } catch {
            let cancelled = isAttemptCancelled(key: key) || error is CancellationError || (error as? LLMProviderError) == .cancelled
            markTerminal(key: key, status: cancelled ? .cancelled : .failed)
            throw cancelled ? LLMProviderError.cancelled : error
        }

        let messages = context.messages
        let options = LLMCompletionOptions(temperature: 0.7, maxTokens: context.manifest.reservedOutputTokens, timeoutInterval: 45.0)
        return AsyncThrowingStream<LLMChunk, Error> { continuation in
            let streamingTask = Task {
                do {
                    try Task.checkCancellation()
                    // Handshake belongs to the registered task, so cancel works before the first byte.
                    let underlyingStream = try await self.provider.streamCompletion(messages: messages, options: options)
                    try Task.checkCancellation()
                    for try await chunk in underlyingStream {
                        try Task.checkCancellation()
                        if self.isAttemptCancelled(key: key) { throw LLMProviderError.cancelled }
                        continuation.yield(chunk)
                    }
                    try Task.checkCancellation()
                    if self.isAttemptCancelled(key: key) { throw LLMProviderError.cancelled }
                    self.markTerminal(key: key, status: .completed)
                    continuation.finish()
                } catch {
                    let cancelled = Task.isCancelled || self.isAttemptCancelled(key: key) || error is CancellationError || (error as? LLMProviderError) == .cancelled
                    self.markTerminal(key: key, status: cancelled ? .cancelled : .failed)
                    continuation.finish(throwing: cancelled ? LLMProviderError.cancelled : error)
                }
            }
            self.registerAttempt(key: key, task: streamingTask, continuation: continuation)
            continuation.onTermination = { @Sendable _ in
                streamingTask.cancel()
                Task { await self.handleStreamTermination(key: key) }
            }
        }
    }

    private func attemptKey(requestID: String, attemptID: String) -> String {
        "\(requestID.utf8.count):\(requestID)\(attemptID)"
    }

    /// 取消指定的 AI 尝试 (支持 alreadyTerminal 防御)
    public func cancel(requestID: String, attemptID: String) async -> Bool {
        let key = attemptKey(requestID: requestID, attemptID: attemptID)
        guard let state = attempts[key] else {
            // 未找到该 attempt，直接记录为 cancelled
            attempts[key] = .terminal(.cancelled)
            return true
        }

        switch state {
        case .terminal:
            // 契约规定：已终态的取消属于 alreadyTerminal，不覆写已有 failed 或 completed
            return false
        case .preparing:
            attempts[key] = .terminal(.cancelled)
            return true
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
        case .preparing, .running:
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
        case .preparing, .running:
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
        case .preparing, .running:
            return .running
        case .terminal(let status):
            return status
        }
    }
}
