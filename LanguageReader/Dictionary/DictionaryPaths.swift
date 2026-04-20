import Foundation

enum DictionaryPaths {
    static let sqliteFileName = "dictionary.sqlite"
    static let germanSQLiteFileName = "dictionary_de.sqlite"
    static let bundledFileName = "dictionary"
    static let germanBundledFileName = "dictionary_de"
    static let overridesFileName = "dictionary_overrides.tsv"
    static let germanOverridesFileName = "dictionary_overrides_de.tsv"
    static let missingFileName = "dictionary_missing.tsv"
    static let germanMissingFileName = "dictionary_missing_de.tsv"
    static let cloudCacheFileName = "dictionary_cloud_cache.tsv"

    static func documentsDictionaryURL(languageCode: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(sqliteFileName(for: languageCode))
    }

    static func bundledDictionaryURL(languageCode: String) -> URL? {
        Bundle.main.url(forResource: bundledFileName(for: languageCode), withExtension: "sqlite")
    }

    static func documentsOverridesURL(languageCode: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(overridesFileName(for: languageCode))
    }

    static func documentsMissingURL(languageCode: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(missingFileName(for: languageCode))
    }

    static func documentsCloudCacheURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(cloudCacheFileName)
    }

    private static func bundledFileName(for languageCode: String) -> String {
        switch SupportedLanguage.legacyResolved(languageCode) {
        case .german:
            return germanBundledFileName
        case .kannada:
            return bundledFileName
        }
    }

    private static func sqliteFileName(for languageCode: String) -> String {
        switch SupportedLanguage.legacyResolved(languageCode) {
        case .german:
            return germanSQLiteFileName
        case .kannada:
            return sqliteFileName
        }
    }

    private static func overridesFileName(for languageCode: String) -> String {
        switch SupportedLanguage.legacyResolved(languageCode) {
        case .german:
            return germanOverridesFileName
        case .kannada:
            return overridesFileName
        }
    }

    private static func missingFileName(for languageCode: String) -> String {
        switch SupportedLanguage.legacyResolved(languageCode) {
        case .german:
            return germanMissingFileName
        case .kannada:
            return missingFileName
        }
    }
}
