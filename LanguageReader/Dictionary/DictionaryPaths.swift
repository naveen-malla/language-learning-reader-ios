import Foundation

/// Provides file system paths for dictionary resources.
enum DictionaryPaths {
    /// The name of the SQLite dictionary file.
    static let sqliteFileName = "dictionary.sqlite"

    /// Returns the URL for the dictionary file in the app's Documents directory.
    /// - Returns: The URL if the documents directory is accessible, nil otherwise.
    static func documentsDictionaryURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(sqliteFileName)
    }
}
