import Foundation
import XCTest
@testable import LanguageReader

final class DictionaryCloudMeaningStoreTests: XCTestCase {
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

    func testSetLookupAndPersistRoundTrip() throws {
        let fileURL = try makeTempFileURL(fileName: "dictionary_cloud_cache.tsv")
        let store = DictionaryCloudMeaningStore(fileURL: fileURL)

        store.setMeaning(normalizedKey: "hola", languageCode: "es", meaning: "hello", source: "remote")

        XCTAssertEqual(store.lookup(normalizedKey: "hola", languageCode: "es"), "hello")
        XCTAssertEqual(store.allCount(), 1)

        let reloaded = DictionaryCloudMeaningStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.lookup(normalizedKey: "hola", languageCode: "es"), "hello")
        XCTAssertEqual(reloaded.allCount(), 1)
    }

    func testClearRemovesEntries() {
        let store = DictionaryCloudMeaningStore(
            fileURL: nil,
            entries: [
                CachedWordMeaning(languageCode: "kn", normalizedKey: "ಮನೆ", meaning: "house", source: "remote", updatedAt: Date())
            ]
        )

        XCTAssertEqual(store.allCount(), 1)
        store.clear()
        XCTAssertEqual(store.allCount(), 0)
        XCTAssertNil(store.lookup(normalizedKey: "ಮನೆ", languageCode: "kn"))
    }

    func testSetMeaningNormalizesLanguageAndDefaultsSource() throws {
        let fileURL = try makeTempFileURL(fileName: "dictionary_cloud_cache.tsv")
        let store = DictionaryCloudMeaningStore(fileURL: fileURL)

        store.setMeaning(normalizedKey: "  ಮನೆ\t", languageCode: " KN ", meaning: " house\t ", source: " ")

        XCTAssertEqual(store.lookup(normalizedKey: "ಮನೆ", languageCode: "kn"), "house")
        XCTAssertEqual(store.allCount(), 1)

        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("kn\tಮನೆ\thouse\tcloud\t"))
    }

    func testSetMeaningIgnoresBlankInputs() {
        let store = DictionaryCloudMeaningStore(fileURL: nil)

        store.setMeaning(normalizedKey: "", languageCode: "kn", meaning: "house", source: "remote")
        store.setMeaning(normalizedKey: "ಮನೆ", languageCode: "", meaning: "house", source: "remote")
        store.setMeaning(normalizedKey: "ಮನೆ", languageCode: "kn", meaning: "   ", source: "remote")

        XCTAssertEqual(store.allCount(), 0)
        XCTAssertNil(store.lookup(normalizedKey: "ಮನೆ", languageCode: "kn"))
    }

    func testLoadEntriesNormalizesLanguageAndSkipsInvalidRows() throws {
        let fileURL = try makeTempFileURL(fileName: "dictionary_cloud_cache.tsv")
        let content = [
            "# header",
            "KN\tಮನೆ\thouse\t\t2024-01-01T00:00:00Z",
            "\tempty-language\thouse\tremote\t2024-01-01T00:00:00Z",
            "kn\t\thouse\tremote\t2024-01-01T00:00:00Z",
            "kn\tಮನೆ\t\tremote\t2024-01-01T00:00:00Z"
        ].joined(separator: "\n")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let store = DictionaryCloudMeaningStore(fileURL: fileURL)

        XCTAssertEqual(store.lookup(normalizedKey: "ಮನೆ", languageCode: "kn"), "house")
        XCTAssertEqual(store.allCount(), 1)
    }

    func testLoadEntriesUsesNewestTimestampForDuplicateKey() throws {
        let fileURL = try makeTempFileURL(fileName: "dictionary_cloud_cache.tsv")
        let content = [
            "kn\tಮನೆ\thouse-old\tremote\t2024-01-01T00:00:00Z",
            "kn\tಮನೆ\thouse-new\tremote\t2024-01-02T00:00:00Z",
            "kn\tಪದ\tword\tremote\t2024-01-01T00:00:00Z"
        ].joined(separator: "\n")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let store = DictionaryCloudMeaningStore(fileURL: fileURL)

        XCTAssertEqual(store.lookup(normalizedKey: "ಮನೆ", languageCode: "kn"), "house-new")
        XCTAssertEqual(store.lookup(normalizedKey: "ಪದ", languageCode: "kn"), "word")
        XCTAssertEqual(store.allCount(), 2)
    }

    func testLoadEntriesReplacesInvalidTimestampDuplicateWithValidTimestamp() throws {
        let fileURL = try makeTempFileURL(fileName: "dictionary_cloud_cache.tsv")
        let content = [
            "kn\tಮನೆ\thouse-invalid\tremote\tnot-a-date",
            "kn\tಮನೆ\thouse-valid\tremote\t2024-01-02T00:00:00Z"
        ].joined(separator: "\n")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let store = DictionaryCloudMeaningStore(fileURL: fileURL)

        XCTAssertEqual(store.lookup(normalizedKey: "ಮನೆ", languageCode: "kn"), "house-valid")
        XCTAssertEqual(store.allCount(), 1)
    }
}
