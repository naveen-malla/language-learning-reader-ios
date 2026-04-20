import Foundation
import SwiftData
import XCTest
@testable import LanguageReader

@MainActor
final class AutoImportCoordinatorTests: XCTestCase {
    func testShouldRunAutoTopUpRules() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertTrue(
            AutoImportCoordinator.shouldRunAutoTopUp(
                enabled: true,
                now: now,
                lastAttemptAt: nil,
                cooldownHours: 24,
                unreadCount: 0,
                unreadThreshold: 3
            )
        )

        XCTAssertFalse(
            AutoImportCoordinator.shouldRunAutoTopUp(
                enabled: false,
                now: now,
                lastAttemptAt: nil,
                cooldownHours: 24,
                unreadCount: 0,
                unreadThreshold: 3
            )
        )

        XCTAssertFalse(
            AutoImportCoordinator.shouldRunAutoTopUp(
                enabled: true,
                now: now,
                lastAttemptAt: now.addingTimeInterval(-3600),
                cooldownHours: 24,
                unreadCount: 0,
                unreadThreshold: 3
            )
        )

        XCTAssertFalse(
            AutoImportCoordinator.shouldRunAutoTopUp(
                enabled: true,
                now: now,
                lastAttemptAt: nil,
                cooldownHours: 24,
                unreadCount: 3,
                unreadThreshold: 3
            )
        )
    }

    func testImportSmartPackDedupesAndPersistsBatchMetadata() async throws {
        let defaults = UserDefaults(suiteName: "AutoImportCoordinatorTests.\(UUID().uuidString)")!
        defaults.set(SupportedLanguage.kannada.rawValue, forKey: StudyLanguageSettingsStore.studyLanguageKey)
        defaults.set(false, forKey: AutoImportSettings.allowRepeatImportsKey)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let container = try makeContainer()
        let context = ModelContext(container)

        let existing = Document(
            title: "Existing",
            body: "Body",
            languageCode: .kannada,
            createdAt: now,
            updatedAt: now,
            sourceType: .youtube,
            sourceURL: "https://www.youtube.com/watch?v=AAAAAAAAAAA",
            sourceVideoID: "AAAAAAAAAAA",
            sourceChannel: "Existing Channel",
            sourceChannelID: "UC-EXISTING"
        )
        context.insert(existing)
        try context.save()

        let suggestions: [YouTubeSuggestedVideo] = [
            .init(
                videoID: "AAAAAAAAAAA",
                title: "Duplicate",
                channelTitle: "Existing Channel",
                channelID: "UC-EXISTING",
                category: "Basics",
                durationSeconds: 120,
                thumbnailURL: nil,
                publishedAt: now
            ),
            .init(
                videoID: "BBBBBBBBBBB",
                title: "Fresh One",
                channelTitle: "Channel One",
                channelID: "UC-ONE",
                category: "Grammar",
                durationSeconds: 180,
                thumbnailURL: nil,
                publishedAt: now
            ),
            .init(
                videoID: "CCCCCCCCCCC",
                title: "Fresh Two",
                channelTitle: "Channel Two",
                channelID: "UC-TWO",
                category: "Stories",
                durationSeconds: 210,
                thumbnailURL: nil,
                publishedAt: now
            )
        ]

        let discovery = CoordinatorDiscoveryStub(suggestions: suggestions)
        let importer = CoordinatorImporterStub(contentsByVideoID: [
            "BBBBBBBBBBB": makeImportedContent(videoID: "BBBBBBBBBBB", channelID: "UC-ONE"),
            "CCCCCCCCCCC": makeImportedContent(videoID: "CCCCCCCCCCC", channelID: "UC-TWO")
        ])

        let coordinator = AutoImportCoordinator(
            discoveryService: discovery,
            importService: importer,
            defaults: defaults,
            now: { now }
        )

        let summary = await coordinator.importSmartPack(modelContext: context)
        XCTAssertEqual(summary.mode, .smartPack)
        XCTAssertEqual(summary.targetCount, 3)
        XCTAssertEqual(summary.attemptedCount, 2)
        XCTAssertEqual(summary.importedCount, 2)
        XCTAssertEqual(summary.repeatedImportCount, 0)
        XCTAssertEqual(summary.skippedDuplicates, 1)
        XCTAssertNotNil(summary.batchID)

        let stored = try context.fetch(FetchDescriptor<Document>())
        let newDocs = stored.filter { $0.sourceVideoID == "BBBBBBBBBBB" || $0.sourceVideoID == "CCCCCCCCCCC" }
        XCTAssertEqual(newDocs.count, 2)
        XCTAssertTrue(newDocs.allSatisfy { $0.importMode == .smartPack })
        XCTAssertTrue(newDocs.allSatisfy { $0.autoBatchID == summary.batchID })
        XCTAssertEqual(newDocs.first(where: { $0.sourceVideoID == "BBBBBBBBBBB" })?.sourceChannelID, "UC-ONE")
        XCTAssertEqual(newDocs.first(where: { $0.sourceVideoID == "CCCCCCCCCCC" })?.sourceChannelID, "UC-TWO")
        XCTAssertEqual(
            newDocs.first(where: { $0.sourceVideoID == "BBBBBBBBBBB" })?.subtitleCues.map(\.sourceText),
            ["Transcript BBBBBBBBBBB"]
        )
        XCTAssertEqual(
            newDocs.first(where: { $0.sourceVideoID == "CCCCCCCCCCC" })?.subtitleCues.map(\.sourceText),
            ["Transcript CCCCCCCCCCC"]
        )
    }

    func testImportSmartPackUsesFixedThreeLessonTarget() async throws {
        let defaults = UserDefaults(suiteName: "AutoImportCoordinatorTests.\(UUID().uuidString)")!
        defaults.set(SupportedLanguage.kannada.rawValue, forKey: StudyLanguageSettingsStore.studyLanguageKey)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let container = try makeContainer()
        let context = ModelContext(container)

        let discovery = CoordinatorDiscoveryStub(suggestions: [
            .init(
                videoID: "GGGGGGGGGGG",
                title: "Queue Target",
                channelTitle: "Channel",
                channelID: "UC-CONFIG",
                category: "Basics",
                durationSeconds: 120,
                thumbnailURL: nil,
                publishedAt: now
            )
        ])
        let importer = CoordinatorImporterStub(contentsByVideoID: [
            "GGGGGGGGGGG": makeImportedContent(videoID: "GGGGGGGGGGG", channelID: "UC-CONFIG")
        ])

        let coordinator = AutoImportCoordinator(
            discoveryService: discovery,
            importService: importer,
            defaults: defaults,
            now: { now }
        )

        let summary = await coordinator.importSmartPack(modelContext: context)
        XCTAssertEqual(summary.targetCount, 3)
    }

    func testImportSmartPackFallsBackToRepeatCandidatesWhenEnabled() async throws {
        let defaults = UserDefaults(suiteName: "AutoImportCoordinatorTests.\(UUID().uuidString)")!
        defaults.set(SupportedLanguage.kannada.rawValue, forKey: StudyLanguageSettingsStore.studyLanguageKey)
        defaults.set(true, forKey: AutoImportSettings.allowRepeatImportsKey)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let container = try makeContainer()
        let context = ModelContext(container)

        let existing = Document(
            title: "Existing",
            body: "Body",
            languageCode: .kannada,
            createdAt: now,
            updatedAt: now,
            sourceType: .youtube,
            sourceVideoID: "AAAAAAAAAAA",
            sourceChannel: "Channel",
            sourceChannelID: "UC-EXISTING"
        )
        context.insert(existing)
        try context.save()

        let discovery = CoordinatorDiscoveryStub(suggestions: [
            .init(
                videoID: "AAAAAAAAAAA",
                title: "Repeat Candidate",
                channelTitle: "Existing Channel",
                channelID: "UC-EXISTING",
                category: "Basics",
                durationSeconds: 600,
                thumbnailURL: nil,
                publishedAt: now
            )
        ])
        let importer = CoordinatorImporterStub(contentsByVideoID: [
            "AAAAAAAAAAA": makeImportedContent(videoID: "AAAAAAAAAAA", channelID: "UC-EXISTING")
        ])

        let coordinator = AutoImportCoordinator(
            discoveryService: discovery,
            importService: importer,
            defaults: defaults,
            now: { now }
        )

        let summary = await coordinator.importSmartPack(modelContext: context)
        XCTAssertEqual(summary.importedCount, 1)
        XCTAssertEqual(summary.repeatedImportCount, 1)
        XCTAssertEqual(summary.skippedDuplicates, 0)
    }

    func testAutoTopUpFallsBackToRepeatImportsWhenEnabled() async throws {
        let defaults = UserDefaults(suiteName: "AutoImportCoordinatorTests.\(UUID().uuidString)")!
        defaults.set(SupportedLanguage.kannada.rawValue, forKey: StudyLanguageSettingsStore.studyLanguageKey)
        defaults.set(true, forKey: AutoImportSettings.allowRepeatImportsKey)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let container = try makeContainer()
        let context = ModelContext(container)

        let existing = Document(
            title: "Existing",
            body: "Body",
            languageCode: .kannada,
            createdAt: now,
            updatedAt: now,
            sourceType: .youtube,
            sourceURL: "https://www.youtube.com/watch?v=AAAAAAAAAAA",
            sourceVideoID: "AAAAAAAAAAA",
            sourceChannel: "Existing Channel",
            sourceChannelID: "UC-EXISTING"
        )
        context.insert(existing)
        try context.save()

        let discovery = CoordinatorDiscoveryStub(suggestions: [
            .init(
                videoID: "AAAAAAAAAAA",
                title: "Repeat Candidate",
                channelTitle: "Existing Channel",
                channelID: "UC-EXISTING",
                category: "Basics",
                durationSeconds: 120,
                thumbnailURL: nil,
                publishedAt: now
            )
        ])
        let importer = CoordinatorImporterStub(contentsByVideoID: [
            "AAAAAAAAAAA": makeImportedContent(videoID: "AAAAAAAAAAA", channelID: "UC-EXISTING")
        ])

        let coordinator = AutoImportCoordinator(
            discoveryService: discovery,
            importService: importer,
            defaults: defaults,
            now: { now }
        )

        let summary = await coordinator.performAutoTopUpIfNeeded(
            modelContext: context,
            trigger: .libraryEntry
        )
        XCTAssertEqual(summary?.importedCount, 1)
        XCTAssertEqual(summary?.repeatedImportCount, 1)
        XCTAssertEqual(summary?.skippedDuplicates, 0)
    }

    func testPerformAutoTopUpWritesRunMetadataWhenImportSucceeds() async throws {
        let defaults = UserDefaults(suiteName: "AutoImportCoordinatorTests.\(UUID().uuidString)")!
        defaults.set(SupportedLanguage.kannada.rawValue, forKey: StudyLanguageSettingsStore.studyLanguageKey)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let container = try makeContainer()
        let context = ModelContext(container)

        let discovery = CoordinatorDiscoveryStub(suggestions: [
            .init(
                videoID: "DDDDDDDDDDD",
                title: "Auto Fresh",
                channelTitle: "Auto Channel",
                channelID: "UC-AUTO",
                category: "Basics",
                durationSeconds: 120,
                thumbnailURL: nil,
                publishedAt: now
            )
        ])
        let importer = CoordinatorImporterStub(contentsByVideoID: [
            "DDDDDDDDDDD": makeImportedContent(videoID: "DDDDDDDDDDD", channelID: "UC-AUTO")
        ])

        let coordinator = AutoImportCoordinator(
            discoveryService: discovery,
            importService: importer,
            defaults: defaults,
            now: { now }
        )

        let summary = await coordinator.performAutoTopUpIfNeeded(
            modelContext: context,
            trigger: .appLaunch
        )
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.mode, .autoTopUp)
        XCTAssertEqual(summary?.importedCount, 1)

        XCTAssertNotNil(defaults.object(forKey: AutoImportSettings.lastAutoTopUpAttemptAtKey(for: .kannada)) as? Date)
        XCTAssertNotNil(defaults.object(forKey: AutoImportSettings.lastAutoTopUpSuccessAtKey(for: .kannada)) as? Date)
        XCTAssertEqual(
            defaults.string(forKey: AutoImportSettings.lastAutoTopUpBatchIDKey(for: .kannada)),
            summary?.batchID
        )

        let stored = try context.fetch(FetchDescriptor<Document>())
        let imported = try XCTUnwrap(stored.first(where: { $0.sourceVideoID == "DDDDDDDDDDD" }))
        XCTAssertEqual(imported.importMode, .autoTopUp)
        XCTAssertEqual(imported.autoBatchID, summary?.batchID)
    }

    func testPerformAutoTopUpSkipsWhenUnreadThresholdReached() async throws {
        let defaults = UserDefaults(suiteName: "AutoImportCoordinatorTests.\(UUID().uuidString)")!
        defaults.set(SupportedLanguage.kannada.rawValue, forKey: StudyLanguageSettingsStore.studyLanguageKey)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let container = try makeContainer()
        let context = ModelContext(container)

        for idx in 0..<3 {
            let doc = Document(
                title: "Unread \(idx)",
                body: "Body",
                languageCode: .kannada,
                createdAt: now,
                updatedAt: now,
                sourceType: .youtube,
                sourceVideoID: String(format: "UNREAD%05d", idx),
                sourceChannel: "Channel",
                sourceChannelID: "UC-THRESHOLD"
            )
            context.insert(doc)
        }
        try context.save()

        let discovery = CoordinatorDiscoveryStub(suggestions: [
            .init(
                videoID: "EEEEEEEEEEE",
                title: "Should Not Import",
                channelTitle: "Channel",
                channelID: "UC-SHOULD-NOT-RUN",
                category: "Basics",
                durationSeconds: 120,
                thumbnailURL: nil,
                publishedAt: now
            )
        ])
        let importer = CoordinatorImporterStub(contentsByVideoID: [
            "EEEEEEEEEEE": makeImportedContent(videoID: "EEEEEEEEEEE", channelID: "UC-SHOULD-NOT-RUN")
        ])

        let coordinator = AutoImportCoordinator(
            discoveryService: discovery,
            importService: importer,
            defaults: defaults,
            now: { now }
        )

        let summary = await coordinator.performAutoTopUpIfNeeded(
            modelContext: context,
            trigger: .libraryEntry
        )
        XCTAssertNil(summary)
        let discoveryCalls = await discovery.loadCallCount()
        let importerCalls = await importer.importCallCount()
        XCTAssertEqual(discoveryCalls, 0)
        XCTAssertEqual(importerCalls, 0)
    }

    func testPerformAutoTopUpDoesNotWriteSuccessMetadataWhenImportsFail() async throws {
        let defaults = UserDefaults(suiteName: "AutoImportCoordinatorTests.\(UUID().uuidString)")!
        defaults.set(SupportedLanguage.kannada.rawValue, forKey: StudyLanguageSettingsStore.studyLanguageKey)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let container = try makeContainer()
        let context = ModelContext(container)

        let discovery = CoordinatorDiscoveryStub(suggestions: [
            .init(
                videoID: "FFFFFFFFFFF",
                title: "Will Fail",
                channelTitle: "Broken Channel",
                channelID: "UC-BROKEN",
                category: "Basics",
                durationSeconds: 120,
                thumbnailURL: nil,
                publishedAt: now
            )
        ])
        let importer = CoordinatorImporterStub(contentsByVideoID: [:])

        let coordinator = AutoImportCoordinator(
            discoveryService: discovery,
            importService: importer,
            defaults: defaults,
            now: { now }
        )

        let summary = await coordinator.performAutoTopUpIfNeeded(
            modelContext: context,
            trigger: .appLaunch
        )
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.mode, .autoTopUp)
        XCTAssertEqual(summary?.attemptedCount, 1)
        XCTAssertEqual(summary?.importedCount, 0)
        XCTAssertNil(summary?.batchID)

        XCTAssertNotNil(defaults.object(forKey: AutoImportSettings.lastAutoTopUpAttemptAtKey(for: .kannada)) as? Date)
        XCTAssertNil(defaults.object(forKey: AutoImportSettings.lastAutoTopUpSuccessAtKey(for: .kannada)) as? Date)
        XCTAssertNil(defaults.string(forKey: AutoImportSettings.lastAutoTopUpBatchIDKey(for: .kannada)))

        let stored = try context.fetch(FetchDescriptor<Document>())
        XCTAssertTrue(stored.isEmpty)
    }

    func testAutoTopUpForcesDiscoveryRefreshWhenLibraryIsEmpty() async throws {
        let defaults = UserDefaults(suiteName: "AutoImportCoordinatorTests.\(UUID().uuidString)")!
        defaults.set(SupportedLanguage.kannada.rawValue, forKey: StudyLanguageSettingsStore.studyLanguageKey)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let container = try makeContainer()
        let context = ModelContext(container)

        let discovery = CoordinatorDiscoveryStub(suggestions: [
            .init(
                videoID: "JJJJJJJJJJJ",
                title: "Fresh Candidate",
                channelTitle: "Channel",
                channelID: "UC-J",
                category: "Basics",
                durationSeconds: 600,
                thumbnailURL: nil,
                publishedAt: now
            )
        ])
        let importer = CoordinatorImporterStub(contentsByVideoID: [
            "JJJJJJJJJJJ": makeImportedContent(videoID: "JJJJJJJJJJJ", channelID: "UC-J")
        ])

        let coordinator = AutoImportCoordinator(
            discoveryService: discovery,
            importService: importer,
            defaults: defaults,
            now: { now }
        )

        _ = await coordinator.performAutoTopUpIfNeeded(
            modelContext: context,
            trigger: .appLaunch
        )

        let forceRefreshFlags = await discovery.forceRefreshArguments()
        XCTAssertEqual(forceRefreshFlags, [true])
    }

    func testImportSmartPackSkipsHistoricallyImportedVideoIDs() async throws {
        let defaults = UserDefaults(suiteName: "AutoImportCoordinatorTests.\(UUID().uuidString)")!
        defaults.set(SupportedLanguage.kannada.rawValue, forKey: StudyLanguageSettingsStore.studyLanguageKey)
        defaults.set(["OLDOLDOLD01"], forKey: AutoImportSettings.historicalImportedVideoIDsKey(for: .kannada))
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let container = try makeContainer()
        let context = ModelContext(container)

        let discovery = CoordinatorDiscoveryStub(suggestions: [
            .init(
                videoID: "OLDOLDOLD01",
                title: "Old Historical",
                channelTitle: "Archive Channel",
                channelID: "UC-ARCHIVE",
                category: "Basics",
                durationSeconds: 600,
                thumbnailURL: nil,
                publishedAt: now
            ),
            .init(
                videoID: "NEWNEWNEW01",
                title: "Fresh Historical",
                channelTitle: "Fresh Channel",
                channelID: "UC-FRESH",
                category: "Conversation",
                durationSeconds: 600,
                thumbnailURL: nil,
                publishedAt: now
            )
        ])
        let importer = CoordinatorImporterStub(contentsByVideoID: [
            "NEWNEWNEW01": makeImportedContent(videoID: "NEWNEWNEW01", channelID: "UC-FRESH")
        ])

        let coordinator = AutoImportCoordinator(
            discoveryService: discovery,
            importService: importer,
            defaults: defaults,
            now: { now }
        )

        let summary = await coordinator.importSmartPack(modelContext: context)
        XCTAssertEqual(summary.importedCount, 1)

        let discoveryExistingIDs = await discovery.existingVideoIDArguments().first ?? []
        XCTAssertTrue(discoveryExistingIDs.contains("OLDOLDOLD01"))

        let storedHistory = Set(
            defaults.stringArray(forKey: AutoImportSettings.historicalImportedVideoIDsKey(for: .kannada)) ?? []
        )
        XCTAssertTrue(storedHistory.contains("OLDOLDOLD01"))
        XCTAssertTrue(storedHistory.contains("NEWNEWNEW01"))
    }

    func testImportSmartPackTracksFirstImportedDocumentID() async throws {
        let defaults = UserDefaults(suiteName: "AutoImportCoordinatorTests.\(UUID().uuidString)")!
        defaults.set(SupportedLanguage.kannada.rawValue, forKey: StudyLanguageSettingsStore.studyLanguageKey)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let container = try makeContainer()
        let context = ModelContext(container)

        let discovery = CoordinatorDiscoveryStub(suggestions: [
            .init(
                videoID: "FIRSTFIRST01",
                title: "First Candidate",
                channelTitle: "Channel One",
                channelID: "UC-ONE",
                category: "Basics",
                durationSeconds: 180,
                thumbnailURL: nil,
                publishedAt: now
            ),
            .init(
                videoID: "SECONDNEXT1",
                title: "Second Candidate",
                channelTitle: "Channel Two",
                channelID: "UC-TWO",
                category: "Grammar",
                durationSeconds: 180,
                thumbnailURL: nil,
                publishedAt: now.addingTimeInterval(-60)
            )
        ])
        let importer = CoordinatorImporterStub(contentsByVideoID: [
            "FIRSTFIRST01": makeImportedContent(videoID: "FIRSTFIRST01", channelID: "UC-ONE"),
            "SECONDNEXT1": makeImportedContent(videoID: "SECONDNEXT1", channelID: "UC-TWO")
        ])

        let coordinator = AutoImportCoordinator(
            discoveryService: discovery,
            importService: importer,
            defaults: defaults,
            now: { now }
        )

        let summary = await coordinator.importSmartPack(modelContext: context)
        let firstID = try XCTUnwrap(summary.firstImportedDocumentID)
        let stored = try context.fetch(FetchDescriptor<Document>())
        let firstDocument = try XCTUnwrap(stored.first(where: { $0.id == firstID }))

        XCTAssertEqual(firstDocument.sourceVideoID, "FIRSTFIRST01")
        XCTAssertEqual(summary.importedCount, 2)
    }

    func testImportSmartPackSkipsDuplicateVideoIDsWithinSameRun() async throws {
        let defaults = UserDefaults(suiteName: "AutoImportCoordinatorTests.\(UUID().uuidString)")!
        defaults.set(SupportedLanguage.kannada.rawValue, forKey: StudyLanguageSettingsStore.studyLanguageKey)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let container = try makeContainer()
        let context = ModelContext(container)

        let duplicateVideoID = "DUPEDUPE001"
        let discovery = CoordinatorDiscoveryStub(suggestions: [
            .init(
                videoID: duplicateVideoID,
                title: "Duplicate First Listing",
                channelTitle: "Channel",
                channelID: "UC-DUPE",
                category: "Basics",
                durationSeconds: 180,
                thumbnailURL: nil,
                publishedAt: now
            ),
            .init(
                videoID: duplicateVideoID,
                title: "Duplicate Second Listing",
                channelTitle: "Channel",
                channelID: "UC-DUPE",
                category: "Basics",
                durationSeconds: 180,
                thumbnailURL: nil,
                publishedAt: now.addingTimeInterval(-30)
            )
        ])
        let importer = CoordinatorImporterStub(contentsByVideoID: [
            duplicateVideoID: makeImportedContent(videoID: duplicateVideoID, channelID: "UC-DUPE")
        ])

        let coordinator = AutoImportCoordinator(
            discoveryService: discovery,
            importService: importer,
            defaults: defaults,
            now: { now }
        )

        let summary = await coordinator.importSmartPack(modelContext: context)
        XCTAssertEqual(summary.importedCount, 1)
        XCTAssertEqual(summary.attemptedCount, 1)
        XCTAssertEqual(summary.skippedDuplicates, 1)

        let importerCalls = await importer.importCallCount()
        XCTAssertEqual(importerCalls, 1)
    }
}

