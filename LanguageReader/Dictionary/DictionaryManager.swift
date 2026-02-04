import Foundation

/// Manages dictionary lookups with automatic provider selection and text normalization.
final class DictionaryManager {
    /// Shared singleton instance.
    static let shared = DictionaryManager()

    private let provider: DictionaryProvider
    private let normalizer = TextNormalizer()

    /// Creates a dictionary manager with an optional provider.
    /// If no provider is given, automatically selects the best available provider.
    /// - Parameter provider: Optional provider to use. If nil, uses automatic selection.
    init(provider: DictionaryProvider? = nil) {
        if let provider {
            self.provider = provider
        } else {
            self.provider = DictionaryManager.makeProvider()
        }
    }

    /// Looks up a word in the dictionary.
    /// Automatically normalizes the input before lookup.
    /// - Parameter word: The word to look up.
    /// - Returns: The meaning if found, nil otherwise.
    func lookup(_ word: String) -> String? {
        let normalized = normalizer.normalize(word)
        return provider.lookup(normalizedKey: normalized)
    }

    /// The description of the current dictionary source.
    var sourceDescription: String {
        provider.sourceDescription
    }

    /// Creates the best available dictionary provider.
    /// Prefers SQLite database if available, falls back to sample dictionary.
    /// - Returns: A dictionary provider instance.
    private static func makeProvider() -> DictionaryProvider {
        if let url = DictionaryPaths.documentsDictionaryURL(),
           FileManager.default.fileExists(atPath: url.path),
           let sqliteProvider = SQLiteDictionaryProvider(fileURL: url, sourceDescription: "Local dictionary file") {
            return sqliteProvider
        }

        return SampleDictionaryProvider()
    }
}
