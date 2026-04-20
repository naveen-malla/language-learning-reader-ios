import XCTest
@testable import LanguageReader

final class StudyLanguageSettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "StudyLanguageSettingsStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testBootstrapDefaultsToGermanForFreshInstall() {
        let store = StudyLanguageSettingsStore(defaults: defaults)

        store.bootstrapIfNeeded(hasPersistedContent: false)

        XCTAssertEqual(store.studyLanguage, .german)
    }

    func testBootstrapPreservesKannadaForMigratedInstall() {
        let store = StudyLanguageSettingsStore(defaults: defaults)

        store.bootstrapIfNeeded(hasPersistedContent: true)

        XCTAssertEqual(store.studyLanguage, .kannada)
    }
}
