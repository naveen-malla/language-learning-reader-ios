import XCTest
@testable import LanguageReader

final class DictionaryLanguageProfileTests: XCTestCase {
    func testGenericProfileKeepsOnlyBaseWord() {
        let profile = DictionaryLanguageProfile.resolve(for: "es")
        let generator = DictionaryWordFormGenerator(profile: profile)

        let candidates = generator.candidateKeys(from: "hola")

        XCTAssertEqual(candidates, ["hola"])
    }

    func testKannadaProfileGeneratesInflectionCandidates() {
        let profile = DictionaryLanguageProfile.resolve(for: "kn")
        let generator = DictionaryWordFormGenerator(profile: profile)

        let candidates = generator.candidateKeys(from: "ಪದವನ್ನು")

        XCTAssertTrue(candidates.contains("ಪದ"))
    }
}
