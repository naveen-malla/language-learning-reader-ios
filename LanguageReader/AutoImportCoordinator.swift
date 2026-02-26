import Foundation
import SwiftData

protocol AutoImportSuggesting: Sendable {
    func loadSuggestions(
        existingVideoIDs: Set<String>,
        forceRefresh: Bool
    ) async -> [YouTubeSuggestedVideo]
}

protocol AutoImportVideoImporting: Sendable {
    func importVideo(videoID: String) async throws -> ImportedYouTubeContent
}

struct AutoImportRunSummary {
    let mode: DocumentImportMode
    let trigger: AutoImportTrigger
    let targetCount: Int
    let attemptedCount: Int
    let importedCount: Int
    let skippedDuplicates: Int
    let batchID: String?
    let firstImportedDocumentID: UUID?

    var isPartial: Bool {
        importedCount < targetCount
    }

    var isSuccessful: Bool {
        let minimumSuccess = min(4, targetCount)
        return importedCount >= minimumSuccess
    }

    var statusMessage: String {
        switch mode {
        case .smartPack:
            if importedCount == 0 {
                return "No new Kannada lessons found right now."
            }
            if isSuccessful {
                return "Imported \(importedCount) lessons for your next 2-3 days."
            }
            return "Imported \(importedCount) lessons (partial pack)."
        case .autoTopUp:
            if importedCount == 0 {
                return "Auto top-up found no new lessons."
            }
            return "Auto top-up imported \(importedCount) lessons."
        case .manual:
            return "Imported \(importedCount) lessons."
        }
    }
}

@MainActor
final class AutoImportCoordinator {
    static let shared = AutoImportCoordinator()

    private let discoveryService: any AutoImportSuggesting
    private let importService: any AutoImportVideoImporting
    private let defaults: UserDefaults
    private let now: () -> Date

    init(
        discoveryService: any AutoImportSuggesting = YouTubeDiscoveryService.shared,
        importService: any AutoImportVideoImporting = YouTubeImportService.shared,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.discoveryService = discoveryService
        self.importService = importService
        self.defaults = defaults
        self.now = now
    }

    func importSmartPack(modelContext: ModelContext) async -> AutoImportRunSummary {
        let documents = fetchDocuments(modelContext: modelContext)
        let targetCount = AutoImportSettings.smartPackTargetCount
        let summary = await runImportBatch(
            mode: .smartPack,
            trigger: .libraryEntry,
            targetCount: targetCount,
            modelContext: modelContext,
            documents: documents,
            forceDiscoveryRefresh: true
        )
        defaults.set(now(), forKey: "auto_import.last_smart_pack_at.v1")
        return summary
    }

    func performAutoTopUpIfNeeded(
        modelContext: ModelContext,
        trigger: AutoImportTrigger
    ) async -> AutoImportRunSummary? {
        let documents = fetchDocuments(modelContext: modelContext)
        let unreadCount = unreadImportedLessonCount(documents: documents)

        let lastAttempt = defaults.object(forKey: AutoImportSettings.lastAutoTopUpAttemptAtKey) as? Date
        guard Self.shouldRunAutoTopUp(
            enabled: effectiveAutoTopUpEnabled,
            now: now(),
            lastAttemptAt: lastAttempt,
            cooldownHours: AutoImportSettings.defaultCooldownHours,
            unreadCount: unreadCount,
            unreadThreshold: AutoImportSettings.defaultUnreadThreshold
        ) else {
            return nil
        }

        defaults.set(now(), forKey: AutoImportSettings.lastAutoTopUpAttemptAtKey)

        let targetCount = max(1, AutoImportSettings.smartPackTargetCount - unreadCount)
        let summary = await runImportBatch(
            mode: .autoTopUp,
            trigger: trigger,
            targetCount: targetCount,
            modelContext: modelContext,
            documents: documents,
            forceDiscoveryRefresh: false
        )

        if summary.importedCount > 0 {
            defaults.set(now(), forKey: AutoImportSettings.lastAutoTopUpSuccessAtKey)
            defaults.set(summary.batchID, forKey: AutoImportSettings.lastAutoTopUpBatchIDKey)
        }

        return summary
    }

