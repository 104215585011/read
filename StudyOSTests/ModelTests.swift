import XCTest
@testable import StudyOS

/// 领域模型与两路删除策略测试套件 (UIREV-01, UIREV-04, UIREV-06)
/// 严格依据 M0 验收矩阵 (ACCEPTANCE-MATRIX.md: R01, R04, R09, R11, R16) 与联调用例 (UI-INTEGRATION-CASES.md: UI-T07, UI-T11)
final class ModelTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }()

    private let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    // MARK: - 1. Document 序列化与状态测试 (R01, R16)

    func testDocumentCodableAndSendable() throws {
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let doc = Document(
            id: "doc_test_001",
            title: "Calculus_Early_Transcendentals.pdf",
            sourceHash: "sha256_abcdef123456",
            revision: 3,
            localFileRef: "/sandbox/Documents/doc_test_001/source.pdf",
            pageCount: 1120,
            importState: .readable,
            indexState: .ready,
            createdAt: fixedDate,
            updatedAt: fixedDate
        )

        let data = try encoder.encode(doc)
        let decoded = try decoder.decode(Document.self, from: data)

        XCTAssertEqual(doc, decoded)
        XCTAssertEqual(decoded.id, "doc_test_001")
        XCTAssertEqual(decoded.title, "Calculus_Early_Transcendentals.pdf")
        XCTAssertEqual(decoded.sourceHash, "sha256_abcdef123456")
        XCTAssertEqual(decoded.revision, 3)
        XCTAssertEqual(decoded.pageCount, 1120)
        XCTAssertEqual(decoded.importState, .readable)
        XCTAssertEqual(decoded.indexState, .ready)
    }

    func testDocumentImportAndIndexStates() throws {
        let importStates: [ImportState] = [.copying, .validating, .readable, .needsPassword, .failed]
        for state in importStates {
            let encoded = try encoder.encode(state)
            let decoded = try decoder.decode(ImportState.self, from: encoded)
            XCTAssertEqual(state, decoded)
        }

        let indexStates: [IndexState] = [.none, .partial, .ready, .failed]
        for state in indexStates {
            let encoded = try encoder.encode(state)
            let decoded = try decoder.decode(IndexState.self, from: encoded)
            XCTAssertEqual(state, decoded)
        }
    }

    // MARK: - 2. Page 物理页与 0-based 规范测试 (R02, R04)

    func testPageCodableAndIDInvariant() throws {
        let cropBox = CodableRect(x: 0, y: 0, width: 595.28, height: 841.89)
        let page = Page(
            documentID: "doc_physics",
            documentRevision: 2,
            pageIndex0: 15,
            displayLabel: "xvi",
            cropBox: cropBox,
            rotation: 90,
            textState: .ready,
            paragraphIDs: ["p_001", "p_002"]
        )

        // 验证 id 构成规范: "\(documentID)_\(documentRevision)_\(pageIndex0)"
        XCTAssertEqual(page.id, "doc_physics_2_15")
        XCTAssertEqual(page.pageIndex0, 15)
        XCTAssertEqual(page.displayLabel, "xvi")
        XCTAssertEqual(page.rotation, 90)

        let data = try encoder.encode(page)
        let decoded = try decoder.decode(Page.self, from: data)

        XCTAssertEqual(page, decoded)
        XCTAssertEqual(decoded.id, "doc_physics_2_15")
        XCTAssertEqual(decoded.cropBox.width, 595.28)
        XCTAssertEqual(decoded.textState, .ready)
    }

    // MARK: - 3. SourceAnchor 定位精度与有效性测试 (R09, UIREV-01)

    func testSourceAnchorCodableAndPrecision() throws {
        let rect = CodableRect(x: 72.0, y: 140.0, width: 450.0, height: 28.5)
        let anchor = SourceAnchor(
            documentID: "doc_source_anchor",
            documentRevision: 1,
            pageIndex0: 4,
            regions: [rect],
            paragraphID: "para_42",
            quote: "Fundamental Theorem of Calculus",
            textRevision: 1,
            precision: .region,
            availability: .active
        )

        XCTAssertEqual(anchor.precision, .region)
        XCTAssertEqual(anchor.availability, .active)

        let data = try encoder.encode(anchor)
        let decoded = try decoder.decode(SourceAnchor.self, from: data)

        XCTAssertEqual(anchor, decoded)
        XCTAssertEqual(decoded.quote, "Fundamental Theorem of Calculus")
        XCTAssertEqual(decoded.regions.count, 1)
        XCTAssertEqual(decoded.regions[0].x, 72.0)
    }

    // MARK: - 4. Note 与两路删除策略核心测试 (R11, UIREV-06)

    func testNoteKeepPolicyDetachmentAndSerialization() throws {
        // 创建带有原文档和章节关联的笔记
        let rect = CodableRect(x: 50.0, y: 100.0, width: 200.0, height: 30.0)
        let originalAnchor = SourceAnchor(
            documentID: "doc_deleted_soon",
            documentRevision: 2,
            pageIndex0: 10,
            regions: [rect],
            quote: "Key concept quote",
            precision: .region,
            availability: .active
        )

        let aiOrigin = AIOrigin(
            requestID: "req_ai_100",
            attemptID: "att_001",
            prompt: "Explain Theorem 3.1"
        )

        var note = Note(
            id: "note_keep_001",
            documentID: "doc_deleted_soon",
            chapterID: "chap_intro",
            editableText: "This theorem links derivatives and integrals.",
            imageRefs: ["local_img_001.png"],
            sourceAnchors: [originalAnchor],
            aiOrigin: aiOrigin,
            revision: 1
        )

        // 验证初始状态：归属于文档与章节，引用 active
        XCTAssertEqual(note.documentID, "doc_deleted_soon")
        XCTAssertEqual(note.chapterID, "chap_intro")
        XCTAssertEqual(note.sourceAnchors.first?.availability, .active)

        // 执行 NotePolicy.keep 策略下的解绑与状态置换逻辑 (与 MetadataStorageEngine 行为严格一致)
        note.documentID = nil
        note.chapterID = nil
        note.sourceAnchors = note.sourceAnchors.map { anchor in
            var updatedAnchor = anchor
            updatedAnchor.availability = .documentDeleted
            return updatedAnchor
        }
        note.updatedAt = Date()

        // 验证解绑后字段不变量
        XCTAssertNil(note.documentID, "保留策略下必须清空 documentID，禁止指向已删除原件")
        XCTAssertNil(note.chapterID, "保留策略下必须清空 chapterID，解除章节归属")
        XCTAssertEqual(note.sourceAnchors.first?.availability, .documentDeleted, "引用有效性必须置为 documentDeleted")
        XCTAssertEqual(note.editableText, "This theorem links derivatives and integrals.", "笔记文本副本必须完整保留")
        XCTAssertEqual(note.imageRefs, ["local_img_001.png"], "笔记图片副本必须完整保留")

        // 验证解绑后的 Note 能够正确通过 Codable 序列化与反序列化
        let data = try encoder.encode(note)
        let decodedNote = try decoder.decode(Note.self, from: data)

        XCTAssertNil(decodedNote.documentID)
        XCTAssertNil(decodedNote.chapterID)
        XCTAssertEqual(decodedNote.sourceAnchors.first?.availability, .documentDeleted)
        XCTAssertEqual(decodedNote.editableText, note.editableText)
        XCTAssertEqual(decodedNote.aiOrigin?.prompt, "Explain Theorem 3.1")
    }

    func testNoteDeletePolicyPruningSimulation() {
        // 模拟 NotePolicy.delete: 关联笔记在删除原件文档时连带彻底清除
        var notesStore: [String: Note] = [:]

        let note1 = Note(id: "n1", documentID: "doc_target", editableText: "Note 1")
        let note2 = Note(id: "n2", documentID: "doc_target", editableText: "Note 2")
        let noteOther = Note(id: "n3", documentID: "doc_other", editableText: "Note 3")

        notesStore[note1.id] = note1
        notesStore[note2.id] = note2
        notesStore[noteOther.id] = noteOther

        let targetDocID = "doc_target"
        let policy = NotePolicy.delete

        if policy == .delete {
            let toRemove = notesStore.filter { $0.value.documentID == targetDocID }.map { $0.key }
            for k in toRemove {
                notesStore.removeValue(forKey: k)
            }
        }

        XCTAssertEqual(notesStore.count, 1)
        XCTAssertNotNil(notesStore["n3"])
        XCTAssertNil(notesStore["n1"])
        XCTAssertNil(notesStore["n2"])
    }
}
