import Foundation

enum YouTubeImportError: LocalizedError {
    case invalidURL
    case invalidVideoID
    case networkFailure
    case parsingFailure
    case captionsUnavailable
    case kannadaCaptionsUnavailable
    case germanCaptionsUnavailable
    case transcriptUnavailable
    case unsupportedDuration
    case lowQualityTranscript

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Enter a valid YouTube URL."
        case .invalidVideoID:
            return "Could not read a YouTube video ID from this URL."
        case .networkFailure:
            return "Could not reach YouTube right now. Try again."
        case .parsingFailure:
            return "YouTube response format changed. Try a different video."
        case .captionsUnavailable:
            return "This video has no subtitles available."
        case .kannadaCaptionsUnavailable:
            return "This video does not have Kannada subtitles."
        case .germanCaptionsUnavailable:
            return "This video does not have German subtitles."
        case .transcriptUnavailable:
            return "Could not extract transcript text from subtitles."
        case .unsupportedDuration:
            return "Video must be between 5 and 20 minutes."
        case .lowQualityTranscript:
            return "Subtitles are too short or not readable enough for study."
        }
    }
}

struct YouTubeSuggestedVideo: Identifiable, Sendable {
    var id: String { videoID }
    let videoID: String
    let title: String
    let channelTitle: String
    let channelID: String?
    let category: String
    let durationSeconds: Int
    let thumbnailURL: URL?
    let publishedAt: Date?
}

struct ImportedYouTubeContent: Sendable {
    let videoID: String
    let language: SupportedLanguage
    let title: String
    let channelTitle: String
    let channelID: String?
    let transcript: String
    let subtitleCues: [TimedSubtitleCue]
    let durationSeconds: Int
    let thumbnailURL: URL?

    var watchURL: URL {
        URL(string: "https://www.youtube.com/watch?v=\(videoID)")!
    }
}

struct YouTubeVideoIDParser {
    static func parse(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if isValidVideoID(trimmed) {
            return trimmed
        }

        guard let components = URLComponents(string: trimmed) else {
            return nil
        }

        if let host = components.host?.lowercased() {
            if isShortYouTubeHost(host) {
                let pathParts = components.path.split(separator: "/")
                if let first = pathParts.first, isValidVideoID(String(first)) {
                    return String(first)
                }
            }

            if isYouTubeHost(host) {
                if let value = components.queryItems?.first(where: { $0.name == "v" })?.value,
                   isValidVideoID(value) {
                    return value
                }

                let pathParts = components.path.split(separator: "/").map(String.init)
                if let shortsIndex = pathParts.firstIndex(of: "shorts"),
                   pathParts.indices.contains(shortsIndex + 1),
                   isValidVideoID(pathParts[shortsIndex + 1]) {
                    return pathParts[shortsIndex + 1]
                }

                if let embedIndex = pathParts.firstIndex(of: "embed"),
                   pathParts.indices.contains(embedIndex + 1),
                   isValidVideoID(pathParts[embedIndex + 1]) {
                    return pathParts[embedIndex + 1]
                }
            }
        }

        return nil
    }

    static func isValidVideoID(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9_-]{11}$"#, options: .regularExpression) != nil
    }

    private static func isYouTubeHost(_ host: String) -> Bool {
        host == "youtube.com" || host.hasSuffix(".youtube.com")
    }

    private static func isShortYouTubeHost(_ host: String) -> Bool {
        host == "youtu.be" || host == "www.youtu.be"
    }
}

