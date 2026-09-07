import Foundation

/// OpenAI 兼容 SSE (Server-Sent Events) 流式 Provider 实现
public final class OpenAICompatibleProvider: LLMProviderProtocol, Sendable {
    public let profileID: String
    public let baseURL: URL
    public let apiKey: String
    public let modelName: String
    public let customHeaders: [String: String]
    private let urlSession: URLSession

    public var snapshot: ProviderSnapshot {
        ProviderSnapshot(
            profileID: profileID,
            configRevision: 1,
            endpoint: baseURL.absoluteString,
            model: modelName
        )
    }

    public init(
        profileID: String = "openai-default",
        baseURL: URL,
        apiKey: String,
        modelName: String = "gpt-4o",
        customHeaders: [String: String] = [:],
        urlSession: URLSession = .shared
    ) {
        self.profileID = profileID
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.modelName = modelName
        self.customHeaders = customHeaders
        self.urlSession = urlSession
    }

    // MARK: - LLMProviderProtocol

    public func streamCompletion(
        messages: [LLMMessage],
        options: LLMCompletionOptions
    ) async throws -> AsyncThrowingStream<LLMChunk, Error> {
        // 1. 构造目标 URL：如 baseURL 结尾不是 /chat/completions 则拼接
        var endpointURL = baseURL
        if !endpointURL.absoluteString.hasSuffix("/chat/completions") {
            endpointURL = endpointURL.appendingPathComponent("chat/completions")
        }

        // 2. 构造 Request
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        for (headerKey, headerVal) in customHeaders {
            request.setValue(headerVal, forHTTPHeaderField: headerKey)
        }
        request.timeoutInterval = options.timeoutInterval

        // 3. 构造请求体
        let payload = OpenAIChatCompletionRequest(
            model: modelName,
            messages: messages.map { OpenAIChatMessage(role: $0.role.rawValue, content: $0.content) },
            stream: true,
            temperature: options.temperature,
            maxTokens: options.maxTokens,
            topP: options.topP
        )

        let bodyData: Data
        do {
            bodyData = try JSONEncoder().encode(payload)
        } catch {
            throw LLMProviderError.invalidResponse("请求参数编码失败: \(error.localizedDescription)")
        }
        request.httpBody = bodyData

        // 4. 返回异步流，由 URLSession.bytes 处理
        let session = self.urlSession
        let finalRequest = request
        return AsyncThrowingStream<LLMChunk, Error> { continuation in
            let task = Task {
                do {
                    // 支持 Task 级主动取消
                    if Task.isCancelled {
                        continuation.finish(throwing: LLMProviderError.cancelled)
                        return
                    }

                    let (asyncBytes, response) = try await session.bytes(for: finalRequest)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: LLMProviderError.invalidResponse("非 HTTP 响应"))
                        return
                    }

                    // 状态码拦截与映射
                    switch httpResponse.statusCode {
                    case 200...299:
                        break // 正常流式响应
                    case 401, 403:
                        continuation.finish(throwing: LLMProviderError.unauthorized("HTTP \(httpResponse.statusCode) 鉴权失败"))
                        return
                    case 429:
                        let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
                        continuation.finish(throwing: LLMProviderError.rateLimited(retryAfterSeconds: retryAfter, "触发调用频率限制"))
                        return
                    case 500...599:
                        continuation.finish(throwing: LLMProviderError.serverError(statusCode: httpResponse.statusCode, "远端服务端异常"))
                        return
                    default:
                        continuation.finish(throwing: LLMProviderError.serverError(statusCode: httpResponse.statusCode, "HTTP 状态码异常"))
                        return
                    }

                    // 逐行解析 SSE 响应
                    for try await line in asyncBytes.lines {
                        if Task.isCancelled {
                            continuation.finish(throwing: LLMProviderError.cancelled)
                            return
                        }

                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty || trimmed.hasPrefix(":") {
                            // 心跳或注释，跳过
                            continue
                        }

                        if trimmed.hasPrefix("data:") {
                            let dataPayload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
                            if dataPayload == "[DONE]" {
                                break
                            }

                            guard let payloadData = dataPayload.data(using: .utf8) else {
                                continue
                            }

                            if let chunkResponse = try? JSONDecoder().decode(OpenAIChatChunkResponse.self, from: payloadData) {
                                for choice in chunkResponse.choices {
                                    if let textDelta = choice.delta?.content, !textDelta.isEmpty {
                                        let chunk = LLMChunk(
                                            delta: textDelta,
                                            finishReason: choice.finishReason,
                                            usageEstimate: chunkResponse.usage?.totalTokens
                                        )
                                        continuation.yield(chunk)
                                    } else if let finishReason = choice.finishReason {
                                        let chunk = LLMChunk(
                                            delta: "",
                                            finishReason: finishReason,
                                            usageEstimate: chunkResponse.usage?.totalTokens
                                        )
                                        continuation.yield(chunk)
                                    }
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch let urlError as URLError {
                    if urlError.code == .cancelled {
                        continuation.finish(throwing: LLMProviderError.cancelled)
                    } else if urlError.code == .timedOut {
                        continuation.finish(throwing: LLMProviderError.timeout)
                    } else {
                        continuation.finish(throwing: LLMProviderError.networkError(urlError.localizedDescription))
                    }
                } catch is CancellationError {
                    continuation.finish(throwing: LLMProviderError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}

// MARK: - 私有请求与响应辅助数据结构 (OpenAI 协议格式)

private struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIChatCompletionRequest: Codable {
    let model: String
    let messages: [OpenAIChatMessage]
    let stream: Bool
    let temperature: Double
    let maxTokens: Int?
    let topP: Double?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case temperature
        case maxTokens = "max_tokens"
        case topP = "top_p"
    }
}

private struct OpenAIChatChunkResponse: Codable {
    let id: String?
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?

    struct OpenAIChoice: Codable {
        let index: Int?
        let delta: OpenAIDelta?
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case delta
            case finishReason = "finish_reason"
        }
    }

    struct OpenAIDelta: Codable {
        let role: String?
        let content: String?
    }

    struct OpenAIUsage: Codable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}
