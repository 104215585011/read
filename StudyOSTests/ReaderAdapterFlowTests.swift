import XCTest
@testable import StudyOS

/// 模拟核心服务桩，用于隔离测试 ReaderAdapter 交互逻辑
final class MockCoreServiceForAdapter: CoreServiceProtocol, @unchecked Sendable {
    var resolveSourceHandler: (@Sendable (SourceAnchor) async -> SourceResolution)?
    var flushInkHandler: (@Sendable (InkSaveSnapshot) async -> Result<InkSaveReceipt, SaveInkError>)?
    var savePositionHandler: (@Sendable (ReadingPosition) async throws -> Bool)?

    var documentService: DocumentServiceProtocol {
        fatalError("DocumentService not accessed in ReaderAdapter unit tests")
    }

    var readerCoreService: ReaderCoreServiceProtocol {
        fatalError("ReaderCoreService not accessed directly in ReaderAdapter unit tests")
    }

    var noteService: NoteServiceProtocol {
        fatalError("NoteService not accessed in ReaderAdapter unit tests")
    }

    var aiService: AIServiceProtocol {
        fatalError("AIService not accessed in ReaderAdapter unit tests")
    }

    var batchExtractionEngine: BatchExtractionProtocol {
        fatalError("BatchExtractionEngine not accessed in ReaderAdapter unit tests")
    }

    var aiNoteService: AINoteServiceProtocol {
        fatalError("AINoteService not accessed in ReaderAdapter unit tests")
    }

    var localLLMProvider: LocalLLMProviderProtocol? {
        nil
    }

    var fullDocumentStudyService: FullDocumentStudyProtocol {
        fatalError("FullDocumentStudyService not accessed in ReaderAdapter unit tests")
    }

    var offlineResourceManager: OfflineResourceManagerProtocol {
        fatalError("OfflineResourceManager not accessed in ReaderAdapter unit tests")
    }

    var networkRetryEngine: NetworkResilienceRetryEngineProtocol {
        fatalError("NetworkRetryEngine not accessed in ReaderAdapter unit tests")
    }

    var localModelPackageManager: LocalModelPackageManagerProtocol? {
        nil
    }

    func resolveSource(_ anchor: SourceAnchor) async -> SourceResolution {
        if let handler = resolveSourceHandler {
            return await handler(anchor)
        }
        return .unavailable
    }

    func flushInk(snapshot: InkSaveSnapshot) async -> Result<InkSaveReceipt, SaveInkError> {
        if let handler = flushInkHandler {
            return await handler(snapshot)
        }
        return .failure(.unavailable)
    }

    func savePosition(_ position: ReadingPosition) async throws -> Bool {
        if let handler = savePositionHandler {
            return try await handler(position)
        }
        return true
    }
}

/// ReaderAdapter 流程与跨会话核对测试套件 (UIREV-01, UIREV-03, UIREV-04)
/// 严格依据 M0 验收矩阵 (ACCEPTANCE-MATRIX.md: R02, R03, R09) 与联调用例 (UI-INTEGRATION-CASES.md: UI-T01, UI-T04, UI-T05, UI-T07)
final class ReaderAdapterFlowTests: XCTestCase {

    // MARK: - 1. 跨文档/会话隔离测试 (ignoredStaleSession, UIREV-04, UI-T07)

    @MainActor
    func testIgnoredStaleSessionWhenTargetDocumentDiffers() async {
        let mock = MockCoreServiceForAdapter()
        let currentDocID = "doc_active_session"
        let currentRevision = 2

        let adapter = ReaderAdapter(
            readerSessionID: "sess_main_001",
            documentID: currentDocID,
            documentRevision: currentRevision,
            initialPageIndex0: 0,
            pageCount: 10,
            coreService: mock
        )

        // 模拟核心服务返回了另一个文档的目标 (例如并发延迟返回了先前文档的解析结果)
        mock.resolveSourceHandler = { anchor in
            let otherTarget = NavigationTarget(
                documentID: "doc_other_legacy",
                documentRevision: 1,
                pageIndex0: 5,
                regions: [CodableRect(x: 10, y: 10, width: 100, height: 20)],
                precision: .region,
                resolvedFromAnchor: anchor
            )
            return .navigationTarget(otherTarget)
        }

        let testAnchor = SourceAnchor(
            documentID: "doc_other_legacy",
            documentRevision: 1,
            pageIndex0: 5
        )

        // 执行导航并验证：必须检测到文档不匹配并返回 .ignoredStaleSession，绝不乱跳
        let result = await adapter.navigateTo(source: testAnchor)
        XCTAssertEqual(result, .ignoredStaleSession, "目标文档 ID 或版本与当前会话不符时必须忽略并返回 .ignoredStaleSession")
        XCTAssertEqual(adapter.currentPageIndex0, 0, "当前页面索引必须保持不变，严禁乱跳")
    }

