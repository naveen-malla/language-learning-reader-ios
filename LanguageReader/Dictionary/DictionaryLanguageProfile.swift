import Foundation

struct DictionaryLanguageProfile {
    struct SuffixRule {
        let suffix: String
        let minimumStemLength: Int
    }

    let languageCode: String
    let suffixRules: [SuffixRule]
    let progressiveVerbEndings: [String]
    let linkedCharacter: Character?
    let minimumVerbStemLength: Int

    static func resolve(for languageCode: String) -> DictionaryLanguageProfile {
        switch languageCode.lowercased() {
        case "de":
            return .german
        case "kn":
            return .kannada
        default:
            return .generic(languageCode: languageCode)
        }
    }

    static func generic(languageCode: String) -> DictionaryLanguageProfile {
        DictionaryLanguageProfile(
            languageCode: languageCode,
            suffixRules: [],
            progressiveVerbEndings: [],
            linkedCharacter: nil,
            minimumVerbStemLength: 3
        )
    }

    static let kannada = DictionaryLanguageProfile(
        languageCode: "kn",
        suffixRules: [
            .init(suffix: "ವಾಗಿತ್ತು", minimumStemLength: 3),
            .init(suffix: "ವಾಗಿ", minimumStemLength: 3),
            .init(suffix: "ಗಳನ್ನು", minimumStemLength: 2),
            .init(suffix: "ಗಳಲ್ಲಿ", minimumStemLength: 2),
            .init(suffix: "ಯಲ್ಲಿ", minimumStemLength: 2),
            .init(suffix: "ದಲ್ಲಿ", minimumStemLength: 2),
            .init(suffix: "ನಲ್ಲಿ", minimumStemLength: 2),
            .init(suffix: "ಯಲಿ", minimumStemLength: 2),
            .init(suffix: "ಗಳ", minimumStemLength: 2),
            .init(suffix: "ಗಳು", minimumStemLength: 2),
            .init(suffix: "ವನ್ನು", minimumStemLength: 2),
            .init(suffix: "ವನು", minimumStemLength: 2),
            .init(suffix: "ಕ್ಕೆ", minimumStemLength: 2),
            .init(suffix: "ನಿಗೆ", minimumStemLength: 2),
            .init(suffix: "ರಿಗೆ", minimumStemLength: 2),
            .init(suffix: "ದಿಂದ", minimumStemLength: 2),
            .init(suffix: "ಯನ್ನು", minimumStemLength: 2),
            .init(suffix: "ನ್ನು", minimumStemLength: 2),
            .init(suffix: "ಲ್ಲಿ", minimumStemLength: 2),
            .init(suffix: "ಲಿ", minimumStemLength: 2),
            .init(suffix: "ಗೆ", minimumStemLength: 2),
            .init(suffix: "ನು", minimumStemLength: 2),
            .init(suffix: "ವೂ", minimumStemLength: 3),
            .init(suffix: "ವೇ", minimumStemLength: 3),
            .init(suffix: "ಯ", minimumStemLength: 2),
            .init(suffix: "ದ", minimumStemLength: 2)
        ],
        progressiveVerbEndings: [
            "ುತ್ತಿದ್ದರು",
            "ುತ್ತಿದ್ದ",
            "ುತ್ತಿತ್ತು",
            "ುತ್ತದೆ",
            "ುತ್ತವೆ",
            "ತ್ತಿದ್ದರು",
            "ತ್ತಿದ್ದ",
            "ತ್ತಿತ್ತು",
            "ತ್ತದೆ",
            "ತ್ತವೆ"
        ],
        linkedCharacter: "ಯ",
        minimumVerbStemLength: 2
    )

    static let german = DictionaryLanguageProfile(
        languageCode: "de",
        suffixRules: [
            .init(suffix: "ern", minimumStemLength: 3),
            .init(suffix: "en", minimumStemLength: 3),
            .init(suffix: "er", minimumStemLength: 3),
            .init(suffix: "es", minimumStemLength: 3),
            .init(suffix: "em", minimumStemLength: 3),
            .init(suffix: "e", minimumStemLength: 3),
            .init(suffix: "n", minimumStemLength: 3),
            .init(suffix: "s", minimumStemLength: 3)
        ],
        progressiveVerbEndings: [],
        linkedCharacter: nil,
        minimumVerbStemLength: 3
    )
}

struct DictionaryWordFormGenerator {
    private let profile: DictionaryLanguageProfile

    init(profile: DictionaryLanguageProfile) {
        self.profile = profile
    }

    func candidateKeys(from normalizedWord: String) -> [String] {
        var candidates: [String] = []

        func appendIfNew(_ value: String, minimumLength: Int = 1) {
            guard value.unicodeScalars.count >= minimumLength else { return }
            guard !candidates.contains(value) else { return }
            candidates.append(value)
        }

        appendIfNew(normalizedWord)

        for rule in profile.suffixRules where normalizedWord.hasSuffix(rule.suffix) {
            let stem = String(normalizedWord.dropLast(rule.suffix.count))
            appendIfNew(stem, minimumLength: rule.minimumStemLength)

            if let linkedCharacter = profile.linkedCharacter, stem.last == linkedCharacter {
                appendIfNew(String(stem.dropLast()), minimumLength: rule.minimumStemLength)
            }
        }

        for ending in profile.progressiveVerbEndings where normalizedWord.hasSuffix(ending) {
            let stem = String(normalizedWord.dropLast(ending.count))
            appendIfNew(stem, minimumLength: profile.minimumVerbStemLength)
            let baseStem = stem.droppingTrailingKannadaUSign ?? stem
            appendIfNew(baseStem, minimumLength: profile.minimumVerbStemLength)
            appendIfNew(baseStem + "ು", minimumLength: profile.minimumVerbStemLength)
        }

        return candidates
    }
}

private extension String {
    var droppingTrailingKannadaUSign: String? {
        let kannadaUSign: UInt32 = 0x0CC1
        guard unicodeScalars.last?.value == kannadaUSign else {
            return nil
        }

        var scalars = Array(unicodeScalars)
        scalars.removeLast()
        return String(String.UnicodeScalarView(scalars))
    }
}