    static func shouldRunAutoTopUp(
        enabled: Bool,
        now: Date,
        lastAttemptAt: Date?,
        cooldownHours: Int,
        unreadCount: Int,
        unreadThreshold: Int
    ) -> Bool {
        guard enabled else { return false }
        guard unreadCount < unreadThreshold else { return false }

        guard let lastAttemptAt else { return true }
        let cooldown = TimeInterval(cooldownHours * 3600)
        return now.timeIntervalSince(lastAttemptAt) >= cooldown
    }

    private var effectiveAutoTopUpEnabled: Bool {
        if defaults.object(forKey: AutoImportSettings.autoTopUpEnabledKey) == nil {
            return AutoImportSettings.defaultAutoTopUpEnabled
        }
        return defaults.bool(forKey: AutoImportSettings.autoTopUpEnabledKey)
    }

    private func runImportBatch(
        mode: DocumentImportMode,
        trigger: AutoImportTrigger,
        targetCount: Int,
        modelContext: ModelContext,
        documents: [Document],
        forceDiscoveryRefresh: Bool
    ) async -> AutoImportRunSummary {
        guard targetCount > 0 else {
            return AutoImportRunSummary(
                mode: mode,
                trigger: trigger,
                targetCount: 0,
                attemptedCount: 0,
                importedCount: 0,
                skippedDuplicates: 0,
                batchID: nil,
                firstImportedDocumentID: nil
            )
        }

        var existingVideoIDs = Set(documents.compactMap(\.sourceVideoID))
        let candidates = await discoveryService.loadSuggestions(
            existingVideoIDs: existingVideoIDs,
            forceRefresh: forceDiscoveryRefresh
        )

        var attemptedCount = 0
        var importedCount = 0
        var skippedDuplicates = 0
        var firstImportedDocumentID: UUID?
        let batchID = UUID().uuidString

        for candidate in candidates {
            if importedCount >= targetCount {
                break
            }

            if existingVideoIDs.contains(candidate.videoID) {
                skippedDuplicates += 1
                continue
            }

            attemptedCount += 1

            do {
                let content = try await importService.importVideo(videoID: candidate.videoID)
                let document = Document(
                    title: content.title,
                    body: content.transcript,
                    createdAt: now(),
                    updatedAt: now(),
                    sourceType: .youtube,
                    sourceURL: content.watchURL.absoluteString,
                    sourceVideoID: content.videoID,
                    sourceChannel: content.channelTitle,
                    sourceChannelID: content.channelID ?? candidate.channelID,
                    sourceCategory: candidate.category,
                    sourceDurationSeconds: content.durationSeconds,
                    thumbnailURL: content.thumbnailURL?.absoluteString,
                    importMode: mode,
                    autoBatchID: mode == .manual ? nil : batchID
                )

                modelContext.insert(document)
                existingVideoIDs.insert(candidate.videoID)
                importedCount += 1
                if firstImportedDocumentID == nil {
                    firstImportedDocumentID = document.id
                }
            } catch {
                continue
            }
        }

        if importedCount > 0 {
            try? modelContext.save()
        }

        return AutoImportRunSummary(
            mode: mode,
            trigger: trigger,
            targetCount: targetCount,
            attemptedCount: attemptedCount,
            importedCount: importedCount,
            skippedDuplicates: skippedDuplicates,
            batchID: importedCount > 0 ? batchID : nil,
            firstImportedDocumentID: firstImportedDocumentID
        )
    }

    private func fetchDocuments(modelContext: ModelContext) -> [Document] {
        let descriptor = FetchDescriptor<Document>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func unreadImportedLessonCount(documents: [Document]) -> Int {
        documents.filter { document in
            document.sourceType == .youtube && document.isOpened == false
        }.count
    }
}

extension YouTubeDiscoveryService: AutoImportSuggesting {}
extension YouTubeImportService: AutoImportVideoImporting {}
