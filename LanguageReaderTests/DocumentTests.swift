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
        XCTAssertTrue(document.subtitleCues.isEmpty)
        XCTAssertNil(document.translatedSubtitleCues)
        XCTAssertNil(document.importModeRaw)
        XCTAssertNil(document.autoBatchID)
    }

    func testSubtitleCueRoundTrip() {
        let document = Document(title: "Title", body: "Body")
        document.subtitleCues = [
            TimedSubtitleCue(startTime: 1.25, duration: 2.5, sourceText: "ಮೊದಲ ಸಾಲು"),
            TimedSubtitleCue(startTime: 4.0, duration: 1.4, sourceText: "ಎರಡನೇ ಸಾಲು")
        ]
        document.translatedSubtitleCues = [
            TranslatedSubtitleCue(startTime: 1.25, duration: 2.5, translatedText: "First line")
        ]

        XCTAssertEqual(document.subtitleCues.count, 2)
        XCTAssertEqual(document.subtitleCues.first?.sourceText, "ಮೊದಲ ಸಾಲು")
        XCTAssertEqual(document.translatedSubtitleCues?.first?.translatedText, "First line")
    }

    func testSubtitleCueAccessorsFallbackOnCorruptRawValues() {
        let document = Document(title: "Title", body: "Body")
        document.subtitleCuesRaw = "{invalid json"
        document.translatedSubtitleCuesRaw = "{invalid json"

        XCTAssertTrue(document.subtitleCues.isEmpty)
        XCTAssertNil(document.translatedSubtitleCues)
    }

    func testSubtitleCueAccessorsClearRawStorageWhenSetEmpty() {
        let document = Document(title: "Title", body: "Body")
        document.subtitleCues = [
            TimedSubtitleCue(startTime: 0.5, duration: 1.0, sourceText: "ಸಾಲು")
        ]
        document.translatedSubtitleCues = [
            TranslatedSubtitleCue(startTime: 0.5, duration: 1.0, translatedText: "Line")
        ]

        document.subtitleCues = []
        document.translatedSubtitleCues = []

        XCTAssertNil(document.subtitleCuesRaw)
        XCTAssertNil(document.translatedSubtitleCuesRaw)
    }
}
