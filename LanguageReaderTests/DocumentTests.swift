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

    func testImportModeRoundTrip() {
        let document = Document(
            title: "Title",
            body: "Body",
            importMode: .smartPack
        )

        XCTAssertEqual(document.importModeRaw, DocumentImportMode.smartPack.rawValue)
        XCTAssertEqual(document.importMode, .smartPack)

        document.importMode = .autoTopUp
        XCTAssertEqual(document.importModeRaw, DocumentImportMode.autoTopUp.rawValue)
        XCTAssertEqual(document.importMode, .autoTopUp)
    }

    func testImportModeFallsBackForUnknownRawValue() {
        let document = Document(title: "Title", body: "Body")
        document.importModeRaw = "unknown"
        XCTAssertNil(document.importMode)
    }

    func testNewMetadataFieldsDefaultToNil() {
        let document = Document(title: "Title", body: "Body")
        XCTAssertNil(document.sourceChannelID)
        XCTAssertNil(document.importModeRaw)
        XCTAssertNil(document.autoBatchID)
    }
}
