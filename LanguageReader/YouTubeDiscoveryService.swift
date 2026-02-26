import Foundation

struct YouTubeChannelSeed: Sendable, Hashable {
    let channelID: String
    let category: String
    let priority: Int
}

protocol YouTubeCandidateValidating: Sendable {
    func validateCandidate(
        videoID: String,
        category: String,
        publishedAt: Date?,
        fallbackTitle: String?,
        fallbackChannelTitle: String?,
        fallbackChannelID: String?
    ) async throws -> YouTubeSuggestedVideo
}

actor YouTubeDiscoveryService {
    struct FeedCandidate: Sendable {
        let videoID: String
        let title: String
        let channelTitle: String
        let channelID: String
        let category: String
        let priority: Int
        let publishedAt: Date?
    }

    static let shared = YouTubeDiscoveryService()

    static let defaultChannelSeeds: [YouTubeChannelSeed] = [
        .init(channelID: "UChsgGgFHYTBL4m0dgRc78PQ", category: "Basics", priority: 1),
        .init(channelID: "UClhQBYN17XW_lA4568Qtu3A", category: "Conversation", priority: 2),
        .init(channelID: "UCirKrUfKVP2ebtwEWCObTbw", category: "Grammar", priority: 3),
        .init(channelID: "UCqZRKIkmWX2L2iAIDjYi0Fw", category: "Short Stories", priority: 4),
        .init(channelID: "UCe-zK4ux-tMl9Y8JJJqxL7Q", category: "Alphabet", priority: 5),
        .init(channelID: "UCOG5uDioDLiIZsSmyYSKYHw", category: "Beginner Intro", priority: 6)
    ]

    private let session: URLSession
    private let cacheStore: SuggestionCacheStore
    private let validator: any YouTubeCandidateValidating
    private let now: () -> Date
    private let feedParser = YouTubeFeedParser()

    init(
        session: URLSession = .shared,
        cacheStore: SuggestionCacheStore = .shared,
        validator: any YouTubeCandidateValidating = YouTubeImportService.shared,
        now: @escaping () -> Date = Date.init
    ) {
        self.session = session
        self.cacheStore = cacheStore
        self.validator = validator
        self.now = now
    }

    func loadSuggestions(
        existingVideoIDs: Set<String>,
        forceRefresh: Bool
    ) async -> [YouTubeSuggestedVideo] {
        if !forceRefresh {
            let cached = await cacheStore.cachedSuggestions()
            if !cached.isEmpty {
                return filtered(cached, excluding: existingVideoIDs)
            }
        }

        if !forceRefresh, await cacheStore.shouldBackoff() {
            let fallback = await cacheStore.cachedSuggestions(includeExpired: true)
            return filtered(fallback, excluding: existingVideoIDs)
        }

        let seeds = await mergedSeeds()
        let feedResult = await fetchCandidates(from: seeds, existingVideoIDs: existingVideoIDs)

        let budgeted = Array(feedResult.candidates.prefix(AutoImportSettings.defaultValidationBudget))
        let validated = await validateCandidates(budgeted, existingVideoIDs: existingVideoIDs)

        if !validated.isEmpty {
            await cacheStore.saveSuggestions(validated)
            await cacheStore.recordDiscoverySuccess()
            return filtered(validated, excluding: existingVideoIDs)
        }

        if feedResult.didFail {
            await cacheStore.recordDiscoveryFailure()
        } else {
            await cacheStore.recordDiscoverySuccess()
        }

        let fallback = await cacheStore.cachedSuggestions(includeExpired: true)
        return filtered(fallback, excluding: existingVideoIDs)
    }

    func addTrustedChannel(channelID: String?, channelTitle: String?) async {
        await cacheStore.addTrustedChannel(channelID: channelID, channelTitle: channelTitle)
    }

    private func mergedSeeds() async -> [YouTubeChannelSeed] {
        var seeds = Self.defaultChannelSeeds
        let trusted = await cacheStore.trustedChannelIDs()
        let existingIDs = Set(seeds.map(\.channelID))
        for channelID in trusted where !existingIDs.contains(channelID) {
            seeds.append(YouTubeChannelSeed(channelID: channelID, category: "Personalized", priority: 0))
        }
        return seeds
    }

    private func fetchCandidates(
        from seeds: [YouTubeChannelSeed],
        existingVideoIDs: Set<String>
    ) async -> (candidates: [FeedCandidate], didFail: Bool) {
        var merged: [String: FeedCandidate] = [:]
        var didFail = false

        await withTaskGroup(of: (candidates: [FeedCandidate], failed: Bool).self) { group in
            for seed in seeds {
                group.addTask {
                    do {
                        let entries = try await self.fetchFeed(seed: seed)
                        let candidates = entries.map { entry in
                            FeedCandidate(
                                videoID: entry.videoID,
                                title: entry.title,
                                channelTitle: entry.channelTitle,
                                channelID: entry.channelID,
                                category: seed.category,
                                priority: seed.priority,
                                publishedAt: entry.publishedAt
                            )
                        }
                        return (candidates, false)
                    } catch {
                        return ([], true)
                    }
                }
            }

            for await result in group {
                didFail = didFail || result.failed
                for candidate in result.candidates where !existingVideoIDs.contains(candidate.videoID) {
                    guard let current = merged[candidate.videoID] else {
                        merged[candidate.videoID] = candidate
                        continue
                    }

                    if candidate.priority < current.priority {
                        merged[candidate.videoID] = candidate
                        continue
                    }

                    if candidate.priority == current.priority,
                       let lhs = candidate.publishedAt,
                       let rhs = current.publishedAt,
                       lhs > rhs {
                        merged[candidate.videoID] = candidate
                    }
                }
            }
        }

        let sorted = merged.values.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            switch (lhs.publishedAt, rhs.publishedAt) {
            case let (lhsDate?, rhsDate?):
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
            return lhs.videoID < rhs.videoID
        }

        return (sorted, didFail)
    }

    private func validateCandidates(
        _ candidates: [FeedCandidate],
        existingVideoIDs: Set<String>
    ) async -> [YouTubeSuggestedVideo] {
        var suggestions: [YouTubeSuggestedVideo] = []

        for (chunkIndex, chunk) in candidates.chunked(by: AutoImportSettings.defaultValidationConcurrency).enumerated() {
            let chunkSuggestions = await withTaskGroup(of: (Int, YouTubeSuggestedVideo?).self) { group in
                for (index, candidate) in chunk.enumerated() {
                    let absoluteIndex = (chunkIndex * AutoImportSettings.defaultValidationConcurrency) + index
                    group.addTask {
                        if existingVideoIDs.contains(candidate.videoID) {
                            return (absoluteIndex, nil)
                        }

                        if let cached = await self.cacheStore.cachedValidation(for: candidate.videoID) {
                            if let cachedSuggestion = cached {
                                let hydrated = await self.applyCandidateMetadata(candidate, to: cachedSuggestion)
                                return (absoluteIndex, hydrated)
                            }
                            return (absoluteIndex, nil)
                        }

                        do {
                            let suggestion = try await self.validator.validateCandidate(
                                videoID: candidate.videoID,
                                category: candidate.category,
                                publishedAt: candidate.publishedAt,
                                fallbackTitle: candidate.title,
                                fallbackChannelTitle: candidate.channelTitle,
                                fallbackChannelID: candidate.channelID
                            )
                            await self.cacheStore.storeValidationSuccess(suggestion)
                            return (absoluteIndex, suggestion)
                        } catch {
                            await self.cacheStore.storeValidationFailure(videoID: candidate.videoID)
                            return (absoluteIndex, nil)
                        }
                    }
                }

                var results: [(Int, YouTubeSuggestedVideo)] = []
                for await value in group {
                    if let suggestion = value.1 {
                        results.append((value.0, suggestion))
                    }
                }
                return results.sorted { $0.0 < $1.0 }.map(\.1)
            }

            suggestions.append(contentsOf: chunkSuggestions)
        }

        return suggestions
    }

    private func applyCandidateMetadata(_ candidate: FeedCandidate, to suggestion: YouTubeSuggestedVideo) -> YouTubeSuggestedVideo {
        YouTubeSuggestedVideo(
            videoID: suggestion.videoID,
            title: suggestion.title,
            channelTitle: suggestion.channelTitle,
            channelID: suggestion.channelID ?? candidate.channelID,
            category: candidate.category,
            durationSeconds: suggestion.durationSeconds,
            thumbnailURL: suggestion.thumbnailURL,
            publishedAt: candidate.publishedAt ?? suggestion.publishedAt
        )
    }

    private func fetchFeed(seed: YouTubeChannelSeed) async throws -> [YouTubeFeedEntry] {
        guard let url = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(seed.channelID)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return feedParser.parse(data: data)
    }

    private func filtered(
        _ suggestions: [YouTubeSuggestedVideo],
        excluding existingVideoIDs: Set<String>
    ) -> [YouTubeSuggestedVideo] {
        suggestions.filter { !existingVideoIDs.contains($0.videoID) }
    }
}

