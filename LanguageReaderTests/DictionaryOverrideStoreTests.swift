import Foundation
import XCTest
@testable import LanguageReader

final class DictionaryOverrideStoreTests: XCTestCase {
    private var tempDirectories: [URL] = []

    override func tearDown() {
        for directory in tempDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        tempDirectories.removeAll()
        super.tearDown()
    }

    private func makeTempFileURL(fileName: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        tempDirectories.append(directory)
        return directory.appendingPathComponent(fileName)
    }

    func testEnsureOverridesFileCreatesTemplate() throws {
        let overridesURL = try makeTempFileURL(fileName: "dictionary_overrides.tsv")
        let store = DictionaryOverrideStore(fileURL: overridesURL, missingURL: nil)

        store.ensureOverridesFile()

        let contents = try String(contentsOf: overridesURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("# Dictionary overrides (TSV)"))
        XCTAssertTrue(contents.contains("# Format: normalized_key<TAB>meaning"))
    }

    func testSetOverridePersistsNormalizedKeyAndTrimmedMeaning() throws {
        let overridesURL = try makeTempFileURL(fileName: "dictionary_overrides.tsv")
        let store = DictionaryOverrideStore(fileURL: overridesURL, missingURL: nil)

        store.setOverride(word: "  HELLO ", meaning: "  hi  ")

        let reloadedStore = DictionaryOverrideStore(fileURL: overridesURL, missingURL: nil)
        XCTAssertEqual(reloadedStore.lookup(normalizedKey: "hello"), "hi")
    }

    func testLoadOverridesIgnoresCommentsAndMalformedLines() throws {
        let overridesURL = try makeTempFileURL(fileName: "dictionary_overrides.tsv")
        let content = [
            "# Comment",
            "",
            "valid\tmeaning",
            "missing-tab-value",
            "empty-value\t",
            "\tempty-key",
            "another\tentry"
        ].joined(separator: "\n")
        try content.write(to: overridesURL, atomically: true, encoding: .utf8)

        let store = DictionaryOverrideStore(fileURL: overridesURL, missingURL: nil)

        XCTAssertEqual(store.lookup(normalizedKey: "valid"), "meaning")
        XCTAssertEqual(store.lookup(normalizedKey: "another"), "entry")
        XCTAssertNil(store.lookup(normalizedKey: "missing-tab-value"))
        XCTAssertNil(store.lookup(normalizedKey: "empty-value"))
    }

    func testAppendMissingAddsOneLinePerWord() throws {
        let missingURL = try makeTempFileURL(fileName: "dictionary_missing.tsv")
        let store = DictionaryOverrideStore(fileURL: nil, missingURL: missingURL)

        store.appendMissing(word: "ಮೊದಲ")
        store.appendMissing(word: "ಎರಡನೆ")

        let contents = try String(contentsOf: missingURL, encoding: .utf8)
        let lines = contents.split(separator: "\n")

        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasPrefix("ಮೊದಲ\t"))
        XCTAssertTrue(lines[1].hasPrefix("ಎರಡನೆ\t"))
    }
}
