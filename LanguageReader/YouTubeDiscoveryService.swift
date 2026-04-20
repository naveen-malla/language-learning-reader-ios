import Foundation

struct YouTubeChannelSeed: Sendable, Hashable {
    let channelID: String
    let category: String
    let priority: Int
}

struct YouTubeSearchSeed: Sendable, Hashable {
    let query: String
    let category: String
    let priority: Int
}

protocol YouTubeCandidateValidating: Sendable {
    func validateCandidate(
        videoID: String,
        language: SupportedLanguage,
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

    static func defaultChannelSeeds(for language: SupportedLanguage) -> [YouTubeChannelSeed] {
        switch language {
        case .german:
            return []
        case .kannada:
            return [
                .init(channelID: "UChsgGgFHYTBL4m0dgRc78PQ", category: "Basics", priority: 1),
                .init(channelID: "UClhQBYN17XW_lA4568Qtu3A", category: "Conversation", priority: 2),
                .init(channelID: "UCirKrUfKVP2ebtwEWCObTbw", category: "Grammar", priority: 3),
                .init(channelID: "UCqZRKIkmWX2L2iAIDjYi0Fw", category: "Short Stories", priority: 4),
                .init(channelID: "UCe-zK4ux-tMl9Y8JJJqxL7Q", category: "Alphabet", priority: 5),
                .init(channelID: "UCOG5uDioDLiIZsSmyYSKYHw", category: "Beginner Intro", priority: 6)
            ]
        }
    }

    static func defaultSearchSeeds(for language: SupportedLanguage) -> [YouTubeSearchSeed] {
        switch language {
        case .german:
            return [
                .init(query: "learn german with subtitles", category: "Learn German", priority: 1),
                .init(query: "german conversation subtitles", category: "Conversation", priority: 2),
                .init(query: "german stories with subtitles", category: "Stories", priority: 3),
                .init(query: "easy german subtitles", category: "Beginner", priority: 1),
                .init(query: "german podcast subtitles", category: "Podcast", priority: 4),
                .init(query: "german vlog subtitles", category: "Vlog", priority: 5),
                .init(query: "german news subtitles", category: "News", priority: 6),
                .init(query: "german interview subtitles", category: "Interview", priority: 5),
                .init(query: "deutsch mit untertiteln", category: "Learn German", priority: 2),
                .init(query: "deutsche geschichten mit untertiteln", category: "Stories", priority: 3),
                .init(query: "deutsche untertitel podcast", category: "Podcast", priority: 5)
            ]
        case .kannada:
            return [
                .init(query: "learn kannada with subtitles", category: "Learn Kannada", priority: 2),
                .init(query: "kannada conversation subtitles", category: "Conversation", priority: 3),
                .init(query: "kannada stories with subtitles", category: "Stories", priority: 4),
                .init(query: "kannada podcast subtitles", category: "Podcast", priority: 5),
                .init(query: "kannada vlog subtitles", category: "Vlog", priority: 6),
                .init(query: "kannada news subtitles", category: "News", priority: 7),
                .init(query: "kannada interview subtitles", category: "Interview", priority: 5),
                .init(query: "kannada travel vlog subtitles", category: "Travel", priority: 6),
                .init(query: "kannada documentary subtitles", category: "Documentary", priority: 6),
                .init(query: "kannada cooking subtitles", category: "Lifestyle", priority: 7),
                .init(query: "kannada comedy subtitles", category: "Entertainment", priority: 8),
                .init(query: "kannada motivation subtitles", category: "Motivation", priority: 8),
                .init(query: "spoken kannada practice subtitles", category: "Conversation", priority: 4),
                .init(query: "kannada beginner lesson subtitles", category: "Learn Kannada", priority: 3),
                .init(query: "ಕನ್ನಡ ಉಪಶೀರ್ಷಿಕೆ ಕಥೆ", category: "Stories", priority: 5),
                .init(query: "ಕನ್ನಡ ಸಂಭಾಷಣೆ ಉಪಶೀರ್ಷಿಕೆ", category: "Conversation", priority: 5),
                .init(query: "ಕನ್ನಡ ಪಾಡ್ಕಾಸ್ಟ್ ಉಪಶೀರ್ಷಿಕೆ", category: "Podcast", priority: 6),
                .init(query: "ಕನ್ನಡ ಸುದ್ದಿ ಉಪಶೀರ್ಷಿಕೆ", category: "News", priority: 7)
            ]
        }
    }

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
        forceRefresh: Bool,
        language: SupportedLanguage = .kannada
    ) async -> [YouTubeSuggestedVideo] {
        if !forceRefresh {
            let cached = await cacheStore.cachedSuggestions(language: language)
            if !cached.isEmpty {
                return filtered(cached, excluding: existingVideoIDs)
            }
        }

        if !forceRefresh, await cacheStore.shouldBackoff(language: language) {
            let fallback = await cacheStore.cachedSuggestions(language: language, includeExpired: true)
            return filtered(fallback, excluding: existingVideoIDs)
        }

        let seeds = await mergedSeeds(for: language)
        let searchSeeds = Self.defaultSearchSeeds(for: language)
        let feedResult = await fetchCandidates(
            from: seeds,
            searchSeeds: searchSeeds,
            existingVideoIDs: existingVideoIDs
        )

        let budgeted = Self.selectValidationBudget(
            from: feedResult.candidates,
            limit: AutoImportSettings.defaultValidationBudget
        )
        let validated = await validateCandidates(
            budgeted,
            language: language,
            existingVideoIDs: existingVideoIDs,
            allowCachedFailures: !forceRefresh,
            useValidationCache: !forceRefresh
        )

        if !validated.isEmpty {
            await cacheStore.saveSuggestions(validated, language: language)
            await cacheStore.recordDiscoverySuccess(language: language)
            return filtered(validated, excluding: existingVideoIDs)
        }

        if feedResult.didFail {
            await cacheStore.recordDiscoveryFailure(language: language)
        } else {
            await cacheStore.recordDiscoverySuccess(language: language)
        }

        let fallback = await cacheStore.cachedSuggestions(language: language, includeExpired: true)
        return filtered(fallback, excluding: existingVideoIDs)
    }

