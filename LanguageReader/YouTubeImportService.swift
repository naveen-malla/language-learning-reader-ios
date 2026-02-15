import Foundation

enum YouTubeImportError: LocalizedError {
    case invalidURL
    case invalidVideoID
    case networkFailure
    case parsingFailure
    case captionsUnavailable
    case kannadaCaptionsUnavailable
    case transcriptUnavailable
    case unsupportedDuration

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
        case .transcriptUnavailable:
            return "Could not extract transcript text from subtitles."
        case .unsupportedDuration:
            return "Video is too long for beginner feed right now."
        }
    }
}

struct YouTubeSuggestionSeed: Sendable {
    let videoID: String
    let category: String
    let rank: Int
}

struct YouTubeSuggestedVideo: Identifiable, Sendable {
    var id: String { videoID }
    let videoID: String
    let title: String
    let channelTitle: String
    let category: String
    let durationSeconds: Int
    let thumbnailURL: URL?
}

struct ImportedYouTubeContent: Sendable {
    let videoID: String
    let title: String
    let channelTitle: String
    let transcript: String
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
            if host == "youtu.be" || host == "www.youtu.be" {
                let pathParts = components.path.split(separator: "/")
                if let first = pathParts.first, isValidVideoID(String(first)) {
                    return String(first)
                }
            }

            if host.contains("youtube.com") {
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
}

actor YouTubeImportService {
    static let shared = YouTubeImportService()

    static let maxBeginnerDurationSeconds = 720

    private static let starterCatalog: [YouTubeSuggestionSeed] = [
        .init(videoID: "KaBYEZ6q2tY", category: "Basics", rank: 1),
        .init(videoID: "Pho7XZTsPis", category: "Conversation", rank: 2),
        .init(videoID: "RpJ-qH_vfD8", category: "Grammar", rank: 3),
        .init(videoID: "UKWBtAYAo5I", category: "Short Stories", rank: 4),
        .init(videoID: "ebQ0LPgoFkQ", category: "Alphabet", rank: 5),
        .init(videoID: "m4llekMMKEg", category: "Beginner Intro", rank: 6)
    ]

    private var metadataCache: [String: VideoMetadata] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadBeginnerSuggestions() async -> [YouTubeSuggestedVideo] {
        var suggestions: [YouTubeSuggestedVideo] = []

        await withTaskGroup(of: (Int, YouTubeSuggestedVideo?).self) { group in
            for seed in Self.starterCatalog {
                group.addTask { [weak self] in
                    guard let self else { return (seed.rank, nil) }
                    do {
                        let metadata = try await self.loadMetadata(videoID: seed.videoID, requireKannada: true)
                        guard metadata.durationSeconds <= Self.maxBeginnerDurationSeconds else {
                            return (seed.rank, nil)
                        }
                        return (seed.rank, YouTubeSuggestedVideo(
                            videoID: seed.videoID,
                            title: metadata.title,
                            channelTitle: metadata.channelTitle,
                            category: seed.category,
                            durationSeconds: metadata.durationSeconds,
                            thumbnailURL: metadata.thumbnailURL
                        ))
                    } catch {
                        return (seed.rank, nil)
                    }
                }
            }

            var ranked: [(Int, YouTubeSuggestedVideo)] = []
            for await result in group {
                if let value = result.1 {
                    ranked.append((result.0, value))
                }
            }
            suggestions = ranked
                .sorted { $0.0 < $1.0 }
                .map(\.1)
        }

        return suggestions
    }

    func importFromURL(_ input: String) async throws -> ImportedYouTubeContent {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw YouTubeImportError.invalidURL
        }
        guard let videoID = YouTubeVideoIDParser.parse(input) else {
            throw YouTubeImportError.invalidVideoID
        }
        return try await importVideo(videoID: videoID)
    }

