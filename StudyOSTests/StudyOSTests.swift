import XCTest
@testable import StudyOS

final class StudyOSTests: XCTestCase {
    func testVersionInfo() {
        XCTAssertEqual(StudyOSInfo.contractRevision, "0.1-draft/M0-BE-REV2")
    }

    func testPageKeyHashable() {
        let key1 = PageKey(documentID: "doc_1", documentRevision: 1, pageIndex0: 0)
        let key2 = PageKey(documentID: "doc_1", documentRevision: 1, pageIndex0: 0)
        XCTAssertEqual(key1, key2)
        XCTAssertEqual(key1.storageKey, "doc_1_1_p0")
    }
}
