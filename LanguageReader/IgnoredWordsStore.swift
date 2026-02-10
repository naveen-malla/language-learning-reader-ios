import Foundation

final class IgnoredWordsStore {
    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "ignored_normalized_words_v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func allKeys() -> Set<String> {
        let values = defaults.array(forKey: storageKey) as? [String] ?? []
        return Set(values)
    }

    func contains(normalizedKey: String) -> Bool {
        allKeys().contains(normalizedKey)
    }

    func add(normalizedKey: String) {
        var keys = allKeys()
        keys.insert(normalizedKey)
        save(keys)
    }

    func remove(normalizedKey: String) {
        var keys = allKeys()
        keys.remove(normalizedKey)
        save(keys)
    }

    private func save(_ keys: Set<String>) {
        defaults.set(Array(keys).sorted(), forKey: storageKey)
    }
}
