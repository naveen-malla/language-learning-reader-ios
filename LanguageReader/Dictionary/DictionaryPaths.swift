import Foundation

enum DictionaryPaths {
    static let sqliteFileName = "dictionary.sqlite"
    static let bundledFileName = "dictionary"
    static let overridesFileName = "dictionary_overrides.tsv"
    static let missingFileName = "dictionary_missing.tsv"

    static func documentsDictionaryURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(sqliteFileName)
    }

    static func bundledDictionaryURL() -> URL? {
        Bundle.main.url(forResource: bundledFileName, withExtension: "sqlite")
    }

    static func documentsOverridesURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(overridesFileName)
    }

    static func documentsMissingURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(missingFileName)
    }
}
