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

    func testKannadaProfileGeneratesProgressiveVerbStemAndInfinitive() {
        let profile = DictionaryLanguageProfile.resolve(for: "kn")
        let generator = DictionaryWordFormGenerator(profile: profile)

        let candidates = generator.candidateKeys(from: "ಬೀಸುತ್ತಿತ್ತು")

        XCTAssertTrue(candidates.contains("ಬೀಸ"))
        XCTAssertTrue(candidates.contains("ಬೀಸು"))
    }

    func testKannadaProfileDropsLinkedCharacterWhenSuffixApplied() {
        let profile = DictionaryLanguageProfile.resolve(for: "kn")
        let generator = DictionaryWordFormGenerator(profile: profile)

        let candidates = generator.candidateKeys(from: "ಕಾಯದಲ್ಲಿ")

        XCTAssertTrue(candidates.contains("ಕಾಯ"))
        XCTAssertTrue(candidates.contains("ಕಾ"))
    }
}