    @MainActor
    func testIgnoredStaleSessionWhenDocumentRevisionDiffers() async {
        let mock = MockCoreServiceForAdapter()
        let currentDocID = "doc_version_check"

        let adapter = ReaderAdapter(
            readerSessionID: "sess_rev_001",
            documentID: currentDocID,
            documentRevision: 3, // 当前为第 3 版
            initialPageIndex0: 1,
            pageCount: 20,
            coreService: mock
        )

        // 目标属于同一文档，但版本为旧版本 2
        mock.resolveSourceHandler = { anchor in
            let staleRevTarget = NavigationTarget(
                documentID: currentDocID,
                documentRevision: 2, // 旧版本
                pageIndex0: 8,
                regions: [],
                precision: .page,
                resolvedFromAnchor: anchor
            )
            return .navigationTarget(staleRevTarget)
        }

        let anchor = SourceAnchor(
            documentID: currentDocID,
            documentRevision: 2,
            pageIndex0: 8
        )

        let result = await adapter.navigateTo(source: anchor)
        XCTAssertEqual(result, .ignoredStaleSession, "跨版本目标必须被识别为过期会话并丢弃")
        XCTAssertEqual(adapter.currentPageIndex0, 1)
    }

    // MARK: - 2. 旧版本来源与失效来源拦截测试 (UIREV-01, UI-T07)

    @MainActor
    func testStaleReferenceHandling() async {
        let mock = MockCoreServiceForAdapter()
        var receivedToast: String?

        let adapter = ReaderAdapter(
            readerSessionID: "sess_stale_ref",
            documentID: "doc_current",
            documentRevision: 2,
            initialPageIndex0: 0,
            pageCount: 15,
            coreService: mock
        )
        adapter.onToastMessage = { msg in
            receivedToast = msg
        }

        mock.resolveSourceHandler = { _ in
            return .staleReference
        }

        let anchor = SourceAnchor(
            documentID: "doc_current",
            documentRevision: 1, // 旧版本锚点
            pageIndex0: 3
        )

        let result = await adapter.navigateTo(source: anchor)
        XCTAssertEqual(result, .staleReference)
        XCTAssertNotNil(receivedToast)
        XCTAssertTrue(receivedToast?.contains("旧版本") == true)
        XCTAssertEqual(adapter.currentPageIndex0, 0)
    }

    @MainActor
    func testUnavailableHandlingForDeletedDocument() async {
        let mock = MockCoreServiceForAdapter()
        var receivedToast: String?

        let adapter = ReaderAdapter(
            readerSessionID: "sess_unavail",
            documentID: "doc_test",
            documentRevision: 1,
            initialPageIndex0: 0,
            pageCount: 5,
            coreService: mock
        )
        adapter.onToastMessage = { msg in
            receivedToast = msg
        }

        mock.resolveSourceHandler = { _ in
            return .unavailable
        }

        let anchor = SourceAnchor(
            documentID: "doc_test",
            documentRevision: 1,
            pageIndex0: 2,
            availability: .documentDeleted
        )

        let result = await adapter.navigateTo(source: anchor)
        XCTAssertEqual(result, .unavailable)
        XCTAssertNotNil(receivedToast)
        XCTAssertTrue(receivedToast?.contains("失效") == true || receivedToast?.contains("删除") == true)
        XCTAssertEqual(adapter.currentPageIndex0, 0)
    }

    // MARK: - 3. 墨水保存会话隔离测试 (UIREV-03, UI-T05)