actor YouTubeImportService {
    static let shared = YouTubeImportService()

    static let minLessonDurationSeconds = 300
    static let maxLessonDurationSeconds = 1200
    static let preferredDurationSeconds = 720
    static let minimumReadableTranscriptLength = 60
    static let minimumKannadaCharacterCount = 24
    static let minimumKannadaWordCount = 6
    static let minimumGermanWordCount = 10
    static let maxDigitRatio = 0.35
    static let maxNumericDominantLines = 12

    private var metadataCache: [String: VideoMetadata] = [:]
    private var transcriptCache: [String: [TimedSubtitleCue]] = [:]
    private let session: URLSession
    private let cacheStore: SuggestionCacheStore
    private lazy var discoveryService = YouTubeDiscoveryService(
        session: session,
        cacheStore: cacheStore,
        validator: self
    )

    init(
        session: URLSession = .shared,
        cacheStore: SuggestionCacheStore = .shared
    ) {
        self.session = session
        self.cacheStore = cacheStore
    }

    func loadBeginnerSuggestions(
        existingVideoIDs: Set<String> = [],
        forceRefresh: Bool = false,
        language: SupportedLanguage = .kannada
    ) async -> [YouTubeSuggestedVideo] {
        await discoveryService.loadSuggestions(
            existingVideoIDs: existingVideoIDs,
            forceRefresh: forceRefresh,
            language: language
        )
    }

    func importFromURL(
        _ input: String,
        language: SupportedLanguage = .kannada
    ) async throws -> ImportedYouTubeContent {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw YouTubeImportError.invalidURL
        }
        guard let videoID = YouTubeVideoIDParser.parse(input) else {
            throw YouTubeImportError.invalidVideoID
        }
        return try await importVideo(videoID: videoID, language: language)
    }

    func importVideo(
        videoID: String,
        language: SupportedLanguage = .kannada
    ) async throws -> ImportedYouTubeContent {
        let metadata = try await loadMetadata(videoID: videoID, language: language)
        guard metadata.durationSeconds >= Self.minLessonDurationSeconds,
              metadata.durationSeconds <= Self.maxLessonDurationSeconds else {
            throw YouTubeImportError.unsupportedDuration
        }
        let subtitleCues = try await loadSubtitleCues(
            videoID: videoID,
            metadata: metadata,
            language: language
        )
        let transcript = Self.flattenedTranscript(from: subtitleCues)

        await cacheStore.addTrustedChannel(
            channelID: metadata.channelID,
            channelTitle: metadata.channelTitle,
            language: language
        )

        return ImportedYouTubeContent(
            videoID: videoID,
            language: language,
            title: metadata.title,
            channelTitle: metadata.channelTitle,
            channelID: metadata.channelID,
            transcript: transcript,
            subtitleCues: subtitleCues,
            durationSeconds: metadata.durationSeconds,
            thumbnailURL: metadata.thumbnailURL
        )
    }

    func loadSubtitleCuesForExistingVideo(
        videoID: String,
        language: SupportedLanguage = .kannada
    ) async throws -> [TimedSubtitleCue] {
        let metadata = try await loadMetadata(videoID: videoID, language: language)
        return try await loadSubtitleCues(videoID: videoID, metadata: metadata, language: language)
    }

    static func synthesizeSubtitleCues(
        from transcript: String,
        durationSeconds: Int?
    ) -> [TimedSubtitleCue] {
        let paragraphs = transcript
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var lines: [String] = []
        let tokenizer = SentenceTokenizer()

        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let sentences = tokenizer.sentences(in: trimmed)
            if sentences.isEmpty {
                lines.append(trimmed)
            } else {
                lines.append(contentsOf: sentences)
            }
        }

        guard !lines.isEmpty else { return [] }

        let totalDuration = max(
            Double(durationSeconds ?? 0),
            Double(lines.count) * 2.5,
            12
        )
        let cueDuration = totalDuration / Double(lines.count)

        return lines.enumerated().map { index, line in
            TimedSubtitleCue(
                startTime: Double(index) * cueDuration,
                duration: cueDuration,
                sourceText: line
            )
        }
    }

    func validateCandidate(
        videoID: String,
        language: SupportedLanguage,
        category: String,
        publishedAt: Date?,
        fallbackTitle: String?,
        fallbackChannelTitle: String?,
        fallbackChannelID: String?
    ) async throws -> YouTubeSuggestedVideo {
        let metadata = try await loadMetadata(videoID: videoID, language: language)
        guard metadata.durationSeconds >= Self.minLessonDurationSeconds,
              metadata.durationSeconds <= Self.maxLessonDurationSeconds else {
            throw YouTubeImportError.unsupportedDuration
        }
        _ = try await loadSubtitleCues(videoID: videoID, metadata: metadata, language: language)

        let resolvedTitle = metadata.title.isEmpty ? (fallbackTitle ?? "Untitled") : metadata.title
        let resolvedChannelTitle = metadata.channelTitle.isEmpty
            ? (fallbackChannelTitle ?? "Unknown Channel")
            : metadata.channelTitle
        let resolvedChannelID = metadata.channelID.isEmpty ? fallbackChannelID : metadata.channelID

        return YouTubeSuggestedVideo(
            videoID: videoID,
            title: resolvedTitle,
            channelTitle: resolvedChannelTitle,
            channelID: resolvedChannelID,
            category: category,
            durationSeconds: metadata.durationSeconds,
            thumbnailURL: metadata.thumbnailURL,
            publishedAt: publishedAt
        )
    }

    private func loadSubtitleCues(
        videoID: String,
        metadata: VideoMetadata,
        language: SupportedLanguage
    ) async throws -> [TimedSubtitleCue] {
        let key = cacheKey(videoID: videoID, language: language)
        if let cached = transcriptCache[key], !cached.isEmpty {
            return cached
        }

        let transcript = try await fetchTranscript(from: metadata.captionTrackURL)
        let flattenedTranscript = Self.flattenedTranscript(from: transcript)
        guard Self.isTranscriptReadableForStudy(flattenedTranscript, language: language) else {
            throw YouTubeImportError.lowQualityTranscript
        }
        transcriptCache[key] = transcript
        return transcript
    }

    private static func flattenedTranscript(from cues: [TimedSubtitleCue]) -> String {
        cues
            .map(\.sourceText)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isTranscriptReadableForStudy(
        _ transcript: String,
        language: SupportedLanguage
    ) -> Bool {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumReadableTranscriptLength else { return false }

        var letterScalars = 0
        var digitScalars = 0
        var kannadaScalars = 0

        for scalar in trimmed.unicodeScalars {
            if CharacterSet.letters.contains(scalar) {
                letterScalars += 1
            }
            if CharacterSet.decimalDigits.contains(scalar) {
                digitScalars += 1
            }
            if isKannadaScalar(scalar) {
                kannadaScalars += 1
            }
        }

        let words = trimmed.components(separatedBy: .whitespacesAndNewlines)
        var cleanedWords: [String] = []
        var kannadaWordCount = 0
        var uniqueKannadaWords: Set<String> = []

        for word in words {
            let cleaned = word
                .lowercased()
                .replacingOccurrences(of: #"[^\p{L}]+"#, with: "", options: .regularExpression)
            guard !cleaned.isEmpty else { continue }
            cleanedWords.append(cleaned)
            if cleaned.unicodeScalars.contains(where: isKannadaScalar) {
                kannadaWordCount += 1
                uniqueKannadaWords.insert(cleaned)
            }
        }

        var numericDominantLines = 0
        for rawLine in trimmed.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }

            var lineDigits = 0
            var lineLetters = 0
            var lineKannada = 0
            for scalar in line.unicodeScalars {
                if CharacterSet.decimalDigits.contains(scalar) {
                    lineDigits += 1
                }
                if CharacterSet.letters.contains(scalar) {
                    lineLetters += 1
                }
                if isKannadaScalar(scalar) {
                    lineKannada += 1
                }
            }

            if lineDigits > 0, lineKannada == 0, lineDigits >= lineLetters {
                numericDominantLines += 1
            }
        }

        if numericDominantLines >= maxNumericDominantLines {
            return false
        }

        let alphaNumericCount = letterScalars + digitScalars
        if alphaNumericCount > 0 {
            let digitRatio = Double(digitScalars) / Double(alphaNumericCount)
            if digitRatio > maxDigitRatio {
                return false
            }
        }

        switch language {
        case .german:
            guard LanguageTextHeuristics.containsLatinAlphabet(in: trimmed) else { return false }
            guard cleanedWords.count >= minimumGermanWordCount else { return false }
            guard Set(cleanedWords).count >= 4 else { return false }
            guard cleanedWords.contains(where: isLikelyGermanToken) || LanguageTextHeuristics.looksLikeGerman(trimmed) else {
                return false
            }
        case .kannada:
            guard kannadaScalars >= minimumKannadaCharacterCount else { return false }
            guard kannadaWordCount >= minimumKannadaWordCount else { return false }
            guard uniqueKannadaWords.count >= 4 else { return false }
        }

        return true
    }

    private static func isLikelyGermanToken(_ token: String) -> Bool {
        let normalized = token.lowercased()
        if normalized.contains("ä") || normalized.contains("ö") || normalized.contains("ü") || normalized.contains("ß") {
            return true
        }

        return [
            "der", "die", "das", "und", "ich", "nicht", "mit", "ein",
            "eine", "ist", "wir", "sie", "zu", "für", "auf", "im"
        ].contains(normalized)
    }

    private static func isKannadaScalar(_ scalar: UnicodeScalar) -> Bool {
        (0x0C80...0x0CFF).contains(scalar.value)
    }

    private func fetchTranscript(from captionTrackURL: URL) async throws -> [TimedSubtitleCue] {
        var request = URLRequest(url: captionTrackURL)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard isSuccessful(response: response) else {
            throw YouTubeImportError.networkFailure
        }

        let text = YouTubeTranscriptXMLParser.parseTimedTranscript(data: data)
        guard !text.isEmpty else {
            throw YouTubeImportError.transcriptUnavailable
        }
        return text
    }

    private func loadMetadata(
        videoID: String,
        language: SupportedLanguage
    ) async throws -> VideoMetadata {
        let key = cacheKey(videoID: videoID, language: language)
        if let cached = metadataCache[key] {
            guard languageMatches(cached.languageCode, language: language) else {
                throw captionsUnavailableError(for: language)
            }
            return cached
        }

        let html = try await fetchWatchHTML(videoID: videoID)
        guard let apiKey = extractInnertubeKey(from: html) else {
            throw YouTubeImportError.parsingFailure
        }

        let playerPayload = try await fetchPlayerPayload(videoID: videoID, apiKey: apiKey)
        let tracks = parseCaptionTracks(from: playerPayload)
        guard !tracks.isEmpty else {
            throw YouTubeImportError.captionsUnavailable
        }
        guard let captionTrack = pickCaptionTrack(from: tracks, language: language) else {
            throw captionsUnavailableError(for: language)
        }
        guard let metadata = buildVideoMetadata(videoID: videoID, payload: playerPayload, track: captionTrack) else {
            throw YouTubeImportError.parsingFailure
        }

        metadataCache[key] = metadata

        if !languageMatches(metadata.languageCode, language: language) {
            throw captionsUnavailableError(for: language)
        }

        return metadata
    }

    private func fetchWatchHTML(videoID: String) async throws -> String {
        guard let url = URL(string: "https://www.youtube.com/watch?v=\(videoID)") else {
            throw YouTubeImportError.invalidVideoID
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard isSuccessful(response: response) else {
            throw YouTubeImportError.networkFailure
        }
        guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
            throw YouTubeImportError.networkFailure
        }
        return html
    }

    private func fetchPlayerPayload(videoID: String, apiKey: String) async throws -> [String: Any] {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?key=\(apiKey)") else {
            throw YouTubeImportError.parsingFailure
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "context": [
                "client": [
                    "clientName": "ANDROID",
                    "clientVersion": "20.10.38"
                ]
            ],
            "videoId": videoID
        ])

        let (data, response) = try await session.data(for: request)
        guard isSuccessful(response: response) else {
            throw YouTubeImportError.networkFailure
        }

        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YouTubeImportError.parsingFailure
        }
        return payload
    }

    private func isSuccessful(response: URLResponse) -> Bool {
        guard let http = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode)
    }

    private func extractInnertubeKey(from html: String) -> String? {
        let pattern = #""INNERTUBE_API_KEY"\s*:\s*"([a-zA-Z0-9_-]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: html.utf16.count)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges == 2,
              let keyRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[keyRange])
    }

    private func buildVideoMetadata(videoID: String, payload: [String: Any], track: CaptionTrack) -> VideoMetadata? {
        guard let videoDetails = payload["videoDetails"] as? [String: Any] else { return nil }
        guard let title = videoDetails["title"] as? String else { return nil }
        guard let channelTitle = videoDetails["author"] as? String else { return nil }
        let channelID = videoDetails["channelId"] as? String ?? ""
        let durationSeconds = Int(videoDetails["lengthSeconds"] as? String ?? "") ?? 0

        let thumbnailURL: URL? = {
            guard let thumbnail = videoDetails["thumbnail"] as? [String: Any],
                  let thumbnails = thumbnail["thumbnails"] as? [[String: Any]] else {
                return URL(string: "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg")
            }

            let best = thumbnails.compactMap { dict -> (Int, URL)? in
                guard let urlString = dict["url"] as? String,
                      let url = URL(string: urlString) else { return nil }
                let width = dict["width"] as? Int ?? 0
                return (width, url)
            }
            .sorted(by: { $0.0 > $1.0 })
            .first
            return best?.1 ?? URL(string: "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg")
        }()

        return VideoMetadata(
            videoID: videoID,
            title: title,
            channelTitle: channelTitle,
            channelID: channelID,
            durationSeconds: durationSeconds,
            thumbnailURL: thumbnailURL,
            languageCode: track.effectiveLanguageCode,
            captionTrackURL: track.transcriptURL
        )
    }

    private func pickCaptionTrack(
        from tracks: [CaptionTrack],
        language: SupportedLanguage
    ) -> CaptionTrack? {
        if let directTrack = pickDirectTrack(from: tracks, language: language) {
            return directTrack
        }

        guard language == .kannada,
              let translatable = pickFallbackTrack(from: tracks, language: language),
              translatable.isTranslatable else {
            return nil
        }
        return translatable.translated(to: language.rawValue)
    }

    private func pickDirectTrack(
        from tracks: [CaptionTrack],
        language: SupportedLanguage
    ) -> CaptionTrack? {
        let directTracks = tracks.filter { languageMatches($0.languageCode, language: language) }
        guard !directTracks.isEmpty else { return nil }
        return prioritizedTracks(directTracks, language: language).first
    }

    private func pickFallbackTrack(
        from tracks: [CaptionTrack],
        language: SupportedLanguage
    ) -> CaptionTrack? {
        guard !tracks.isEmpty else { return nil }
        return prioritizedTracks(tracks, language: language).first
    }

    private func prioritizedTracks(
        _ tracks: [CaptionTrack],
        language: SupportedLanguage
    ) -> [CaptionTrack] {
        tracks.sorted { lhs, rhs in
            let lhsScore = (lhs.isAutoGenerated ? 1 : 0) + languagePreferenceScore(lhs.languageCode, language: language)
            let rhsScore = (rhs.isAutoGenerated ? 1 : 0) + languagePreferenceScore(rhs.languageCode, language: language)
            if lhsScore != rhsScore {
                return lhsScore < rhsScore
            }
            return lhs.languageCode.localizedCaseInsensitiveCompare(rhs.languageCode) == .orderedAscending
        }
    }

    private func languagePreferenceScore(
        _ languageCode: String,
        language: SupportedLanguage
    ) -> Int {
        let normalized = LanguageTextHeuristics.canonicalLanguageCode(languageCode)
        if normalized == language.rawValue { return 0 }
        if languageCode.lowercased().hasPrefix("\(language.rawValue)-") { return 1 }
        if normalized == "en" { return 2 }

        switch language {
        case .german:
            if normalized == "de" { return 0 }
            if normalized == "fr" { return 3 }
            if normalized == "es" { return 4 }
            return 5
        case .kannada:
            if normalized == "hi" { return 3 }
            if normalized == "te" { return 4 }
            if normalized == "ta" { return 5 }
            return 6
        }
    }

    private func languageMatches(_ languageCode: String, language: SupportedLanguage) -> Bool {
        LanguageTextHeuristics.canonicalLanguageCode(languageCode) == language.rawValue
    }

    private func captionsUnavailableError(for language: SupportedLanguage) -> YouTubeImportError {
        switch language {
        case .german:
            return .germanCaptionsUnavailable
        case .kannada:
            return .kannadaCaptionsUnavailable
        }
    }

    private func cacheKey(videoID: String, language: SupportedLanguage) -> String {
        "\(language.rawValue)|\(videoID)"
    }

    private func parseCaptionTracks(from payload: [String: Any]) -> [CaptionTrack] {
        guard let captions = payload["captions"] as? [String: Any],
              let renderer = captions["playerCaptionsTracklistRenderer"] as? [String: Any],
              let tracks = renderer["captionTracks"] as? [[String: Any]] else {
            return []
        }

        return tracks.compactMap { track in
            guard let languageCode = track["languageCode"] as? String,
                  let baseURLString = track["baseUrl"] as? String else {
                return nil
            }

            let cleanedURLString = baseURLString
                .replacingOccurrences(of: "&fmt=srv3", with: "")
                .replacingOccurrences(of: "&fmt=json3", with: "")

            guard let url = URL(string: cleanedURLString) else {
                return nil
            }

            let kind = track["kind"] as? String
            let isTranslatable = track["isTranslatable"] as? Bool ?? true
            return CaptionTrack(
                languageCode: languageCode,
                isAutoGenerated: kind == "asr",
                isTranslatable: isTranslatable,
                baseURL: url
            )
        }
    }

    private struct CaptionTrack {
        let languageCode: String
        let isAutoGenerated: Bool
        let isTranslatable: Bool
        let baseURL: URL
        let translatedLanguageCode: String?

        init(
            languageCode: String,
            isAutoGenerated: Bool,
            isTranslatable: Bool,
            baseURL: URL,
            translatedLanguageCode: String? = nil
        ) {
            self.languageCode = languageCode
            self.isAutoGenerated = isAutoGenerated
            self.isTranslatable = isTranslatable
            self.baseURL = baseURL
            self.translatedLanguageCode = translatedLanguageCode
        }

        var effectiveLanguageCode: String {
            translatedLanguageCode ?? languageCode
        }

        var transcriptURL: URL {
            guard let translatedLanguageCode else {
                return baseURL
            }
            guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
                return baseURL
            }
            var queryItems = components.queryItems ?? []
            queryItems.removeAll(where: { $0.name == "tlang" })
            queryItems.append(URLQueryItem(name: "tlang", value: translatedLanguageCode))
            components.queryItems = queryItems
            return components.url ?? baseURL
        }

        func translated(to languageCode: String) -> CaptionTrack {
            CaptionTrack(
                languageCode: self.languageCode,
                isAutoGenerated: isAutoGenerated,
                isTranslatable: false,
                baseURL: baseURL,
                translatedLanguageCode: languageCode
            )
        }
    }

    private struct VideoMetadata: Sendable {
        let videoID: String
        let title: String
        let channelTitle: String
        let channelID: String
        let durationSeconds: Int
        let thumbnailURL: URL?
        let languageCode: String
        let captionTrackURL: URL
    }
}