private extension AutoImportCoordinatorTests {
    func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Document.self, configurations: configuration)
    }

    func makeImportedContent(videoID: String, channelID: String) -> ImportedYouTubeContent {
        ImportedYouTubeContent(
            videoID: videoID,
            language: .kannada,
            title: "Imported \(videoID)",
            channelTitle: "Channel \(videoID)",
            channelID: channelID,
            transcript: "Transcript \(videoID)",
            subtitleCues: [
                TimedSubtitleCue(startTime: 0, duration: 1.0, sourceText: "Transcript \(videoID)")
            ],
            durationSeconds: 180,
            thumbnailURL: nil
        )
    }
}

private actor CoordinatorDiscoveryStub: AutoImportSuggesting {
    private let suggestions: [YouTubeSuggestedVideo]
    private var calls = 0
    private var forceRefreshFlags: [Bool] = []
    private var existingVideoIDArgumentsLog: [Set<String>] = []

    init(suggestions: [YouTubeSuggestedVideo]) {
        self.suggestions = suggestions
    }

    func loadSuggestions(
        existingVideoIDs: Set<String>,
        forceRefresh: Bool,
        language: SupportedLanguage
    ) async -> [YouTubeSuggestedVideo] {
        calls += 1
        forceRefreshFlags.append(forceRefresh)
        existingVideoIDArgumentsLog.append(existingVideoIDs)
        return suggestions
    }

    func loadCallCount() -> Int {
        calls
    }

    func forceRefreshArguments() -> [Bool] {
        forceRefreshFlags
    }

    func existingVideoIDArguments() -> [Set<String>] {
        existingVideoIDArgumentsLog
    }
}

private actor CoordinatorImporterStub: AutoImportVideoImporting {
    private let contentsByVideoID: [String: ImportedYouTubeContent]
    private var calls = 0

    init(contentsByVideoID: [String: ImportedYouTubeContent]) {
        self.contentsByVideoID = contentsByVideoID
    }

    func importVideo(videoID: String, language: SupportedLanguage) async throws -> ImportedYouTubeContent {
        calls += 1
        guard let content = contentsByVideoID[videoID] else {
            throw YouTubeImportError.networkFailure
        }
        return ImportedYouTubeContent(
            videoID: content.videoID,
            language: language,
            title: content.title,
            channelTitle: content.channelTitle,
            channelID: content.channelID,
            transcript: content.transcript,
            subtitleCues: content.subtitleCues,
            durationSeconds: content.durationSeconds,
            thumbnailURL: content.thumbnailURL
        )
    }

    func importCallCount() -> Int {
        calls
    }
}
