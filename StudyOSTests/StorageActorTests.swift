import XCTest
@testable import StudyOS

/// 存储引擎 Actor 隔离与并发版本控制测试套件 (UIREV-03)
/// 严格依据 M0 验收矩阵 (ACCEPTANCE-MATRIX.md: R03, R17) 与联调用例 (UI-INTEGRATION-CASES.md: UI-T05)
final class StorageActorTests: XCTestCase {

    private var tempDirectoryURL: URL!
    private var sandbox: LocalSandboxManager!
    private var indexManager: PageKeyIndexManager!
    private var inkStorageEngine: InkStorageEngine!

    override func setUp() async throws {
        try await super.setUp()
        // 使用独立的临时目录测试，保证测试隔离性与可重复性
        let tempBase = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("StudyOSTests_\(UUID().uuidString)", isDirectory: true)
        self.tempDirectoryURL = tempBase
        self.sandbox = LocalSandboxManager(rootDirectoryURL: tempBase)
        self.indexManager = PageKeyIndexManager()
        self.inkStorageEngine = InkStorageEngine(sandbox: sandbox, indexManager: indexManager)
    }

    override func tearDown() async throws {
        if let temp = tempDirectoryURL {
            try? FileManager.default.removeItem(at: temp)
        }
        try await super.tearDown()
    }

    // MARK: - 1. 并发多页面墨水保存测试 (Actor 隔离无竞态)

    func testConcurrentInkSavingAcrossPages() async throws {
        let docID = "doc_concurrent"
        let revision = 1
        let pageCount = 5

        // 并发触发 5 个不同页面的笔迹保存
        let results = await withTaskGroup(
            of: (Int, Result<InkSaveReceipt, SaveInkError>).self,
            returning: [Int: Result<InkSaveReceipt, SaveInkError>].self
        ) { group in
            for p in 0..<pageCount {
                let key = PageKey(documentID: docID, documentRevision: revision, pageIndex0: p)
                let snapshot = InkSaveSnapshot(
                    pageKey: key,
                    readerSessionID: "sess_concurrent",
                    snapshotID: "snap_p\(p)",
                    drawingBlob: "StrokeBlob_Page_\(p)".data(using: .utf8)!,
                    expectedRevision: 0
                )

                group.addTask {
                    let res = await self.inkStorageEngine.saveInk(snapshot: snapshot)
                    return (p, res)
                }
            }

            var dict: [Int: Result<InkSaveReceipt, SaveInkError>] = [:]
            for await (pageIdx, res) in group {
                dict[pageIdx] = res
            }
            return dict
        }

        XCTAssertEqual(results.count, pageCount)

        // 验证每一页均成功保存，初始版本均递增至 1
        for p in 0..<pageCount {
            guard let res = results[p] else {
                XCTFail("Missing result for page \(p)")
                continue
            }
            switch res {
            case .success(let receipt):
                XCTAssertEqual(receipt.savedRevision, 1)
                XCTAssertEqual(receipt.pageKey.pageIndex0, p)
            case .failure(let error):
                XCTFail("Unexpected failure on page \(p): \(error)")
            }

            // 验证从持久化引擎读取墨水
            let key = PageKey(documentID: docID, documentRevision: revision, pageIndex0: p)
            let loaded = await inkStorageEngine.loadInkPage(pageKey: key)
            XCTAssertNotNil(loaded)
            XCTAssertEqual(loaded?.drawingRevision, 1)

            let blob = await inkStorageEngine.loadDrawingBlob(pageKey: key)
            XCTAssertEqual(blob, "StrokeBlob_Page_\(p)".data(using: .utf8)!)
        }
    }

    // MARK: - 2. 连续笔画顺序提交与版本推进测试 (UI-T05)

