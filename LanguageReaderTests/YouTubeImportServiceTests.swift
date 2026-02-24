import Foundation
import XCTest
@testable import LanguageReader

final class YouTubeImportServiceTests: XCTestCase {
    override func tearDown() {
        StubbedURLProtocol.handler = nil
        super.tearDown()
    }

    func testVideoIDParserAcceptsWatchURL() {
        let input = "https://www.youtube.com/watch?v=KaBYEZ6q2tY"
        XCTAssertEqual(YouTubeVideoIDParser.parse(input), "KaBYEZ6q2tY")
    }

    func testVideoIDParserAcceptsShortURL() {
        let input = "https://youtu.be/UKWBtAYAo5I?si=abc123"
        XCTAssertEqual(YouTubeVideoIDParser.parse(input), "UKWBtAYAo5I")
    }

    func testVideoIDParserAcceptsShortsURL() {
        let input = "https://www.youtube.com/shorts/RpJ-qH_vfD8"
        XCTAssertEqual(YouTubeVideoIDParser.parse(input), "RpJ-qH_vfD8")
    }

    func testVideoIDParserAcceptsEmbedURL() {
        let input = "https://www.youtube.com/embed/UKWBtAYAo5I?start=30"
        XCTAssertEqual(YouTubeVideoIDParser.parse(input), "UKWBtAYAo5I")
    }

    func testVideoIDParserAcceptsRawID() {
        XCTAssertEqual(YouTubeVideoIDParser.parse("KaBYEZ6q2tY"), "KaBYEZ6q2tY")
    }

    func testVideoIDParserRejectsInvalidVideoIDLength() {
        XCTAssertNil(YouTubeVideoIDParser.parse("KaBYEZ6q2t"))
        XCTAssertNil(YouTubeVideoIDParser.parse("KaBYEZ6q2tYx"))
    }

    func testVideoIDParserRejectsInvalidInput() {
        XCTAssertNil(YouTubeVideoIDParser.parse("https://example.com/not-youtube"))
        XCTAssertNil(YouTubeVideoIDParser.parse(" "))
    }

    func testVideoIDParserAcceptsMobileWatchURL() {
        let input = "https://m.youtube.com/watch?v=KaBYEZ6q2tY&feature=youtu.be"
        XCTAssertEqual(YouTubeVideoIDParser.parse(input), "KaBYEZ6q2tY")
    }

    func testVideoIDParserRejectsPlaylistWithoutVideo() {
        let input = "https://www.youtube.com/playlist?list=PL1234567890"
        XCTAssertNil(YouTubeVideoIDParser.parse(input))
    }

    func testTranscriptXMLParserNormalizesLines() {
        let xml = """
        <?xml version="1.0" encoding="utf-8" ?>
        <transcript>
            <text start="0.1" dur="1.0">ಹಲೋ</text>
            <text start="1.1" dur="1.0">ಹಲೋ</text>
            <text start="2.2" dur="1.0">ಎಲ್ಲರಿಗೆ\nಸ್ವಾಗತ</text>
            <text start="3.0" dur="0.7">ಶುಭೋದಯ &amp; ಧನ್ಯವಾದಗಳು</text>
        </transcript>
        """

        let parsed = YouTubeTranscriptXMLParser.parseTranscript(data: Data(xml.utf8))
        XCTAssertEqual(parsed, "ಹಲೋ\nಎಲ್ಲರಿಗೆ ಸ್ವಾಗತ\nಶುಭೋದಯ & ಧನ್ಯವಾದಗಳು")
    }

    func testTranscriptXMLParserPreservesNonConsecutiveDuplicates() {
        let xml = """
        <transcript>
            <text start="0.1" dur="1.0">ಹಲೋ</text>
            <text start="1.1" dur="1.0">ಮತ್ತೆ</text>
            <text start="2.2" dur="1.0">ಹಲೋ</text>
        </transcript>
        """

        let parsed = YouTubeTranscriptXMLParser.parseTranscript(data: Data(xml.utf8))
        XCTAssertEqual(parsed, "ಹಲೋ\nಮತ್ತೆ\nಹಲೋ")
    }

