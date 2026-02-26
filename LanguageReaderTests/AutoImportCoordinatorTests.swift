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
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let container = try makeContainer()
        let context = ModelContext(container)

        let existing = Document(
            title: "Existing",
            body: "Body",
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
        XCTAssertEqual(summary.targetCount, 5)
        XCTAssertEqual(summary.attemptedCount, 2)
        XCTAssertEqual(summary.importedCount, 2)
        XCTAssertEqual(summary.skippedDuplicates, 1)
        XCTAssertNotNil(summary.batchID)

        let stored = try context.fetch(FetchDescriptor<Document>())
        let newDocs = stored.filter { $0.sourceVideoID == "BBBBBBBBBBB" || $0.sourceVideoID == "CCCCCCCCCCC" }
        XCTAssertEqual(newDocs.count, 2)
        XCTAssertTrue(newDocs.allSatisfy { $0.importMode == .smartPack })
        XCTAssertTrue(newDocs.allSatisfy { $0.autoBatchID == summary.batchID })
        XCTAssertEqual(newDocs.first(where: { $0.sourceVideoID == "BBBBBBBBBBB" })?.sourceChannelID, "UC-ONE")
        XCTAssertEqual(newDocs.first(where: { $0.sourceVideoID == "CCCCCCCCCCC" })?.sourceChannelID, "UC-TWO")
    }

    func testPerformAutoTopUpWritesRunMetadataWhenImportSucceeds() async throws {
        let defaults = UserDefaults(suiteName: "AutoImportCoordinatorTests.\(UUID().uuidString)")!
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

        XCTAssertNotNil(defaults.object(forKey: AutoImportSettings.lastAutoTopUpAttemptAtKey) as? Date)
        XCTAssertNotNil(defaults.object(forKey: AutoImportSettings.lastAutoTopUpSuccessAtKey) as? Date)
        XCTAssertEqual(
            defaults.string(forKey: AutoImportSettings.lastAutoTopUpBatchIDKey),
            summary?.batchID
        )

        let stored = try context.fetch(FetchDescriptor<Document>())
        let imported = try XCTUnwrap(stored.first(where: { $0.sourceVideoID == "DDDDDDDDDDD" }))
        XCTAssertEqual(imported.importMode, .autoTopUp)
        XCTAssertEqual(imported.autoBatchID, summary?.batchID)
    }

    func testPerformAutoTopUpSkipsWhenUnreadThresholdReached() async throws {
        let defaults = UserDefaults(suiteName: "AutoImportCoordinatorTests.\(UUID().uuidString)")!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let container = try makeContainer()
        let context = ModelContext(container)

        for idx in 0..<3 {
            let doc = Document(
                title: "Unread \(idx)",
                body: "Body",
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
}

private extension AutoImportCoordinatorTests {
    func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Document.self, configurations: configuration)
    }

    func makeImportedContent(videoID: String, channelID: String) -> ImportedYouTubeContent {
        ImportedYouTubeContent(
            videoID: videoID,
            title: "Imported \(videoID)",
            channelTitle: "Channel \(videoID)",
            channelID: channelID,
            transcript: "Transcript \(videoID)",
            durationSeconds: 180,
            thumbnailURL: nil
        )
    }
}

private actor CoordinatorDiscoveryStub: AutoImportSuggesting {
    private let suggestions: [YouTubeSuggestedVideo]
    private var calls = 0

    init(suggestions: [YouTubeSuggestedVideo]) {
        self.suggestions = suggestions
    }

    func loadSuggestions(
        existingVideoIDs: Set<String>,
        forceRefresh: Bool
    ) async -> [YouTubeSuggestedVideo] {
        calls += 1
        return suggestions
    }

    func loadCallCount() -> Int {
        calls
    }
}

private actor CoordinatorImporterStub: AutoImportVideoImporting {
    private let contentsByVideoID: [String: ImportedYouTubeContent]
    private var calls = 0

    init(contentsByVideoID: [String: ImportedYouTubeContent]) {
        self.contentsByVideoID = contentsByVideoID
    }

    func importVideo(videoID: String) async throws -> ImportedYouTubeContent {
        calls += 1
        guard let content = contentsByVideoID[videoID] else {
            throw YouTubeImportError.networkFailure
        }
        return content
    }

    func importCallCount() -> Int {
        calls
    }
}