    func testSequentialRapidStrokesProgression() async throws {
        let key = PageKey(documentID: "doc_rapid", documentRevision: 1, pageIndex0: 0)

        // 笔画 1：从版本 0 推进至 1
        let snap1 = InkSaveSnapshot(
            pageKey: key,
            readerSessionID: "sess_rapid",
            snapshotID: "snap_1",
            drawingBlob: "Stroke_1".data(using: .utf8)!,
            expectedRevision: 0
        )
        let res1 = await inkStorageEngine.saveInk(snapshot: snap1)
        guard case .success(let receipt1) = res1 else {
            XCTFail("Stroke 1 save failed")
            return
        }
        XCTAssertEqual(receipt1.savedRevision, 1)

        // 笔画 2：从版本 1 推进至 2
        let snap2 = InkSaveSnapshot(
            pageKey: key,
            readerSessionID: "sess_rapid",
            snapshotID: "snap_2",
            drawingBlob: "Stroke_1_2".data(using: .utf8)!,
            expectedRevision: 1
        )
        let res2 = await inkStorageEngine.saveInk(snapshot: snap2)
        guard case .success(let receipt2) = res2 else {
            XCTFail("Stroke 2 save failed")
            return
        }
        XCTAssertEqual(receipt2.savedRevision, 2)

        // 笔画 3：从版本 2 推进至 3
        let snap3 = InkSaveSnapshot(
            pageKey: key,
            readerSessionID: "sess_rapid",
            snapshotID: "snap_3",
            drawingBlob: "Stroke_1_2_3".data(using: .utf8)!,
            expectedRevision: 2
        )
        let res3 = await inkStorageEngine.saveInk(snapshot: snap3)
        guard case .success(let receipt3) = res3 else {
            XCTFail("Stroke 3 save failed")
            return
        }
        XCTAssertEqual(receipt3.savedRevision, 3)

        // 验证最终读取的内容为最新版本 3
        let latestInk = await inkStorageEngine.loadInkPage(pageKey: key)
        XCTAssertEqual(latestInk?.drawingRevision, 3)

        let latestBlob = await inkStorageEngine.loadDrawingBlob(pageKey: key)
        XCTAssertEqual(latestBlob, "Stroke_1_2_3".data(using: .utf8)!)
    }

    // MARK: - 3. expectedRevision 版本冲突检测 (UIREV-03, UI-T05)

    func testExpectedRevisionConflictDetection() async throws {
        let key = PageKey(documentID: "doc_conflict", documentRevision: 1, pageIndex0: 2)

        // 初始保存版本 0 -> 1
        let snapInitial = InkSaveSnapshot(
            pageKey: key,
            readerSessionID: "sess_1",
            snapshotID: "snap_init",
            drawingBlob: "BaseStroke".data(using: .utf8)!,
            expectedRevision: 0
        )
        let resInitial = await inkStorageEngine.saveInk(snapshot: snapInitial)
        guard case .success(let receipt) = resInitial else {
            XCTFail("Initial save failed")
            return
        }
        XCTAssertEqual(receipt.savedRevision, 1)

        // 模拟迟到或过期的快照，其 expectedRevision 仍为 0 (已落后于当前的 1)
        let staleSnapshot = InkSaveSnapshot(
            pageKey: key,
            readerSessionID: "sess_1",
            snapshotID: "snap_stale",
            drawingBlob: "StaleStroke".data(using: .utf8)!,
            expectedRevision: 0
        )
        let staleResult = await inkStorageEngine.saveInk(snapshot: staleSnapshot)

        // 必须拒绝保存并返回 SaveInkError.conflict(currentRevision: 1)
        switch staleResult {
        case .failure(let error):
            XCTAssertEqual(error, SaveInkError.conflict(currentRevision: 1), "版本不一致时必须检测并返回 conflict 错误")
        case .success:
            XCTFail("Stale snapshot should have failed with conflict error")
        }

        // 验证底层持久化内容未被旧快照篡改
        let currentBlob = await inkStorageEngine.loadDrawingBlob(pageKey: key)
        XCTAssertEqual(currentBlob, "BaseStroke".data(using: .utf8)!)

        let currentRev = await indexManager.getPersistedRevision(for: key)
        XCTAssertEqual(currentRev, 1)
    }

    // MARK: - 4. 墨水清理与删除验证 (UIREV-06)

    func testRemoveInksDeletesFilesAndIndex() async throws {
        let key = PageKey(documentID: "doc_cleanup", documentRevision: 1, pageIndex0: 0)
        let snap = InkSaveSnapshot(
            pageKey: key,
            readerSessionID: "sess_cleanup",
            snapshotID: "snap_del",
            drawingBlob: "BlobToDelete".data(using: .utf8)!,
            expectedRevision: 0
        )
        _ = await inkStorageEngine.saveInk(snapshot: snap)

        // 确认已写入
        let beforeCleanup = await inkStorageEngine.loadInkPage(pageKey: key)
        XCTAssertNotNil(beforeCleanup)

        // 执行删除
        await inkStorageEngine.removeInks(documentID: "doc_cleanup", documentRevision: 1)

        // 验证索引与文件已被清理
        let afterCleanup = await inkStorageEngine.loadInkPage(pageKey: key)
        XCTAssertNil(afterCleanup, "删除后 loadInkPage 必须返回 nil")

        let blobAfter = await inkStorageEngine.loadDrawingBlob(pageKey: key)
        XCTAssertNil(blobAfter)
    }
}
