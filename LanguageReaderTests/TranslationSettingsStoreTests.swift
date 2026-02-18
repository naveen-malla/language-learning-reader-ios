import XCTest
@testable import LanguageReader

final class TranslationSettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var keychain: InMemorySecretStore!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "TranslationSettingsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        keychain = InMemorySecretStore()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        keychain = nil
        suiteName = nil
        super.tearDown()
    }

    func testConfigurationRequiresKeyAndRegion() throws {
        let store = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        XCTAssertNil(store.configuration())

        try store.saveAPIKey("secret")
        XCTAssertNil(store.configuration())

        store.regionText = "germanywestcentral"
        XCTAssertNotNil(store.configuration())
    }

    func testConfigurationNormalizesEndpoint() throws {
        let store = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        store.endpointText = "https://api.cognitive.microsofttranslator.com/ "
        store.regionText = "germanywestcentral"
        try store.saveAPIKey("secret")

        let config = try XCTUnwrap(store.configuration())
        XCTAssertEqual(config.endpoint.absoluteString, "https://api.cognitive.microsofttranslator.com")
        XCTAssertEqual(config.sourceLanguage, "kn")
        XCTAssertEqual(config.targetLanguage, "en")
    }

    func testClearConfigurationRestoresDefaults() {
        let store = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        store.endpointText = "https://example.com"
        store.regionText = "eastus"
        store.sourceLanguage = "ta"
        store.targetLanguage = "de"

        store.clearConfiguration()

        XCTAssertEqual(store.endpointText, TranslationSettingsStore.defaultEndpoint)
        XCTAssertEqual(store.regionText, TranslationSettingsStore.defaultRegion)
        XCTAssertEqual(store.sourceLanguage, TranslationSettingsStore.defaultSourceLanguage)
        XCTAssertEqual(store.targetLanguage, TranslationSettingsStore.defaultTargetLanguage)
    }

    func testSaveAndClearAPIKey() throws {
        let store = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        XCTAssertFalse(store.hasAPIKey)

        try store.saveAPIKey("abc123")
        XCTAssertTrue(store.hasAPIKey)
        XCTAssertEqual(store.apiKey, "abc123")

        try store.clearAPIKey()
        XCTAssertFalse(store.hasAPIKey)
        XCTAssertNil(store.apiKey)
    }

    func testConfigurationRequiresValidEndpointURL() throws {
        let store = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        store.endpointText = "https://"
        store.regionText = "eastus"
        try store.saveAPIKey("secret")

        XCTAssertNil(store.configuration())
    }

    func testConfigurationRejectsNonHTTPSchemes() throws {
        let store = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        store.endpointText = "ftp://api.cognitive.microsofttranslator.com"
        store.regionText = "eastus"
        try store.saveAPIKey("secret")

        XCTAssertNil(store.configuration())
    }

    func testConfigurationRejectsEmptyLanguages() throws {
        let store = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        store.regionText = "eastus"
        store.sourceLanguage = "  "
        store.targetLanguage = ""
        try store.saveAPIKey("secret")

        XCTAssertNil(store.configuration())
    }

    func testConfigurationAcceptsWhitespaceAroundFields() throws {
        let store = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        store.endpointText = " https://api.cognitive.microsofttranslator.com "
        store.regionText = " westus2 "
        store.sourceLanguage = " kn "
        store.targetLanguage = " en "
        try store.saveAPIKey(" secret ")

        let config = try XCTUnwrap(store.configuration())
        XCTAssertEqual(config.endpoint.absoluteString, "https://api.cognitive.microsofttranslator.com")
        XCTAssertEqual(config.region, "westus2")
        XCTAssertEqual(config.sourceLanguage, "kn")
        XCTAssertEqual(config.targetLanguage, "en")
        XCTAssertEqual(config.apiKey, "secret")
    }
}

private final class InMemorySecretStore: SecretStoring {
    private var values: [String: String] = [:]

    func read(account: String) -> String? {
        values[account]
    }

    func write(_ value: String, account: String) throws {
        values[account] = value
    }

    func delete(account: String) throws {
        values.removeValue(forKey: account)
    }
}
