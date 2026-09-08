import Foundation

/// 弱网与网络弹性重试引擎实现 (NetworkResilienceRetryEngine)
/// 纯原生 Swift Actor 隔离，提供带 Jitter 的指数退避重试，严密区分可重试故障与不可重试终态 (R12)
public actor NetworkResilienceRetryEngine: NetworkResilienceRetryEngineProtocol {
    private var totalOperations: Int = 0
    private var totalRetries: Int = 0
    private var successfulRetries: Int = 0
    private var nonRetryableFailures: Int = 0
    private var exhaustedFailures: Int = 0

    public init() {}

    /// 执行带弹性重试保护的异步操作
    public func execute<T: Sendable>(
        policy: RetryPolicy = .default,
        operationID: String = UUID().uuidString,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        totalOperations += 1
        var currentAttempt = 1

        while true {
            try Task.checkCancellation()

            do {
                let result = try await operation()
                if currentAttempt > 1 {
                    successfulRetries += 1
                }
                return result
            } catch {
                try Task.checkCancellation()

                // 判断是否允许重试
                guard policy.canRetry(error: error) else {
                    nonRetryableFailures += 1
                    throw error
                }

                // 判断重试次数是否已耗尽
                if currentAttempt >= policy.maxAttempts {
                    exhaustedFailures += 1
                    throw error
                }

                totalRetries += 1
                let delay = policy.delay(forAttempt: currentAttempt)
                currentAttempt += 1

                if delay > 0 {
                    let nanoseconds = UInt64(delay * 1_000_000_000)
                    try await Task.sleep(nanoseconds: nanoseconds)
                }
            }
        }
    }

    /// 评估指定错误在特定策略下是否可重试
    public nonisolated func canRetry(error: Error, policy: RetryPolicy) -> Bool {
        policy.canRetry(error: error)
    }

    /// 获取当前引擎的运行与重试统计快照
    public func getStats() async -> RetryEngineStats {
        RetryEngineStats(
            totalOperations: totalOperations,
            totalRetries: totalRetries,
            successfulRetries: successfulRetries,
            nonRetryableFailures: nonRetryableFailures,
            exhaustedFailures: exhaustedFailures
        )
    }

    /// 重置统计快照
    public func resetStats() async {
        totalOperations = 0
        totalRetries = 0
        successfulRetries = 0
        nonRetryableFailures = 0
        exhaustedFailures = 0
    }
}
