import XCTest
import CryptoKit
@testable import StudyOS

// Actor-owned observations; no mutable global URLProtocol handlers or timing sleeps.
private actor RecordingProvider: LLMProviderProtocol {
    nonisolated let profileID = "regression-provider"
    nonisolated let snapshot = ProviderSnapshot(profileID: "regression-provider", endpoint: "https://fixture.invalid/v1", model: "fixture")
    private(set) var received: [[LLMMessage]] = []
    private let blockFirst: Bool
    private var entered = false
    private var entryWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?
    private var released = false

    init(blockFirst: Bool = false) { self.blockFirst = blockFirst }

    func streamCompletion(messages: [LLMMessage], options: LLMCompletionOptions) async throws -> AsyncThrowingStream<LLMChunk, Error> {
        received.append(messages)
        if blockFirst && received.count == 1 {
            entered = true
            entryWaiter?.resume()
            entryWaiter = nil
            if !released { await withCheckedContinuation { releaseWaiter = $0 } }
        }
        return AsyncThrowingStream { continuation in
            continuation.yield(LLMChunk(delta: "fixture response", finishReason: "stop"))
            continuation.finish()
        }
    }

    func waitUntilEntered() async {
        if !entered { await withCheckedContinuation { entryWaiter = $0 } }
    }

    func release() {
        released = true
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

// Each URL chooses immutable fixture bytes. No network or provider credentials are used.
private final class SSEFixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "fixture.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/event-stream"]) else { return }
        let body: String
        if url.path.contains("malformed") {
            body = "data: {broken-json}\n\ndata: [DONE]\n\n"
        } else if url.path.contains("truncated") {
            body = "data: {\"choices\":[{\"delta\":{\"content\":\"partial\"}}]}\n\n"
        } else {
            body = "data: {\"choices\":[{\"delta\":{\"content\":\"hello\"}}]}\n\ndata: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n"
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class M2RegressionTests: XCTestCase {
    private func request(scope: AIScope = .page(index0: 0)) -> AIRequest {
        AIRequest(documentID: "fixture-document", documentRevision: 1, scope: scope, mode: .ask, question: "Explain the fixture", providerProfileID: "regression-provider")
    }

    private func service(_ provider: RecordingProvider) async -> (AIService, URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("StudyOS-M2-\(UUID().uuidString)")
        let metadata = MetadataStorageEngine(sandbox: LocalSandboxManager(rootDirectoryURL: root))
        await metadata.saveDocument(Document(id: "fixture-document", title: "Fixture", sourceHash: "fixture", localFileRef: "fixture.pdf", pageCount: 3, importState: .readable))
        return (AIService(provider: provider, metadataEngine: metadata), root)
    }

    func testConfirmedPageContextActuallyReachesProvider() async throws {
        let provider = RecordingProvider()
        let (service, root) = await service(provider)
        defer { try? FileManager.default.removeItem(at: root) }
        let req = request()
        let context = ContextAggregator().buildContext(request: req, providerSnapshot: provider.snapshot, document: nil, pageTexts: [0: "PAGE_ZERO_SENTINEL", 1: "PRIVATE_OTHER_PAGE"])
        let stream = try await service.generateStream(request: req, context: context)
        for try await _ in stream {}
        let calls = await provider.received
        XCTAssertEqual(calls.count, 1)
        let text = calls.flatMap { $0 }.map(\.content).joined(separator: "\n")
        XCTAssertTrue(text.contains("PAGE_ZERO_SENTINEL"))
        XCTAssertFalse(text.contains("PRIVATE_OTHER_PAGE"))
    }

    func testConfirmedChapterIncludesBothBoundaryPages() async throws {
        let provider = RecordingProvider()
        let (service, root) = await service(provider)
        defer { try? FileManager.default.removeItem(at: root) }
        let req = request(scope: .chapter(chapterID: nil, startPageIndex0: 0, endPageIndex0: 1))
        let context = ContextAggregator().buildContext(request: req, providerSnapshot: provider.snapshot, document: nil, pageTexts: [0: "CHAPTER_START", 1: "CHAPTER_END", 2: "OUTSIDE_CHAPTER"])
        let stream = try await service.generateStream(request: req, context: context)
        for try await _ in stream {}
        let calls = await provider.received
        let text = calls.flatMap { $0 }.map(\.content).joined(separator: "\n")
        XCTAssertTrue(text.contains("CHAPTER_START"))
        XCTAssertTrue(text.contains("CHAPTER_END"))
        XCTAssertFalse(text.contains("OUTSIDE_CHAPTER"))
    }

    func testManifestOnlyCannotAuthorizeUnreconstructablePayload() async throws {
        let provider = RecordingProvider()
        let (service, root) = await service(provider)
        defer { try? FileManager.default.removeItem(at: root) }
        let req = request()
        let context = ContextAggregator().buildContext(request: req, providerSnapshot: provider.snapshot, document: nil, pageTexts: [0: "approved"])
        do {
            _ = try await service.generateStream(request: req, manifest: context.manifest)
            XCTFail("A manifest summary alone must not trigger a reconstructed, different request")
        } catch LLMProviderError.invalidResponse(_) { }
        let calls = await provider.received
        XCTAssertTrue(calls.isEmpty)
    }

    func testDigestHashesAllUTF8BytesNotOnlyPrefixAndLength() throws {
        let provider = RecordingProvider()
        let req = request()
        let a = "0123456789abcdefA中文"
        let b = "0123456789abcdefB中文"
        let first = ContextAggregator().buildContext(request: req, providerSnapshot: provider.snapshot, document: nil, pageTexts: [0: a])
        let second = ContextAggregator().buildContext(request: req, providerSnapshot: provider.snapshot, document: nil, pageTexts: [0: b])
        let digestA = try XCTUnwrap(first.manifest.outboundItems.first(where: { $0.kind == .documentText })?.payloadDigest)
        let digestB = try XCTUnwrap(second.manifest.outboundItems.first(where: { $0.kind == .documentText })?.payloadDigest)
        let expected = "sha256_" + SHA256.hash(data: Data(a.utf8)).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(digestA, expected)
        XCTAssertNotEqual(digestA, digestB)
    }

    func testDuplicateAttemptRejectedWhileFirstProviderHandshakeSuspends() async throws {
        let provider = RecordingProvider(blockFirst: true)
        let (service, root) = await service(provider)
        defer { try? FileManager.default.removeItem(at: root) }
        let req = request()
        let context = ContextAggregator().buildContext(request: req, providerSnapshot: provider.snapshot, document: nil, pageTexts: [0: "fixture"])
        let first = Task {
            let stream = try await service.generateStream(request: req, context: context)
            for try await _ in stream {}
        }
        await provider.waitUntilEntered()
        do {
            _ = try await service.generateStream(request: req, context: context)
            XCTFail("Duplicate attempt must be reserved before the first await")
        } catch LLMProviderError.invalidResponse(_) { }
        await provider.release()
        try await first.value
        let calls = await provider.received
        XCTAssertEqual(calls.count, 1)
    }

    private func consumeSSE(_ fixture: String) async throws -> String {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SSEFixtureProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let provider = OpenAICompatibleProvider(baseURL: try XCTUnwrap(URL(string: "https://fixture.invalid/\(fixture)")), apiKey: "fixture-key", urlSession: session)
        let stream = try await provider.streamCompletion(messages: [LLMMessage(role: .user, content: "fixture")], options: LLMCompletionOptions())
        var text = ""
        for try await chunk in stream { text += chunk.delta }
        return text
    }

    func testValidSSECompletesWithActualDelta() async throws {
        let text = try await consumeSSE("valid")
        XCTAssertEqual(text, "hello")
    }

    func testMalformedSSEIsFailureEvenIfDoneFollows() async throws {
        do { _ = try await consumeSSE("malformed"); XCTFail("Malformed data must not be silently ignored") }
        catch LLMProviderError.invalidResponse(_) { }
    }

    func testTruncatedSSEWithoutTerminalMarkerIsFailure() async throws {
        do { _ = try await consumeSSE("truncated"); XCTFail("EOF after partial delta must not be completed") }
        catch LLMProviderError.invalidResponse(_) { }
    }
}
