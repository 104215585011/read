import XCTest
@testable import StudyOS

/// 契约与不变量测试套件 (UIREV-01, UIREV-03, UIREV-04, UIREV-06)
/// 严格依据 M0 验收矩阵 (ACCEPTANCE-MATRIX.md: R02, R03, R04, R09, R17) 与联调用例 (UI-INTEGRATION-CASES.md: UI-T03, UI-T05, UI-T07)
final class ContractTests: XCTestCase {

    // MARK: - 1. PageKey 唯一哈希与隔离测试 (UIREV-03)

    func testPageKeyHashAndEquality() {
        let key1 = PageKey(documentID: "doc_alpha", documentRevision: 1, pageIndex0: 0)
        let key2 = PageKey(documentID: "doc_alpha", documentRevision: 1, pageIndex0: 0)
        let keyDiffRev = PageKey(documentID: "doc_alpha", documentRevision: 2, pageIndex0: 0)
        let keyDiffPage = PageKey(documentID: "doc_alpha", documentRevision: 1, pageIndex0: 1)
        let keyDiffDoc = PageKey(documentID: "doc_beta", documentRevision: 1, pageIndex0: 0)

        // 相同三元组必须完全等价且哈希一致
        XCTAssertEqual(key1, key2)
        XCTAssertEqual(key1.hashValue, key2.hashValue)

        // 任一维度不同均不相等
        XCTAssertNotEqual(key1, keyDiffRev)
        XCTAssertNotEqual(key1, keyDiffPage)
        XCTAssertNotEqual(key1, keyDiffDoc)

        // 验证集合去重与字典键表现
        var set: Set<PageKey> = []
        set.insert(key1)
        set.insert(key2)
        set.insert(keyDiffRev)
        set.insert(keyDiffPage)
        set.insert(keyDiffDoc)
        XCTAssertEqual(set.count, 4)

        var dict: [PageKey: String] = [:]
        dict[key1] = "first"
        dict[key2] = "second"
        XCTAssertEqual(dict[key1], "second")
        XCTAssertEqual(dict.count, 1)
    }

    func testPageKeyStorageKeyFormat() {
        let key = PageKey(documentID: "doc_987", documentRevision: 3, pageIndex0: 42)
        XCTAssertEqual(key.storageKey, "doc_987_3_p42")
    }

    func testPageKeyCodableRoundTrip() throws {
        let originalKey = PageKey(documentID: "doc_test_codable", documentRevision: 5, pageIndex0: 12)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(originalKey)
        let decodedKey = try decoder.decode(PageKey.self, from: data)

        XCTAssertEqual(originalKey, decodedKey)
        XCTAssertEqual(originalKey.storageKey, decodedKey.storageKey)
    }

    // MARK: - 2. InkSaveSnapshot 排队前不可变固化测试 (UIREV-03)

    func testInkSaveSnapshotImmutabilityBeforeQueuing() {
        let key = PageKey(documentID: "doc_ink", documentRevision: 1, pageIndex0: 0)
        var sourceBlob = "StrokeData_Initial".data(using: .utf8)!
        let originalTransform = CodableTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 10.0, ty: 20.0)

        let snapshotID = "snap_fixed_001"
        let snapshot = InkSaveSnapshot(
            pageKey: key,
            readerSessionID: "sess_reader_001",
            snapshotID: snapshotID,
            drawingBlob: sourceBlob,
            canvasToPageTransform: originalTransform,
            expectedRevision: 0
        )

        // 验证快照创建时的字段完整性
        XCTAssertEqual(snapshot.pageKey, key)
        XCTAssertEqual(snapshot.readerSessionID, "sess_reader_001")
        XCTAssertEqual(snapshot.snapshotID, snapshotID)
        XCTAssertEqual(snapshot.drawingBlob, sourceBlob)
        XCTAssertEqual(snapshot.canvasToPageTransform.tx, 10.0)
        XCTAssertEqual(snapshot.expectedRevision, 0)

        // 模拟外部数据在入队后被修改 (例如用户又画了新一笔)
        sourceBlob.append("_AdditionalStroke".data(using: .utf8)!)