    func importVideo(videoID: String) async throws -> ImportedYouTubeContent {
        let metadata = try await loadMetadata(videoID: videoID, requireKannada: true)
        let transcript = try await fetchTranscript(from: metadata.captionTrackURL)

        guard !transcript.isEmpty else {
            throw YouTubeImportError.transcriptUnavailable
        }

        return ImportedYouTubeContent(
            videoID: videoID,
            title: metadata.title,
            channelTitle: metadata.channelTitle,
            transcript: transcript,
            durationSeconds: metadata.durationSeconds,
            thumbnailURL: metadata.thumbnailURL
        )
    }

    private func loadMetadata(videoID: String, requireKannada: Bool) async throws -> VideoMetadata {
        if let cached = metadataCache[videoID] {
            if requireKannada, !cached.languageCode.lowercased().hasPrefix("kn") {
                throw YouTubeImportError.kannadaCaptionsUnavailable
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
        guard let kannadaTrack = pickKannadaTrack(from: tracks) else {
            throw YouTubeImportError.kannadaCaptionsUnavailable
        }
        guard let metadata = buildVideoMetadata(videoID: videoID, payload: playerPayload, track: kannadaTrack) else {
            throw YouTubeImportError.parsingFailure
        }

        metadataCache[videoID] = metadata

        if requireKannada, !metadata.languageCode.lowercased().hasPrefix("kn") {
            throw YouTubeImportError.kannadaCaptionsUnavailable
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

    private func fetchTranscript(from captionTrackURL: URL) async throws -> String {
        var request = URLRequest(url: captionTrackURL)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard isSuccessful(response: response) else {
            throw YouTubeImportError.networkFailure
        }

        let text = YouTubeTranscriptXMLParser.parseTranscript(data: data)
        guard !text.isEmpty else {
            throw YouTubeImportError.transcriptUnavailable
        }
        return text
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
            durationSeconds: durationSeconds,
            thumbnailURL: thumbnailURL,
            languageCode: track.languageCode,
            captionTrackURL: track.baseURL
        )
    }

    private func pickKannadaTrack(from tracks: [CaptionTrack]) -> CaptionTrack? {
        let kannadaTracks = tracks.filter { $0.languageCode.lowercased().hasPrefix("kn") }
        guard !kannadaTracks.isEmpty else { return nil }

        // Prefer manually-uploaded Kannada subtitles over auto-generated asr tracks.
        return kannadaTracks.sorted { lhs, rhs in
            let lhsScore = (lhs.isAutoGenerated ? 1 : 0) + (lhs.languageCode.lowercased() == "kn" ? 0 : 1)
            let rhsScore = (rhs.isAutoGenerated ? 1 : 0) + (rhs.languageCode.lowercased() == "kn" ? 0 : 1)
            return lhsScore < rhsScore
        }.first
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
            return CaptionTrack(
                languageCode: languageCode,
                isAutoGenerated: kind == "asr",
                baseURL: url
            )
        }
    }

    private struct CaptionTrack {
        let languageCode: String
        let isAutoGenerated: Bool
        let baseURL: URL
    }

    private struct VideoMetadata: Sendable {
        let videoID: String
        let title: String
        let channelTitle: String
        let durationSeconds: Int
        let thumbnailURL: URL?
        let languageCode: String
        let captionTrackURL: URL
    }
}

enum YouTubeTranscriptXMLParser {
    static func parseTranscript(data: Data) -> String {
        let parserDelegate = TranscriptXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        _ = parser.parse()
        return normalize(lines: parserDelegate.lines)
    }

    private static func normalize(lines: [String]) -> String {
        var normalized: [String] = []
        var previous = ""

        for line in lines {
            let cleaned = line
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleaned.isEmpty else { continue }
            guard cleaned != previous else { continue }
            normalized.append(cleaned)
            previous = cleaned
        }

        return normalized.joined(separator: "\n")
    }
}

private final class TranscriptXMLDelegate: NSObject, XMLParserDelegate {
    private(set) var lines: [String] = []
    private var currentText = ""
    private var isTextElement = false

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
        lines.append(currentText)
        currentText = ""
    }
}
