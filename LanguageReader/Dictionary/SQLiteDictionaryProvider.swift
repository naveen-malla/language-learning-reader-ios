import Foundation
import SQLite3

final class SQLiteDictionaryProvider: DictionaryProvider {
    private let db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.languagereader.dictionary.sqlite")
    private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    let sourceDescription: String

    init?(fileURL: URL, sourceDescription: String) {
        self.sourceDescription = sourceDescription
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(fileURL.path, &handle, flags, nil) != SQLITE_OK {
            self.db = nil
            return nil
        }

        self.db = handle
    }

    deinit {
        if let db {
            _ = queue.sync {
                sqlite3_close(db)
            }
        }
    }

    func lookup(normalizedKey: String) -> String? {
        guard let db else { return nil }
        return queue.sync {
            var statement: OpaquePointer?
            let query = "SELECT meaning FROM entries WHERE key = ? LIMIT 1;"
            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                return nil
            }
            defer { sqlite3_finalize(statement) }

            let result = normalizedKey.withCString { cString in
                sqlite3_bind_text(statement, 1, cString, -1, sqliteTransient)
            }

            guard result == SQLITE_OK else { return nil }

            if sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    return String(cString: cString)
                }
            }
            return nil
        }
    }
}