    func testTranscriptXMLParserReturnsEmptyWhenNoTextElements() {
        let xml = """
        <transcript>
            <meta />
        </transcript>
        """

        let parsed = YouTubeTranscriptXMLParser.parseTranscript(data: Data(xml.utf8))
        XCTAssertEqual(parsed, "")
    }

    func testTranscriptXMLParserDecodesEntitiesAndTrimsWhitespace() {
        let xml = """
        <transcript>
            <text start="0.1" dur="1.0">  hello &amp; world  </text>
            <text start="1.1" dur="1.0">&lt;tag&gt;</text>
        </transcript>
        """

        let parsed = YouTubeTranscriptXMLParser.parseTranscript(data: Data(xml.utf8))
        XCTAssertEqual(parsed, "hello & world\n<tag>")
    }

    func testImportVideoPrefersManualKannadaTrack() async throws {
        let videoID = "KaBYEZ6q2tY"
        let manualTranscript = "ಮ್ಯಾನುಯಲ್"
        let asrTranscript = "ಆಸರ್"
        let session = makeStubbedSession { request in
            let url = try XCTUnwrap(request.url)
            if url.absoluteString.contains("youtube.com/watch") {
                return StubbedURLProtocol.response(
                    for: url,
                    data: Data(self.makeWatchHTML(apiKey: "test-key").utf8)
                )
            }
            if url.absoluteString.contains("youtubei/v1/player") {
                let payload = self.makePlayerPayload(
                    videoID: videoID,
                    durationSeconds: 120,
                    thumbnailWidths: [120, 640],
                    tracks: [
                        self.makeCaptionTrack(
                            languageCode: "kn",
                            baseURL: "https://example.com/manual.xml",
                            kind: nil
                        ),
                        self.makeCaptionTrack(
                            languageCode: "kn-IN",
                            baseURL: "https://example.com/asr.xml",
                            kind: "asr"
                        )
                    ]
                )
                return StubbedURLProtocol.response(for: url, data: payload)
            }
            if url.absoluteString.contains("manual.xml") {
                let xml = "<transcript><text>\(manualTranscript)</text></transcript>"
                return StubbedURLProtocol.response(for: url, data: Data(xml.utf8))
            }
            if url.absoluteString.contains("asr.xml") {
                let xml = "<transcript><text>\(asrTranscript)</text></transcript>"
                return StubbedURLProtocol.response(for: url, data: Data(xml.utf8))
            }
            throw URLError(.badURL)
        }

        let service = YouTubeImportService(session: session)
        let content = try await service.importVideo(videoID: videoID)

        XCTAssertEqual(content.videoID, videoID)
        XCTAssertEqual(content.title, "Test Video \(videoID)")
        XCTAssertEqual(content.channelTitle, "Channel \(videoID)")
        XCTAssertEqual(content.durationSeconds, 120)
        XCTAssertEqual(content.thumbnailURL?.absoluteString, "https://example.com/thumb-640.jpg")
        XCTAssertEqual(content.transcript, manualTranscript)
    }

