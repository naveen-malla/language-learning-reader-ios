import XCTest
@testable import LanguageReader

final class DocumentTests: XCTestCase {
    func testSourceTypeDefaultsToText() {
        let document = Document(title: "Title", body: "Body")
        XCTAssertEqual(document.sourceType, .text)
    }

    func testSourceTypeRoundTrip() {
        let document = Document(title: "Title", body: "Body", sourceType: .youtube)
        XCTAssertEqual(document.sourceTypeRaw, DocumentSourceType.youtube.rawValue)
        XCTAssertEqual(document.sourceType, .youtube)

        document.sourceType = .sample
        XCTAssertEqual(document.sourceTypeRaw, DocumentSourceType.sample.rawValue)
        XCTAssertEqual(document.sourceType, .sample)
    }

    func testSourceTypeFallsBackForUnknownRawValue() {
        let document = Document(title: "Title", body: "Body")
        document.sourceTypeRaw = "unknown"
        XCTAssertEqual(document.sourceType, .text)
    }

    func testIsOpenedReflectsFirstOpenedAt() {
        let document = Document(title: "Title", body: "Body")
        XCTAssertFalse(document.isOpened)

        document.firstOpenedAt = Date()
        XCTAssertTrue(document.isOpened)
    }
}
