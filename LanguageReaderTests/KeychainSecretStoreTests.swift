import XCTest
@testable import LanguageReader

final class KeychainSecretStoreTests: XCTestCase {
    func testReadReturnsNilForMissingEntry() {
        let store = makeStore()
        let account = "missing-\(UUID().uuidString)"

        XCTAssertNil(store.read(account: account))
        XCTAssertNoThrow(try store.delete(account: account))
    }

    func testWriteAndReadRoundTrip() throws {
        let store = makeStore()
        let account = "roundtrip-\(UUID().uuidString)"
        defer { try? store.delete(account: account) }

        try store.write("secret-value", account: account)

        XCTAssertEqual(store.read(account: account), "secret-value")
    }

    func testWriteOverwritesExistingValue() throws {
        let store = makeStore()
        let account = "overwrite-\(UUID().uuidString)"
        defer { try? store.delete(account: account) }

        try store.write("first", account: account)
        try store.write("second", account: account)

        XCTAssertEqual(store.read(account: account), "second")
    }

    private func makeStore() -> KeychainSecretStore {
        KeychainSecretStore(service: "com.local.LanguageReaderTests.\(UUID().uuidString)")
    }
}
