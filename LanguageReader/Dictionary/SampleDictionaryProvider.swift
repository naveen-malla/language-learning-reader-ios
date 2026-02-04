import Foundation

/// Dictionary provider that uses an in-memory dictionary.
struct SampleDictionaryProvider: DictionaryProvider {
    private let entries: [String: String]

    /// Creates a sample dictionary provider.
    /// - Parameter entries: The dictionary entries. Defaults to bundled sample data.
    init(entries: [String: String] = SampleDictionary.data) {
        self.entries = entries
    }

    func lookup(normalizedKey: String) -> String? {
        entries[normalizedKey]
    }

    var sourceDescription: String {
        "Bundled sample dictionary"
    }
}

/// Contains sample Kannada-English dictionary entries for testing and development.
enum SampleDictionary {
    static let data: [String: String] = [
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
}
