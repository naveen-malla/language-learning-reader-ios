import Foundation
import SwiftData

protocol AutoImportSuggesting: Sendable {
    func loadSuggestions(
        existingVideoIDs: Set<String>,
        forceRefresh: Bool,
        language: SupportedLanguage
    ) async -> [YouTubeSuggestedVideo]
}

protocol AutoImportVideoImporting: Sendable {
    func importVideo(videoID: String, language: SupportedLanguage) async throws -> ImportedYouTubeContent
}

struct AutoImportRunSummary {
    let mode: DocumentImportMode
    let trigger: AutoImportTrigger
    let targetCount: Int
    let attemptedCount: Int
    let importedCount: Int
    let repeatedImportCount: Int
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
                if attemptedCount == 0 {
                    return "Feed refreshed. No importable lessons found in this cycle."
                }
                return "Checked \(attemptedCount) candidates, but none passed subtitle and duration checks."
            }
            if repeatedImportCount == importedCount {
                return "Added \(importedCount) lessons from your existing feed while waiting for fresh uploads."
            }
            if repeatedImportCount > 0 {
                return "Added \(importedCount) lessons (\(repeatedImportCount) from existing feed)."
            }
            if isSuccessful {
                return "Added \(importedCount) fresh lessons to your queue."
            }
            return "Added \(importedCount) lessons (\(targetCount - importedCount) still missing)."
        case .autoTopUp:
            if importedCount == 0 {
                if attemptedCount == 0 {
                    return "Auto top-up left queue unchanged: no feed candidates available."
                }
                return "Auto top-up checked \(attemptedCount) items, but none passed subtitle and duration checks."
            }
            if repeatedImportCount > 0 {
                return "Auto top-up added \(importedCount) lessons (\(repeatedImportCount) from existing feed)."
            }
            return "Auto top-up added \(importedCount) fresh lessons."
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
            forceDiscoveryRefresh: true,
            allowRepeatImports: effectiveAllowRepeatImports
        )
        defaults.set(now(), forKey: "auto_import.last_smart_pack_at.v1")
        return summary
    }

    func performAutoTopUpIfNeeded(
        modelContext: ModelContext,
        trigger: AutoImportTrigger
    ) async -> AutoImportRunSummary? {
        let documents = fetchDocuments(modelContext: modelContext)
        let studyLanguage = currentStudyLanguage
        let unreadCount = unreadImportedLessonCount(documents: documents, language: studyLanguage)

        let lastAttempt = defaults.object(
            forKey: AutoImportSettings.lastAutoTopUpAttemptAtKey(for: studyLanguage)
        ) as? Date
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

        defaults.set(now(), forKey: AutoImportSettings.lastAutoTopUpAttemptAtKey(for: studyLanguage))

        let targetCount = max(1, AutoImportSettings.smartPackTargetCount - unreadCount)
        let summary = await runImportBatch(
            mode: .autoTopUp,
            trigger: trigger,
            targetCount: targetCount,
            modelContext: modelContext,
            documents: documents,
            forceDiscoveryRefresh: false,
            allowRepeatImports: effectiveAllowRepeatImports
        )

        if summary.importedCount > 0 {
            defaults.set(now(), forKey: AutoImportSettings.lastAutoTopUpSuccessAtKey(for: studyLanguage))
            defaults.set(summary.batchID, forKey: AutoImportSettings.lastAutoTopUpBatchIDKey(for: studyLanguage))
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

    private var effectiveAllowRepeatImports: Bool {
        if defaults.object(forKey: AutoImportSettings.allowRepeatImportsKey) == nil {
            return AutoImportSettings.defaultAllowRepeatImports
        }
        return defaults.bool(forKey: AutoImportSettings.allowRepeatImportsKey)
    }

    private func runImportBatch(
        mode: DocumentImportMode,
        trigger: AutoImportTrigger,
        targetCount: Int,
        modelContext: ModelContext,
        documents: [Document],
        forceDiscoveryRefresh: Bool,
        allowRepeatImports: Bool
    ) async -> AutoImportRunSummary {
        let studyLanguage = currentStudyLanguage
        guard targetCount > 0 else {
            return AutoImportRunSummary(
                mode: mode,
                trigger: trigger,
                targetCount: 0,
                attemptedCount: 0,
                importedCount: 0,
                repeatedImportCount: 0,
                skippedDuplicates: 0,
                batchID: nil,
                firstImportedDocumentID: nil
            )
        }

        let batchID = UUID().uuidString
        let languageDocuments = documents.filter { $0.languageCode == studyLanguage }
        let recentChannelKeys = Self.recentlyImportedChannelKeys(from: languageDocuments)
        let libraryVideoIDs = Set(languageDocuments.compactMap(\.sourceVideoID))
        var existingVideoIDs = libraryVideoIDs
        existingVideoIDs.formUnion(historicalImportedVideoIDs(language: studyLanguage))
        // Empty library should not trust old discovery cache; force a fresh pull.
        let shouldForceDiscoveryRefresh = forceDiscoveryRefresh || libraryVideoIDs.isEmpty
        let discoveredCandidates = await discoveryService.loadSuggestions(
            existingVideoIDs: allowRepeatImports ? [] : existingVideoIDs,
            forceRefresh: shouldForceDiscoveryRefresh,
            language: studyLanguage
        )
        let freshCandidates = discoveredCandidates.filter { !existingVideoIDs.contains($0.videoID) }
        let repeatCandidates = discoveredCandidates.filter { existingVideoIDs.contains($0.videoID) }
        let repeatCandidateIDs = Set(repeatCandidates.map(\.videoID))
        let candidates = Self.prioritizeCandidates(
            freshCandidates + (allowRepeatImports ? repeatCandidates : []),
            recentChannelKeys: recentChannelKeys,
            batchID: batchID
        )

        var primaryPass: [YouTubeSuggestedVideo] = []
        var deferredPass: [YouTubeSuggestedVideo] = []
        var seenTitleFingerprints: Set<String> = []
        var seenChannelKeys = recentChannelKeys

        for candidate in candidates {
            let titleFingerprint = Self.titleFingerprint(candidate.title)
            if !titleFingerprint.isEmpty, seenTitleFingerprints.contains(titleFingerprint) {
                continue
            }

            let channelKey = Self.normalizedChannelKey(candidate)
            if !channelKey.isEmpty, seenChannelKeys.contains(channelKey) {
                deferredPass.append(candidate)
                continue
            }

            primaryPass.append(candidate)
            if !titleFingerprint.isEmpty {
                seenTitleFingerprints.insert(titleFingerprint)
            }
            if !channelKey.isEmpty {
                seenChannelKeys.insert(channelKey)
            }
        }

        for candidate in deferredPass {
            if primaryPass.count >= max(targetCount * 2, targetCount + 4) {
                break
            }

            let titleFingerprint = Self.titleFingerprint(candidate.title)
            if !titleFingerprint.isEmpty, seenTitleFingerprints.contains(titleFingerprint) {
                continue
            }

            primaryPass.append(candidate)
            if !titleFingerprint.isEmpty {
                seenTitleFingerprints.insert(titleFingerprint)
            }
        }

        let plannedCandidates = primaryPass

        var attemptedCount = 0
        var importedCount = 0
        var repeatedImportCount = 0
        var skippedDuplicates = allowRepeatImports ? 0 : repeatCandidates.count
        var firstImportedDocumentID: UUID?
        var importedVideoIDsThisRun: Set<String> = []

        for candidate in plannedCandidates {
            if importedCount >= targetCount {
                break
            }

            if existingVideoIDs.contains(candidate.videoID) {
                if !allowRepeatImports {
                    skippedDuplicates += 1
                    continue
                }
            }

            attemptedCount += 1

            do {
                let content = try await importService.importVideo(
                    videoID: candidate.videoID,
                    language: studyLanguage
                )
                let document = Document(
                    title: content.title,
                    body: content.transcript,
                    languageCode: content.language,
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
                document.subtitleCues = content.subtitleCues

                modelContext.insert(document)
                existingVideoIDs.insert(candidate.videoID)
                importedVideoIDsThisRun.insert(candidate.videoID)
                importedCount += 1
                if repeatCandidateIDs.contains(candidate.videoID) {
                    repeatedImportCount += 1
                }
                if firstImportedDocumentID == nil {
                    firstImportedDocumentID = document.id
                }
            } catch {
                continue
            }
        }

        if importedCount > 0 {
            try? modelContext.save()
            persistHistoricalImportedVideoIDs(importedVideoIDsThisRun, language: studyLanguage)
        }

        return AutoImportRunSummary(
            mode: mode,
            trigger: trigger,
            targetCount: targetCount,
            attemptedCount: attemptedCount,
            importedCount: importedCount,
            repeatedImportCount: repeatedImportCount,
            skippedDuplicates: skippedDuplicates,
            batchID: importedCount > 0 ? batchID : nil,
            firstImportedDocumentID: firstImportedDocumentID
        )
    }

    private static func normalizedTitleKey(_ title: String) -> String {
        title
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func titleFingerprint(_ title: String) -> String {
        let words = normalizedTitleKey(title).split(separator: " ")
        guard !words.isEmpty else { return "" }
        return words.prefix(10).joined(separator: " ")
    }

    private static func normalizedChannelKey(_ suggestion: YouTubeSuggestedVideo) -> String {
        if let channelID = suggestion.channelID?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !channelID.isEmpty {
            return channelID.lowercased()
        }
        return suggestion.channelTitle
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedChannelKey(from document: Document) -> String {
        if let channelID = document.sourceChannelID?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !channelID.isEmpty {
            return channelID.lowercased()
        }

        return (document.sourceChannel ?? "")
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func recentlyImportedChannelKeys(
        from documents: [Document],
        limit: Int = 20
    ) -> Set<String> {
        let recent = documents
            .filter { $0.sourceType == .youtube }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
        return Set(recent.map(normalizedChannelKey(from:)).filter { !$0.isEmpty })
    }

    private static func prioritizeCandidates(
        _ suggestions: [YouTubeSuggestedVideo],
        recentChannelKeys: Set<String>,
        batchID: String
    ) -> [YouTubeSuggestedVideo] {
        suggestions.sorted { lhs, rhs in
            let lhsChannel = normalizedChannelKey(lhs)
            let rhsChannel = normalizedChannelKey(rhs)
            let lhsIsNovel = !recentChannelKeys.contains(lhsChannel)
            let rhsIsNovel = !recentChannelKeys.contains(rhsChannel)
            if lhsIsNovel != rhsIsNovel {
                return lhsIsNovel && !rhsIsNovel
            }

            switch (lhs.publishedAt, rhs.publishedAt) {
            case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                return lhsDate > rhsDate
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                break
            }

            let lhsHash = stableHash(batchID + lhs.videoID)
            let rhsHash = stableHash(batchID + rhs.videoID)
            if lhsHash != rhsHash {
                return lhsHash < rhsHash
            }
            return lhs.videoID < rhs.videoID
        }
    }

    private static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private func fetchDocuments(modelContext: ModelContext) -> [Document] {
        let descriptor = FetchDescriptor<Document>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private var currentStudyLanguage: SupportedLanguage {
        StudyLanguageSettingsStore(defaults: defaults).studyLanguage
    }

    private func historicalImportedVideoIDs(language: SupportedLanguage) -> Set<String> {
        let stored = defaults.stringArray(
            forKey: AutoImportSettings.historicalImportedVideoIDsKey(for: language)
        ) ?? []
        return Set(stored.filter(YouTubeVideoIDParser.isValidVideoID))
    }

    private func persistHistoricalImportedVideoIDs(
        _ newIDs: Set<String>,
        language: SupportedLanguage
    ) {
        guard !newIDs.isEmpty else { return }
        var merged = historicalImportedVideoIDs(language: language)
        merged.formUnion(newIDs.filter(YouTubeVideoIDParser.isValidVideoID))
        if merged.count > AutoImportSettings.maxHistoricalVideoIDs {
            let sorted = Array(merged).sorted()
            let keep = sorted.suffix(AutoImportSettings.maxHistoricalVideoIDs)
            merged = Set(keep)
        }
        defaults.set(
            Array(merged),
            forKey: AutoImportSettings.historicalImportedVideoIDsKey(for: language)
        )
    }

    private func unreadImportedLessonCount(
        documents: [Document],
        language: SupportedLanguage
    ) -> Int {
        documents.filter { document in
            document.sourceType == .youtube && document.isOpened == false && document.languageCode == language
        }.count
    }
}

extension YouTubeDiscoveryService: AutoImportSuggesting {}
extension YouTubeImportService: AutoImportVideoImporting {}