    func testImportVideoThrowsWhenKannadaCaptionsMissing() async {
        let videoID = "KaBYEZ6q2tY"
        let session = makeStubbedSession { request in
            let url = try XCTUnwrap(request.url)
            if url.absoluteString.contains("youtube.com/watch") {
                return StubbedURLProtocol.response(
                    for: url,
                    data: Data(self.makeWatchHTML(apiKey: "test-key").utf8)
                )
            }
            if url.absoluteString.contains("youtubei/v1/player") {
                let payload = self.makePlayerPayload(
                    videoID: videoID,
                    durationSeconds: 120,
                    thumbnailWidths: [120],
                    tracks: [
                        self.makeCaptionTrack(
                            languageCode: "en",
                            baseURL: "https://example.com/en.xml",
                            kind: nil
                        )
                    ]
                )
                return StubbedURLProtocol.response(for: url, data: payload)
            }
            throw URLError(.badURL)
        }

        let service = YouTubeImportService(session: session)

        do {
            _ = try await service.importVideo(videoID: videoID)
            XCTFail("Expected importVideo to throw when Kannada captions are missing")
        } catch let error as YouTubeImportError {
            XCTAssertEqual(error, .kannadaCaptionsUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLoadBeginnerSuggestionsFiltersOverlongVideosAndKeepsRankOrder() async {
        let overlongID = "RpJ-qH_vfD8"
        let session = makeStubbedSession { request in
            let url = try XCTUnwrap(request.url)
            if url.absoluteString.contains("youtube.com/watch") {
                return StubbedURLProtocol.response(
                    for: url,
                    data: Data(self.makeWatchHTML(apiKey: "test-key").utf8)
                )
            }
            if url.absoluteString.contains("youtubei/v1/player") {
                let videoID = try self.extractVideoID(from: request)
                let duration = videoID == overlongID ? 999 : 120
                let payload = self.makePlayerPayload(
                    videoID: videoID,
                    durationSeconds: duration,
                    thumbnailWidths: [120],
                    tracks: [
                        self.makeCaptionTrack(
                            languageCode: "kn",
                            baseURL: "https://example.com/\(videoID).xml",
                            kind: nil
                        )
                    ]
                )
                return StubbedURLProtocol.response(for: url, data: payload)
            }
            throw URLError(.badURL)
        }

        let service = YouTubeImportService(session: session)
        let suggestions = await service.loadBeginnerSuggestions()
        let ids = suggestions.map(\.videoID)

        XCTAssertFalse(ids.contains(overlongID))
        XCTAssertEqual(
            ids,
            [
                "KaBYEZ6q2tY",
                "Pho7XZTsPis",
                "UKWBtAYAo5I",
                "ebQ0LPgoFkQ",
                "m4llekMMKEg"
            ]
        )
    }
}

private final class StubbedURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func response(for url: URL, statusCode: Int = 200, data: Data) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (response, data)
    }
}

private extension YouTubeImportServiceTests {
    func makeStubbedSession(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> URLSession {
        StubbedURLProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubbedURLProtocol.self]
        return URLSession(configuration: config)
    }

    func makeWatchHTML(apiKey: String) -> String {
        "<html><script>\"INNERTUBE_API_KEY\":\"\(apiKey)\"</script></html>"
    }

    func makeCaptionTrack(languageCode: String, baseURL: String, kind: String?) -> [String: Any] {
        var track: [String: Any] = [
            "languageCode": languageCode,
            "baseUrl": baseURL
        ]
        if let kind {
            track["kind"] = kind
        }
        return track
    }

    func makePlayerPayload(
        videoID: String,
        durationSeconds: Int,
        thumbnailWidths: [Int],
        tracks: [[String: Any]]
    ) -> Data {
        let thumbnails = thumbnailWidths.map { width -> [String: Any] in
            ["url": "https://example.com/thumb-\(width).jpg", "width": width]
        }
        let payload: [String: Any] = [
            "videoDetails": [
                "title": "Test Video \(videoID)",
                "author": "Channel \(videoID)",
                "lengthSeconds": "\(durationSeconds)",
                "thumbnail": ["thumbnails": thumbnails]
            ],
            "captions": [
                "playerCaptionsTracklistRenderer": [
                    "captionTracks": tracks
                ]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    func extractVideoID(from request: URLRequest) throws -> String {
        if let body = request.httpBody,
           let json = try JSONSerialization.jsonObject(with: body) as? [String: Any],
           let videoID = json["videoId"] as? String {
            return videoID
        }
        throw URLError(.badURL)
    }
}
