import Foundation

struct SampleDictionaryProvider: DictionaryProvider {
    private let entries: [String: String]
    private let languageCode: String

    init(languageCode: String = "kn", entries: [String: String]? = nil) {
        let resolvedLanguage = SupportedLanguage.legacyResolved(languageCode).rawValue
        self.languageCode = resolvedLanguage
        self.entries = entries ?? SampleDictionary.data(for: resolvedLanguage)
    }

    func lookup(normalizedKey: String) -> String? {
        entries[normalizedKey]
    }

    var sourceDescription: String {
        "Bundled sample dictionary (\(languageCode))"
    }
}

enum SampleDictionary {
    static func data(for languageCode: String) -> [String: String] {
        switch SupportedLanguage.legacyResolved(languageCode) {
        case .german:
            return german
        case .kannada:
            return kannada
        }
    }

    private static let kannada: [String: String] = [
        "ನಮಸ್ಕಾರ": "hello",
        "ಇದು": "this",
        "ಪಠ್ಯ": "text",
        "ಪರೀಕ್ಷೆ": "test",
        "ಶಿಕ್ಷಣ": "learning",
        "ಪದ": "word",
        "ಅರ್ಥ": "meaning",
        "ಓದು": "read",
        "ಕನ್ನಡ": "Kannada",
        "ಮಾತು": "speech",
        "ಮನೆ": "house",
        "ನೀರು": "water",
        "ಪುಸ್ತಕ": "book",
        "ಹೆಸರು": "name",
        "ಪ್ರಶ್ನೆ": "question",
        "ಉತ್ತರ": "answer"
    ]

    private static let german: [String: String] = [
        "hallo": "hello",
        "haus": "house",
        "buch": "book",
        "schule": "school",
        "wasser": "water",
        "geschichte": "story",
        "sprache": "language",
        "fenster": "window",
        "brief": "letter",
        "markt": "market",
        "lernen": "learn",
        "lesen": "read",
        "wort": "word",
        "antwort": "answer",
        "frage": "question",
        "heute": "today"
    ]
}
