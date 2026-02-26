import XCTest
@testable import LanguageReader

final class DictionaryMissingFixtureTests: XCTestCase {
    private struct FixtureCase {
        let word: String
        let baseKey: String
        let expectedMeaning: String
        let expectedPath: DictionaryLookupResult.Path
    }

    func testKnownFailureWordsResolveFromFixture() throws {
        let fixtureCases = try loadFixtureCases()

        var entries: [String: String] = [:]
        for item in fixtureCases {
            if item.expectedPath == .redirect {
                entries[item.word] = "= \(item.baseKey)2."
            }
            entries[item.baseKey] = item.expectedMeaning
        }

        let manager = DictionaryManager(
            provider: SampleDictionaryProvider(entries: entries),
            overrideStore: DictionaryOverrideStore(fileURL: nil, missingURL: nil),
            cloudStore: DictionaryCloudMeaningStore(fileURL: nil, entries: []),
            remoteProvider: nil,
            sourceLanguageProvider: { "kn" },
            targetLanguageProvider: { "en" },
            defaults: UserDefaults(suiteName: "DictionaryMissingFixtureTests")!
        )

        for item in fixtureCases {
            let result = manager.lookupDetailed(item.word)
            XCTAssertEqual(result.path, item.expectedPath, "Expected path mismatch for word: \(item.word)")
            XCTAssertNotNil(result.meaning, "Missing meaning for word: \(item.word)")
            XCTAssertTrue(
                result.meaning?.localizedCaseInsensitiveContains(item.expectedMeaning) == true,
                "Meaning mismatch for word: \(item.word)"
            )
        }
    }

    private func loadFixtureCases() throws -> [FixtureCase] {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("dictionary_missing_fixture.tsv")

        let content = try String(contentsOf: fixtureURL, encoding: .utf8)

        return content
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .compactMap(parseLine)
    }

    private func parseLine(_ line: String) -> FixtureCase? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }

        let parts = trimmed.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 4 else {
            XCTFail("Invalid fixture row: \(line)")
            return nil
        }

        let word = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let baseKey = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let expectedMeaning = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let pathRaw = parts[3].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !word.isEmpty, !baseKey.isEmpty, !expectedMeaning.isEmpty else {
            XCTFail("Invalid fixture values: \(line)")
            return nil
        }

        let path: DictionaryLookupResult.Path
        switch pathRaw {
        case "suffix":
            path = .suffix
        case "redirect":
            path = .redirect
        default:
            XCTFail("Unsupported path in fixture: \(pathRaw)")
            return nil
        }

        return FixtureCase(
            word: word,
            baseKey: baseKey,
            expectedMeaning: expectedMeaning,
            expectedPath: path
        )
    }
}
