import Foundation

final class IgnoredWordsStore {
    private static let legacyStorageKey = "ignored_normalized_words_v1"
    private let defaults: UserDefaults
    private let storageKeyPrefix: String

    init(
        defaults: UserDefaults = .standard,
        storageKeyPrefix: String = "ignored_normalized_words_by_language_v1"
    ) {
        self.defaults = defaults
        self.storageKeyPrefix = storageKeyPrefix
    }

    var hasLegacyEntries: Bool {
        let values = defaults.array(forKey: Self.legacyStorageKey) as? [String] ?? []
        return !values.isEmpty
    }

    func allKeys(languageCode: String) -> Set<String> {
        let values = defaults.array(forKey: storageKey(for: languageCode)) as? [String] ?? []
        return Set(values)
    }

    func contains(normalizedKey: String, languageCode: String) -> Bool {
        allKeys(languageCode: languageCode).contains(normalizedKey)
    }

    func add(normalizedKey: String, languageCode: String) {
        var keys = allKeys(languageCode: languageCode)
        keys.insert(normalizedKey)
        save(keys, languageCode: languageCode)
    }

    func remove(normalizedKey: String, languageCode: String) {
        var keys = allKeys(languageCode: languageCode)
        keys.remove(normalizedKey)
        save(keys, languageCode: languageCode)
    }

    func migrateLegacyEntriesIfNeeded(to language: SupportedLanguage) {
        let legacyValues = defaults.array(forKey: Self.legacyStorageKey) as? [String] ?? []
        guard !legacyValues.isEmpty else { return }

        let targetKey = storageKey(for: language.rawValue)
        let existingValues = defaults.array(forKey: targetKey) as? [String] ?? []
        let merged = Set(existingValues).union(legacyValues)
        defaults.set(Array(merged).sorted(), forKey: targetKey)
        defaults.removeObject(forKey: Self.legacyStorageKey)
    }

    private func storageKey(for languageCode: String) -> String {
        let language = SupportedLanguage.legacyResolved(languageCode).rawValue
        return "\(storageKeyPrefix).\(language)"
    }

    private func save(_ keys: Set<String>, languageCode: String) {
        defaults.set(Array(keys).sorted(), forKey: storageKey(for: languageCode))
    }
}