        // 验证已固化的快照不受外部数据变化影响 (不可变性保证)
        XCTAssertNotEqual(snapshot.drawingBlob, sourceBlob)
        XCTAssertEqual(
            snapshot.drawingBlob,
            "StrokeData_Initial".data(using: .utf8)!
        )
    }

    // MARK: - 3. InkSaveReceipt 版本递增与回执匹配 (UIREV-03)

    func testInkSaveReceiptRevisionProgression() throws {
        let key = PageKey(documentID: "doc_receipt", documentRevision: 1, pageIndex0: 3)
        let snapshotID = "snap_req_777"
        let sessionID = "sess_receipt_001"
        let initialRevision = 0
        let nextRevision = initialRevision + 1

        let receipt = InkSaveReceipt(
            pageKey: key,
            snapshotID: snapshotID,
            savedRevision: nextRevision,
            readerSessionID: sessionID
        )

        XCTAssertEqual(receipt.pageKey, key)
        XCTAssertEqual(receipt.snapshotID, snapshotID)
        XCTAssertEqual(receipt.savedRevision, 1)
        XCTAssertEqual(receipt.readerSessionID, sessionID)

        // 验证 Receipt Codable 序列化与反序列化
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(receipt)
        let decoded = try decoder.decode(InkSaveReceipt.self, from: data)

        XCTAssertEqual(receipt, decoded)
        XCTAssertEqual(receipt.savedRevision, decoded.savedRevision)
    }

    // MARK: - 4. ReaderToolMode 三态切换与编码测试 (UIREV-04)

    func testReaderToolModeTransitionsAndCodable() throws {
        let modes: [ReaderToolMode] = [.reading, .textSelection, .annotation]
        let rawValues = ["reading", "textSelection", "annotation"]

        for (index, mode) in modes.enumerated() {
            XCTAssertEqual(mode.rawValue, rawValues[index])
        }

        // 验证序列化
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for mode in modes {
            let data = try encoder.encode(mode)
            let decoded = try decoder.decode(ReaderToolMode.self, from: data)
            XCTAssertEqual(mode, decoded)
        }

        // 验证三态穷举分支行为
        func describe(mode: ReaderToolMode) -> String {
            switch mode {
            case .reading:
                return "Pencil writing / scrolling"
            case .textSelection:
                return "Precise text selection, ink suppressed"
            case .annotation:
                return "PKToolPicker active"
            }
        }

        XCTAssertEqual(describe(mode: .reading), "Pencil writing / scrolling")
        XCTAssertEqual(describe(mode: .textSelection), "Precise text selection, ink suppressed")
        XCTAssertEqual(describe(mode: .annotation), "PKToolPicker active")
    }

    // MARK: - 5. SaveInkError 结构化错误分型 (UIREV-03)

    func testSaveInkErrorCases() {
        let conflictError = SaveInkError.conflict(currentRevision: 4)
        let storageFullError = SaveInkError.storageFull
        let failedError = SaveInkError.saveFailed("IO error")
        let staleError = SaveInkError.staleReference
        let unavailError = SaveInkError.unavailable
        let timeoutError = SaveInkError.timeout
        let cancelledError = SaveInkError.cancelled

        XCTAssertEqual(conflictError, SaveInkError.conflict(currentRevision: 4))
        XCTAssertNotEqual(conflictError, SaveInkError.conflict(currentRevision: 5))
        XCTAssertNotEqual(conflictError, storageFullError)
        XCTAssertEqual(failedError, SaveInkError.saveFailed("IO error"))
        XCTAssertEqual(staleError, SaveInkError.staleReference)
        XCTAssertEqual(unavailError, SaveInkError.unavailable)
        XCTAssertEqual(timeoutError, SaveInkError.timeout)
        XCTAssertEqual(cancelledError, SaveInkError.cancelled)
    }

    // MARK: - 6. NotePolicy 策略契约 (UIREV-06)

    func testNotePolicyCasesAndCodable() throws {
        let keepPolicy = NotePolicy.keep
        let deletePolicy = NotePolicy.delete

        XCTAssertEqual(keepPolicy.rawValue, "keep")
        XCTAssertEqual(deletePolicy.rawValue, "delete")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let keepData = try encoder.encode(keepPolicy)
        let decodedKeep = try decoder.decode(NotePolicy.self, from: keepData)
        XCTAssertEqual(keepPolicy, decodedKeep)

        let deleteData = try encoder.encode(deletePolicy)
        let decodedDelete = try decoder.decode(NotePolicy.self, from: deleteData)
        XCTAssertEqual(deletePolicy, decodedDelete)
    }
}
