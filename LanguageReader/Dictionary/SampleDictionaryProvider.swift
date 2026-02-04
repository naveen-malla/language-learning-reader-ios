import Foundation

struct SampleDictionaryProvider: DictionaryProvider {
    private let entries: [String: String]

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
