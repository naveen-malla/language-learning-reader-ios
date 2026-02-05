import Foundation

final class DictionaryManager {
    static let shared = DictionaryManager()

    private let provider: DictionaryProvider
    private let normalizer = TextNormalizer()

    init(provider: DictionaryProvider? = nil) {
        if let provider {
            self.provider = provider
        } else {
            self.provider = DictionaryManager.makeProvider()
        }
    }

    func lookup(_ word: String) -> String? {
        let normalized = normalizer.normalize(word)
        return provider.lookup(normalizedKey: normalized)
    }

    var sourceDescription: String {
        provider.sourceDescription
    }

    static func makeProvider() -> DictionaryProvider {
        if let url = DictionaryPaths.documentsDictionaryURL(),
           FileManager.default.fileExists(atPath: url.path),
           let sqliteProvider = SQLiteDictionaryProvider(fileURL: url, sourceDescription: "Local dictionary file") {
            return sqliteProvider
        }

        if let url = DictionaryPaths.bundledDictionaryURL(),
           FileManager.default.fileExists(atPath: url.path),
           let sqliteProvider = SQLiteDictionaryProvider(fileURL: url, sourceDescription: "Bundled dictionary file") {
            return sqliteProvider
        }

        return SampleDictionaryProvider()
    }
}
