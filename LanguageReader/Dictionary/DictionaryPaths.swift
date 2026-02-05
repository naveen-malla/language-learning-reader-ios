import Foundation

enum DictionaryPaths {
    static let sqliteFileName = "dictionary.sqlite"
    static let bundledFileName = "dictionary"

    static func documentsDictionaryURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(sqliteFileName)
    }

    static func bundledDictionaryURL() -> URL? {
        Bundle.main.url(forResource: bundledFileName, withExtension: "sqlite")
    }
}