    func addTrustedChannel(
        channelID: String?,
        channelTitle: String?,
        language: SupportedLanguage = .kannada
    ) async {
        await cacheStore.addTrustedChannel(
            channelID: channelID,
            channelTitle: channelTitle,
            language: language
        )
    }

    private func mergedSeeds(for language: SupportedLanguage) async -> [YouTubeChannelSeed] {
        var seeds = Self.defaultChannelSeeds(for: language)
        let trusted = await cacheStore.trustedChannelIDs(language: language)
        let existingIDs = Set(seeds.map(\.channelID))
        for channelID in trusted where !existingIDs.contains(channelID) {
            seeds.append(YouTubeChannelSeed(channelID: channelID, category: "Personalized", priority: 0))
        }
        return seeds
    }

    private func fetchCandidates(
        from seeds: [YouTubeChannelSeed],
        searchSeeds: [YouTubeSearchSeed],
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

            for seed in searchSeeds {
                group.addTask {
                    do {
                        let entries = try await self.fetchSearchFeed(seed: seed)
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
        language: SupportedLanguage,
        existingVideoIDs: Set<String>,
        allowCachedFailures: Bool,
        useValidationCache: Bool
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

                        if useValidationCache {
                            if let cached = await self.cacheStore.cachedValidation(
                                for: candidate.videoID,
                                language: language
                            ) {
                                if let cachedSuggestion = cached {
                                    let hydrated = await self.applyCandidateMetadata(candidate, to: cachedSuggestion)
                                    return (absoluteIndex, hydrated)
                                }
                                if allowCachedFailures {
                                    return (absoluteIndex, nil)
                                }
                            }
                        }

                        do {
                            let suggestion = try await self.validator.validateCandidate(
                                videoID: candidate.videoID,
                                language: language,
                                category: candidate.category,
                                publishedAt: candidate.publishedAt,
                                fallbackTitle: candidate.title,
                                fallbackChannelTitle: candidate.channelTitle,
                                fallbackChannelID: candidate.channelID
                            )
                            await self.cacheStore.storeValidationSuccess(suggestion, language: language)
                            return (absoluteIndex, suggestion)
                        } catch {
                            if Self.shouldCacheValidationFailure(error) {
                                await self.cacheStore.storeValidationFailure(
                                    videoID: candidate.videoID,
                                    language: language
                                )
                            }
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

    private func fetchSearchFeed(seed: YouTubeSearchSeed) async throws -> [YouTubeFeedEntry] {
        do {
            let liveEntries = try await fetchSearchResultsPage(seed: seed)
            if !liveEntries.isEmpty {
                return liveEntries
            }
        } catch {
            // Fall back to RSS-style search feed for compatibility and tests.
        }

        return try await fetchSearchFeedRSS(seed: seed)
    }

    private func fetchSearchFeedRSS(seed: YouTubeSearchSeed) async throws -> [YouTubeFeedEntry] {
        guard var components = URLComponents(string: "https://www.youtube.com/feeds/videos.xml") else {
            throw URLError(.badURL)
        }
        components.queryItems = [URLQueryItem(name: "search_query", value: seed.query)]
        guard let url = components.url else {
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

    private func fetchSearchResultsPage(seed: YouTubeSearchSeed) async throws -> [YouTubeFeedEntry] {
        guard var components = URLComponents(string: "https://www.youtube.com/results") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "search_query", value: seed.query)
        ]
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
            throw URLError(.cannotDecodeRawData)
        }
        return YouTubeSearchResultsParser.parse(html: html)
    }

    private func filtered(
        _ suggestions: [YouTubeSuggestedVideo],
        excluding existingVideoIDs: Set<String>
    ) -> [YouTubeSuggestedVideo] {
        suggestions.filter { !existingVideoIDs.contains($0.videoID) }
    }

    private static func selectValidationBudget(
        from candidates: [FeedCandidate],
        limit: Int
    ) -> [FeedCandidate] {
        guard limit > 0, !candidates.isEmpty else { return [] }

        var buckets: [String: [FeedCandidate]] = [:]
        var orderedChannels: [String] = []

        for candidate in candidates {
            let channelKey = candidate.channelID.isEmpty ? "unknown-\(candidate.videoID)" : candidate.channelID
            if buckets[channelKey] == nil {
                buckets[channelKey] = []
                orderedChannels.append(channelKey)
            }
            buckets[channelKey]?.append(candidate)
        }

        var selected: [FeedCandidate] = []
        var index = 0
        while selected.count < limit {
            var pickedInRound = false
            for channelKey in orderedChannels {
                guard let bucket = buckets[channelKey], !bucket.isEmpty else { continue }
                if index >= bucket.count {
                    continue
                }
                selected.append(bucket[index])
                pickedInRound = true
                if selected.count >= limit {
                    break
                }
            }
            if !pickedInRound {
                break
            }
            index += 1
        }

        return selected
    }

    private static func shouldCacheValidationFailure(_ error: Error) -> Bool {
        guard let error = error as? YouTubeImportError else {
            return false
        }

        switch error {
        case .captionsUnavailable,
                .kannadaCaptionsUnavailable,
                .germanCaptionsUnavailable,
                .unsupportedDuration,
                .lowQualityTranscript:
            return true
        case .invalidURL,
                .invalidVideoID,
                .networkFailure,
                .parsingFailure,
                .transcriptUnavailable:
            return false
        }
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

private enum YouTubeSearchResultsParser {
    static func parse(html: String) -> [YouTubeFeedEntry] {
        guard let initialData = extractInitialData(from: html),
              let data = initialData.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        var renderers: [[String: Any]] = []
        collectVideoRenderers(in: root, output: &renderers)

        var seenVideoIDs: Set<String> = []
        var entries: [YouTubeFeedEntry] = []

        for renderer in renderers {
            guard let videoID = renderer["videoId"] as? String,
                  YouTubeVideoIDParser.isValidVideoID(videoID),
                  !seenVideoIDs.contains(videoID) else {
                continue
            }

            let title = extractText(from: renderer["title"]) ?? ""
            guard !title.isEmpty else { continue }

            let channelTitle = extractText(from: renderer["ownerText"])
                ?? extractText(from: renderer["longBylineText"])
                ?? "Unknown Channel"
            let channelID = extractBrowseID(from: renderer["ownerText"])
                ?? extractBrowseID(from: renderer["longBylineText"])
                ?? "search-\(videoID)"

            seenVideoIDs.insert(videoID)
            entries.append(
                YouTubeFeedEntry(
                    videoID: videoID,
                    title: title,
                    channelTitle: channelTitle,
                    channelID: channelID,
                    publishedAt: nil
                )
            )
        }

        return entries
    }

    private static func extractInitialData(from html: String) -> String? {
        guard let markerRange = html.range(of: "var ytInitialData = ") else {
            return nil
        }

        let suffix = html[markerRange.upperBound...]
        guard let start = suffix.firstIndex(of: "{") else {
            return nil
        }

        var depth = 0
        var end: String.Index?
        var index = start
        while index < suffix.endIndex {
            let character = suffix[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    end = index
                    break
                }
            }
            index = suffix.index(after: index)
        }

        guard let end else { return nil }
        return String(suffix[start...end])
    }

    private static func collectVideoRenderers(in value: Any, output: inout [[String: Any]]) {
        if let dictionary = value as? [String: Any] {
            if let renderer = dictionary["videoRenderer"] as? [String: Any] {
                output.append(renderer)
            }
            for nested in dictionary.values {
                collectVideoRenderers(in: nested, output: &output)
            }
            return
        }

        if let array = value as? [Any] {
            for nested in array {
                collectVideoRenderers(in: nested, output: &output)
            }
        }
    }

    private static func extractText(from value: Any?) -> String? {
        guard let value else { return nil }

        if let text = value as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let dictionary = value as? [String: Any] {
            if let simpleText = dictionary["simpleText"] as? String {
                return simpleText.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if let runs = dictionary["runs"] as? [[String: Any]] {
                let joined = runs
                    .compactMap { $0["text"] as? String }
                    .joined()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return joined.isEmpty ? nil : joined
            }

            for nested in dictionary.values {
                if let extracted = extractText(from: nested), !extracted.isEmpty {
                    return extracted
                }
            }
        }

        if let array = value as? [Any] {
            for nested in array {
                if let extracted = extractText(from: nested), !extracted.isEmpty {
                    return extracted
                }
            }
        }

        return nil
    }

    private static func extractBrowseID(from value: Any?) -> String? {
        guard let value else { return nil }

        if let dictionary = value as? [String: Any] {
            if let runs = dictionary["runs"] as? [[String: Any]] {
                for run in runs {
                    if let endpoint = run["navigationEndpoint"] as? [String: Any],
                       let browseEndpoint = endpoint["browseEndpoint"] as? [String: Any],
                       let browseID = browseEndpoint["browseId"] as? String,
                       !browseID.isEmpty {
                        return browseID
                    }
                }
            }

            for nested in dictionary.values {
                if let browseID = extractBrowseID(from: nested) {
                    return browseID
                }
            }
        }

        if let array = value as? [Any] {
            for nested in array {
                if let browseID = extractBrowseID(from: nested) {
                    return browseID
                }
            }
        }

        return nil
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