private struct YouTubeFeedEntry: Sendable {
    let videoID: String
    let title: String
    let channelTitle: String
    let channelID: String
    let publishedAt: Date?
}

private final class YouTubeFeedParser: NSObject {
    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func parse(data: Data) -> [YouTubeFeedEntry] {
        let delegate = YouTubeFeedXMLDelegate(dateParser: parseDate)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        _ = parser.parse()
        return delegate.entries
    }

    private func parseDate(_ value: String) -> Date? {
        if let date = formatter.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }
}

private final class YouTubeFeedXMLDelegate: NSObject, XMLParserDelegate {
    private struct WorkingEntry {
        var videoID = ""
        var title = ""
        var channelTitle = ""
        var channelID = ""
        var publishedAt: Date?
    }

    private enum Context {
        case none
        case title
        case videoID
        case published
        case authorName
        case authorURI
    }

    private let dateParser: (String) -> Date?
    private(set) var entries: [YouTubeFeedEntry] = []

    private var context: Context = .none
    private var currentText = ""
    private var currentEntry: WorkingEntry?
    private var insideAuthor = false

    init(dateParser: @escaping (String) -> Date?) {
        self.dateParser = dateParser
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "entry":
            currentEntry = WorkingEntry()
            context = .none
            currentText = ""
        case "author":
            insideAuthor = true
            context = .none
            currentText = ""
        case "title":
            context = .title
            currentText = ""
        case "yt:videoId", "videoId":
            context = .videoID
            currentText = ""
        case "published":
            context = .published
            currentText = ""
        case "name":
            if insideAuthor {
                context = .authorName
                currentText = ""
            }
        case "uri":
            if insideAuthor {
                context = .authorURI
                currentText = ""
            }
        default:
            context = .none
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard context != .none else { return }
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch context {
        case .title:
            currentEntry?.title = value
        case .videoID:
            currentEntry?.videoID = value
        case .published:
            currentEntry?.publishedAt = dateParser(value)
        case .authorName:
            currentEntry?.channelTitle = value
        case .authorURI:
            currentEntry?.channelID = Self.extractChannelID(fromURI: value)
        case .none:
            break
        }

        if elementName == "author" {
            insideAuthor = false
        }

        if elementName == "entry" {
            if let entry = currentEntry,
               !entry.videoID.isEmpty,
               !entry.title.isEmpty,
               !entry.channelID.isEmpty {
                entries.append(
                    YouTubeFeedEntry(
                        videoID: entry.videoID,
                        title: entry.title,
                        channelTitle: entry.channelTitle,
                        channelID: entry.channelID,
                        publishedAt: entry.publishedAt
                    )
                )
            }
            currentEntry = nil
        }

        context = .none
        currentText = ""
    }

    private static func extractChannelID(fromURI value: String) -> String {
        guard let url = URL(string: value) else { return "" }
        let components = url.path.split(separator: "/").map(String.init)
        guard let channelIndex = components.firstIndex(of: "channel"),
              components.indices.contains(channelIndex + 1) else {
            return ""
        }
        return components[channelIndex + 1]
    }
}

private extension Array {
    func chunked(by size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var chunks: [[Element]] = []
        chunks.reserveCapacity((count + size - 1) / size)
        var index = 0
        while index < count {
            let end = Swift.min(index + size, count)
            chunks.append(Array(self[index..<end]))
            index = end
        }
        return chunks
    }
}