    @MainActor
    func testInkFlushMismatchedSessionRejection() async {
        let mock = MockCoreServiceForAdapter()
        let adapter = ReaderAdapter(
            readerSessionID: "sess_active_001",
            documentID: "doc_sess",
            documentRevision: 1,
            initialPageIndex0: 0,
            pageCount: 10,
            coreService: mock
        )

        let key = PageKey(documentID: "doc_sess", documentRevision: 1, pageIndex0: 0)

        // 提交带有过期会话 ID 的快照 (例如在后台切会话后迟到的提交)
        let staleSnapshot = InkSaveSnapshot(
            pageKey: key,
            readerSessionID: "sess_old_stale_999", // 会话 ID 不符
            snapshotID: "snap_stale_sess",
            drawingBlob: "StaleBlob".data(using: .utf8)!,
            expectedRevision: 0
        )

        let result = await adapter.flushInk(snapshot: staleSnapshot)

        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .staleReference, "会话 ID 不符的笔迹快照必须直接拒绝保存并返回 staleReference")
        case .success:
            XCTFail("Stale session snapshot must not be saved")
        }
    }

    // MARK: - 4. 工具态管理与切换测试 (UIREV-04)

    @MainActor
    func testToolModeTransitions() {
        let mock = MockCoreServiceForAdapter()
        let adapter = ReaderAdapter(
            readerSessionID: "sess_tool",
            documentID: "doc_tool",
            documentRevision: 1,
            initialPageIndex0: 0,
            pageCount: 5,
            coreService: mock
        )

        XCTAssertEqual(adapter.currentToolMode, .reading)

        adapter.setToolMode(.textSelection)
        XCTAssertEqual(adapter.currentToolMode, .textSelection)

        adapter.setToolMode(.annotation)
        XCTAssertEqual(adapter.currentToolMode, .annotation)

        adapter.setToolMode(.reading)
        XCTAssertEqual(adapter.currentToolMode, .reading)
    }

    // MARK: - 5. 页面导航边界与选区管理测试 (UIREV-01, UI-T03)

    @MainActor
    func testGoToPageBoundaryChecks() {
        let mock = MockCoreServiceForAdapter()
        var lastChangedPage: Int?
        var toastMessage: String?

        let adapter = ReaderAdapter(
            readerSessionID: "sess_page",
            documentID: "doc_page",
            documentRevision: 1,
            initialPageIndex0: 0,
            pageCount: 10,
            coreService: mock
        )
        adapter.onPageChanged = { page in
            lastChangedPage = page
        }
        adapter.onToastMessage = { msg in
            toastMessage = msg
        }

        // 合法跳转
        let success = adapter.goToPage(index0: 5)
        XCTAssertTrue(success)
        XCTAssertEqual(adapter.currentPageIndex0, 5)
        XCTAssertEqual(lastChangedPage, 5)

        // 越界负数跳转
        let negSuccess = adapter.goToPage(index0: -1)
        XCTAssertFalse(negSuccess)
        XCTAssertEqual(adapter.currentPageIndex0, 5, "非法跳转不得修改当前页面")
        XCTAssertNotNil(toastMessage)

        // 越界超出 pageCount 跳转
        toastMessage = nil
        let overflowSuccess = adapter.goToPage(index0: 10) // 有效范围是 0..<10
        XCTAssertFalse(overflowSuccess)
        XCTAssertEqual(adapter.currentPageIndex0, 5)
        XCTAssertNotNil(toastMessage)
    }

    @MainActor
    func testSelectionLifecycle() {
        let mock = MockCoreServiceForAdapter()
        var reportedAnchor: SourceAnchor?
        var reportedRect: CGRect?

        let adapter = ReaderAdapter(
            readerSessionID: "sess_select",
            documentID: "doc_sel",
            documentRevision: 1,
            initialPageIndex0: 0,
            pageCount: 5,
            coreService: mock
        )
        adapter.onSelectionChanged = { anchor, rect in
            reportedAnchor = anchor
            reportedRect = rect
        }

        let anchor = SourceAnchor(
            documentID: "doc_sel",
            documentRevision: 1,
            pageIndex0: 2,
            quote: "Selected text"
        )
        let rect = CGRect(x: 20, y: 30, width: 100, height: 15)

        adapter.updateSelection(anchor: anchor, screenRect: rect)
        XCTAssertEqual(adapter.currentSelectionAnchor, anchor)
        XCTAssertEqual(reportedAnchor, anchor)
        XCTAssertEqual(reportedRect, rect)

        // 清除选区
        adapter.clearCurrentSelection()
        XCTAssertNil(adapter.currentSelectionAnchor)
        XCTAssertNil(reportedAnchor)
        XCTAssertNil(reportedRect)
    }
}
