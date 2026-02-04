import Foundation
import SQLite3

final class SQLiteDictionaryProvider: DictionaryProvider {
    private let db: OpaquePointer?
    private let statement: OpaquePointer?
    private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    let sourceDescription: String

    init?(fileURL: URL, sourceDescription: String) {
        self.sourceDescription = sourceDescription
        var handle: OpaquePointer?
        if sqlite3_open(fileURL.path, &handle) != SQLITE_OK {
            self.db = nil
            self.statement = nil
            return nil
        }

        self.db = handle
        var stmt: OpaquePointer?
        let query = "SELECT meaning FROM entries WHERE key = ? LIMIT 1;"
        if sqlite3_prepare_v2(handle, query, -1, &stmt, nil) != SQLITE_OK {
            sqlite3_close(handle)
            self.statement = nil
            return nil
        }
        self.statement = stmt
    }

    deinit {
        if let statement {
            sqlite3_finalize(statement)
        }
        if let db {
            sqlite3_close(db)
        }
    }

    func lookup(normalizedKey: String) -> String? {
        guard let statement else { return nil }
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)

        _ = normalizedKey.withCString { cString in
            sqlite3_bind_text(statement, 1, cString, -1, sqliteTransient)
        }
        if sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                return String(cString: cString)
            }
        }
        return nil
    }
}
