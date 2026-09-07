import Foundation

/// AI 助学核心服务协议
public protocol AIServiceProtocol: Sendable {
    /// 基于请求与已确认清单发起流式 AI 生成
    func generateStream(
        request: AIRequest,
        manifest: ContextManifest
    ) async throws -> AsyncThrowingStream<LLMChunk, Error>

    /// 取消正在进行的请求尝试
    func cancel(requestID: String, attemptID: String) async -> Bool

    /// 校验提取来源锚点有效性
    func validateSources(sources: [SourceAnchor]) async -> [SourceAnchor]
}
