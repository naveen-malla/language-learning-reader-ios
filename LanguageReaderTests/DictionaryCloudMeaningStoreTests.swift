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
}
