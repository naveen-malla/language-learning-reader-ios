import XCTest
@testable import LanguageReader

final class AutoImportSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AutoImportSettingsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testMigrateLegacyStateCopiesLegacyValuesIntoKannadaScope() {
        let attemptDate = Date(timeIntervalSince1970: 100)
        let successDate = Date(timeIntervalSince1970: 200)

        defaults.set(["abc123"], forKey: AutoImportSettings.historicalImportedVideoIDsKey)
        defaults.set(attemptDate, forKey: AutoImportSettings.lastAutoTopUpAttemptAtKey)
        defaults.set(successDate, forKey: AutoImportSettings.lastAutoTopUpSuccessAtKey)
        defaults.set("batch-1", forKey: AutoImportSettings.lastAutoTopUpBatchIDKey)

        AutoImportSettings.migrateLegacyStateIfNeeded(defaults: defaults)

        XCTAssertEqual(
            defaults.stringArray(forKey: AutoImportSettings.historicalImportedVideoIDsKey(for: .kannada)),
            ["abc123"]
        )
        XCTAssertEqual(
            defaults.object(forKey: AutoImportSettings.lastAutoTopUpAttemptAtKey(for: .kannada)) as? Date,
            attemptDate
        )
        XCTAssertEqual(
            defaults.object(forKey: AutoImportSettings.lastAutoTopUpSuccessAtKey(for: .kannada)) as? Date,
            successDate
        )
        XCTAssertEqual(
            defaults.string(forKey: AutoImportSettings.lastAutoTopUpBatchIDKey(for: .kannada)),
            "batch-1"
        )
    }

    func testMigrateLegacyStateDoesNotOverwriteExistingScopedValues() {
        let scopedAttempt = Date(timeIntervalSince1970: 500)

        defaults.set(Date(timeIntervalSince1970: 100), forKey: AutoImportSettings.lastAutoTopUpAttemptAtKey)
        defaults.set(scopedAttempt, forKey: AutoImportSettings.lastAutoTopUpAttemptAtKey(for: .kannada))

        AutoImportSettings.migrateLegacyStateIfNeeded(defaults: defaults)

        XCTAssertEqual(
            defaults.object(forKey: AutoImportSettings.lastAutoTopUpAttemptAtKey(for: .kannada)) as? Date,
            scopedAttempt
        )
    }
}