extension YouTubeImportService: YouTubeCandidateValidating {}

enum YouTubeTranscriptXMLParser {
    private static let mergeGapThreshold = 0.3
    private static let maxMergedCueCharacterCount = 120
    private static let microCueCharacterCount = 18
    private static let microCueDurationThreshold = 0.8

    static func parseTimedTranscript(data: Data) -> [TimedSubtitleCue] {
        let parserDelegate = TranscriptXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        _ = parser.parse()
        return normalize(cues: parserDelegate.cues)
    }

    static func parseTranscript(data: Data) -> String {
        let cues = parseTimedTranscript(data: data)
        return cues.map(\.sourceText).joined(separator: "\n")
    }

    private static func normalize(cues: [ParsedTranscriptCue]) -> [TimedSubtitleCue] {
        let normalized = cues.compactMap { cue -> TimedSubtitleCue? in
            let cleaned = cue.text
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return nil }
            return TimedSubtitleCue(
                startTime: cue.startTime,
                duration: cue.duration,
                sourceText: cleaned
            )
        }

        return mergeConsecutiveDuplicates(in: normalized)
            .reduce(into: []) { result, cue in
                guard let previous = result.popLast() else {
                    result.append(cue)
                    return
                }

                if shouldMerge(previous, cue) {
                    let mergedText = "\(previous.sourceText) \(cue.sourceText)"
                        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let endTime = max(previous.endTime, cue.endTime)
                    result.append(
                        TimedSubtitleCue(
                            startTime: previous.startTime,
                            duration: endTime - previous.startTime,
                            sourceText: mergedText
                        )
                    )
                } else {
                    result.append(previous)
                    result.append(cue)
                }
            }
    }

    private static func mergeConsecutiveDuplicates(in cues: [TimedSubtitleCue]) -> [TimedSubtitleCue] {
        var result: [TimedSubtitleCue] = []

        for cue in cues {
            guard let previous = result.popLast() else {
                result.append(cue)
                continue
            }

            let gap = cue.startTime - previous.endTime
            if previous.sourceText == cue.sourceText, gap <= mergeGapThreshold {
                let mergedEndTime = max(previous.endTime, cue.endTime)
                result.append(
                    TimedSubtitleCue(
                        startTime: previous.startTime,
                        duration: mergedEndTime - previous.startTime,
                        sourceText: previous.sourceText
                    )
                )
            } else {
                result.append(previous)
                result.append(cue)
            }
        }

        return result
    }

    private static func shouldMerge(_ lhs: TimedSubtitleCue, _ rhs: TimedSubtitleCue) -> Bool {
        let gap = rhs.startTime - lhs.endTime
        guard gap >= 0, gap <= mergeGapThreshold else { return false }

        let mergedCharacterCount = lhs.sourceText.count + 1 + rhs.sourceText.count
        guard mergedCharacterCount <= maxMergedCueCharacterCount else { return false }

        let lhsIsMicroCue = lhs.duration <= microCueDurationThreshold && lhs.sourceText.count <= microCueCharacterCount
        let rhsIsMicroCue = rhs.duration <= microCueDurationThreshold && rhs.sourceText.count <= microCueCharacterCount
        guard lhsIsMicroCue || rhsIsMicroCue else { return false }

        return hasTerminalPunctuation(lhs.sourceText) == false
    }

    private static func hasTerminalPunctuation(_ text: String) -> Bool {
        guard let last = text.trimmingCharacters(in: .whitespacesAndNewlines).last else {
            return false
        }
        return ".?!;:।…".contains(last)
    }
}

private final class TranscriptXMLDelegate: NSObject, XMLParserDelegate {
    private(set) var cues: [ParsedTranscriptCue] = []
    private var currentText = ""
    private var isTextElement = false
    private var currentStartTime = 0.0
    private var currentDuration = 0.0

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "text" {
            currentText = ""
            isTextElement = true
            currentStartTime = Double(attributeDict["start"] ?? "") ?? 0
            currentDuration = Double(attributeDict["dur"] ?? "") ?? 0
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isTextElement else { return }
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard elementName == "text" else { return }
        isTextElement = false
        cues.append(
            ParsedTranscriptCue(
                startTime: currentStartTime,
                duration: currentDuration,
                text: currentText
            )
        )
        currentText = ""
        currentStartTime = 0
        currentDuration = 0
    }
}

private struct ParsedTranscriptCue {
    let startTime: Double
    let duration: Double
    let text: String
}
