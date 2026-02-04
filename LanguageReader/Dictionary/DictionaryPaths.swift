import Foundation

enum DictionaryPaths {
    static let sqliteFileName = "dictionary.sqlite"

    static func documentsDictionaryURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(sqliteFileName)
    }
}
