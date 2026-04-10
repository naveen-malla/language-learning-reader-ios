import Foundation
import XCTest
@testable import LanguageReader

final class YouTubeImportServiceTests: XCTestCase {
    override func tearDown() {
        StubbedURLProtocol.reset()
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
        XCTAssertNil(YouTubeVideoIDParser.parse("https://notyoutube.com/watch?v=KaBYEZ6q2tY"))
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

        let timedCues = YouTubeTranscriptXMLParser.parseTimedTranscript(data: Data(xml.utf8))
        XCTAssertEqual(timedCues.map(\.sourceText), ["ಹಲೋ", "ಎಲ್ಲರಿಗೆ ಸ್ವಾಗತ", "ಶುಭೋದಯ & ಧನ್ಯವಾದಗಳು"])
        let firstTimedCue = try! XCTUnwrap(timedCues.first)
        XCTAssertEqual(firstTimedCue.startTime, 0.1, accuracy: 0.001)
        XCTAssertEqual(firstTimedCue.duration, 2.0, accuracy: 0.001)

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

    func testTranscriptXMLParserDoesNotMergeDuplicateLinesAcrossLargeGap() {
        let xml = """
        <transcript>
            <text start="0.1" dur="1.0">ಹಲೋ</text>
            <text start="4.0" dur="1.0">ಹಲೋ</text>
        </transcript>
        """

        let parsed = YouTubeTranscriptXMLParser.parseTimedTranscript(data: Data(xml.utf8))
        XCTAssertEqual(parsed.count, 2)
        let firstParsedCue = try! XCTUnwrap(parsed.first)
        let lastParsedCue = try! XCTUnwrap(parsed.last)
        XCTAssertEqual(firstParsedCue.duration, 1.0, accuracy: 0.001)
        XCTAssertEqual(lastParsedCue.startTime, 4.0, accuracy: 0.001)
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

    func testTranscriptXMLParserMergesMicroFragmentsIntoReadableCue() {
        let xml = """
        <transcript>
            <text start="0.0" dur="0.35">ಇದು</text>
            <text start="0.37" dur="0.3">ಒಂದು</text>
            <text start="0.7" dur="0.4">ಉದಾಹರಣೆ</text>
            <text start="2.0" dur="1.0">ಮುಂದಿನ ವಾಕ್ಯ.</text>
        </transcript>
        """

        let parsed = YouTubeTranscriptXMLParser.parseTimedTranscript(data: Data(xml.utf8))
        XCTAssertEqual(parsed.count, 2)
        let mergedCue = try! XCTUnwrap(parsed.first)
        let trailingCue = try! XCTUnwrap(parsed.last)
        XCTAssertEqual(mergedCue.sourceText, "ಇದು ಒಂದು ಉದಾಹರಣೆ")
        XCTAssertEqual(mergedCue.startTime, 0.0, accuracy: 0.001)
        XCTAssertEqual(mergedCue.duration, 1.1, accuracy: 0.001)
        XCTAssertEqual(trailingCue.sourceText, "ಮುಂದಿನ ವಾಕ್ಯ.")
    }

    func testTranscriptXMLParserDoesNotMergeAcrossTerminalPunctuation() {
        let xml = """
        <transcript>
            <text start="0.0" dur="0.35">ಹೌದು.</text>
            <text start="0.4" dur="0.35">ಮುಂದೆ</text>
        </transcript>
        """

        let parsed = YouTubeTranscriptXMLParser.parseTimedTranscript(data: Data(xml.utf8))
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed.first?.sourceText, "ಹೌದು.")
        XCTAssertEqual(parsed.last?.sourceText, "ಮುಂದೆ")
    }

    func testTranscriptXMLParserDoesNotMergeWhenMergedCueWouldBeTooLong() {
        let left = String(repeating: "ಅ", count: 70)
        let right = String(repeating: "ಬ", count: 70)
        let xml = """
        <transcript>
            <text start="0.0" dur="0.35">\(left)</text>
            <text start="0.36" dur="0.35">\(right)</text>
        </transcript>
        """

        let parsed = YouTubeTranscriptXMLParser.parseTimedTranscript(data: Data(xml.utf8))
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed.first?.sourceText, left)
        XCTAssertEqual(parsed.last?.sourceText, right)
    }

    func testImportVideoPrefersManualKannadaTrack() async throws {
        let videoID = "KaBYEZ6q2tY"
        let channelID = "channel-\(videoID)"
        let manualLines = [
            "ಇದು ಕನ್ನಡ ಕಲಿಕೆಯ ಮೊದಲ ಪಾಠ ಮತ್ತು ಉಚ್ಚಾರಣೆಯ ಅಭ್ಯಾಸ.",
            "ನೀವು ನಿಧಾನವಾಗಿ ಓದಿ ಪ್ರತಿಯೊಂದು ಪದವನ್ನು ಸ್ಪಷ್ಟವಾಗಿ ಹೇಳಿ.",
            "ಈ ವಾಕ್ಯಗಳು ಓದುಗರಿಗೆ ಅರ್ಥವಾಗುವ ಸರಳ ಭಾಷೆಯಲ್ಲಿ ಇವೆ.",
            "ಪ್ರತಿ ದಿನ ಅಭ್ಯಾಸ ಮಾಡಿದರೆ ಓದು ಮತ್ತು ಪದಸಂಪತ್ತು ವೇಗವಾಗಿ ಬೆಳೆಯುತ್ತದೆ."
        ]
        let manualTranscript = manualLines.joined(separator: "\n")
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
                    channelID: channelID,
                    durationSeconds: 600,
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
                let xml = self.makeTranscriptXML(lines: manualLines)
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
        XCTAssertEqual(content.channelID, channelID)
        XCTAssertEqual(content.durationSeconds, 600)
        XCTAssertEqual(content.thumbnailURL?.absoluteString, "https://example.com/thumb-640.jpg")
        XCTAssertEqual(content.transcript, manualTranscript)
        XCTAssertEqual(content.subtitleCues.map(\.sourceText), manualLines)
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
                    channelID: "channel-\(videoID)",
                    durationSeconds: 600,
                    thumbnailWidths: [120],
                    tracks: [
                        self.makeCaptionTrack(
                            languageCode: "en",
                            baseURL: "https://example.com/en.xml",
                            kind: nil,
                            isTranslatable: false
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

    func testLoadSubtitleCuesForExistingVideoSkipsDurationGate() async throws {
        let videoID = "KaBYEZ6q2tY"
        let readableTranscript = [
            "ಇದು ಚಿಕ್ಕ ಆದರೆ ಸಾಕಷ್ಟು ಓದಬಹುದಾದ ಕನ್ನಡ ಪಾಠವಾಗಿದೆ.",
            "ಹಳೆಯ lesson ಗಾಗಿ subtitle cues ಮಾತ್ರ ಇಲ್ಲಿ backfill ಆಗಬೇಕು.",
            "Duration gate ಅನ್ನು ಈ path ನಲ್ಲಿ skip ಮಾಡಬೇಕು.",
            "ಆದರೆ Kannada subtitle ಮತ್ತು readability rules ಉಳಿಯಬೇಕು."
        ]
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
                    channelID: "channel-\(videoID)",
                    durationSeconds: 120,
                    thumbnailWidths: [120],
                    tracks: [
                        self.makeCaptionTrack(
                            languageCode: "kn",
                            baseURL: "https://example.com/short.xml",
                            kind: nil
                        )
                    ]
                )
                return StubbedURLProtocol.response(for: url, data: payload)
            }
            if url.absoluteString.contains("short.xml") {
                let xml = self.makeTranscriptXML(lines: readableTranscript)
                return StubbedURLProtocol.response(for: url, data: Data(xml.utf8))
            }
            throw URLError(.badURL)
        }

        let service = YouTubeImportService(session: session)
        let cues = try await service.loadSubtitleCuesForExistingVideo(videoID: videoID)

        XCTAssertEqual(cues.map(\.sourceText), readableTranscript)
        XCTAssertEqual(cues.count, readableTranscript.count)
    }

    func testLoadSubtitleCuesForExistingVideoUsesCueCacheOnRepeatedCalls() async throws {
        let videoID = "KaBYEZ6q2tY"
        let readableTranscript = [
            "ಇದು ಓದುಗರಿಗೆ ಉಪಯೋಗವಾಗುವ ಸಾಲು.",
            "ಇನ್ನೊಂದು ಸರಳ ಕನ್ನಡ ಸಾಲು.",
            "ಹೆಚ್ಚು ಅಭ್ಯಾಸ ಮಾಡಿದರೆ ಓದುವಿಕೆ ಉತ್ತಮವಾಗುತ್ತದೆ."
        ]
        var transcriptFetchCount = 0

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
                    channelID: "channel-\(videoID)",
                    durationSeconds: 120,
                    thumbnailWidths: [120],
                    tracks: [
                        self.makeCaptionTrack(
                            languageCode: "kn",
                            baseURL: "https://example.com/cached.xml",
                            kind: nil
                        )
                    ]
                )
                return StubbedURLProtocol.response(for: url, data: payload)
            }
            if url.absoluteString.contains("cached.xml") {
                transcriptFetchCount += 1
                let xml = self.makeTranscriptXML(lines: readableTranscript)
                return StubbedURLProtocol.response(for: url, data: Data(xml.utf8))
            }
            throw URLError(.badURL)
        }

        let service = YouTubeImportService(session: session)

        let first = try await service.loadSubtitleCuesForExistingVideo(videoID: videoID)
        let second = try await service.loadSubtitleCuesForExistingVideo(videoID: videoID)

        XCTAssertEqual(first, second)
        XCTAssertEqual(transcriptFetchCount, 1)
    }

    func testLoadSubtitleCuesForExistingVideoThrowsWhenKannadaCaptionsMissing() async {
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
                    channelID: "channel-\(videoID)",
                    durationSeconds: 120,
                    thumbnailWidths: [120],
                    tracks: [
                        self.makeCaptionTrack(
                            languageCode: "en",
                            baseURL: "https://example.com/en.xml",
                            kind: nil,
                            isTranslatable: false
                        )
                    ]
                )
                return StubbedURLProtocol.response(for: url, data: payload)
            }
            throw URLError(.badURL)
        }

        let service = YouTubeImportService(session: session)

        do {
            _ = try await service.loadSubtitleCuesForExistingVideo(videoID: videoID)
            XCTFail("Expected loadSubtitleCuesForExistingVideo to throw when Kannada captions are missing")
        } catch let error as YouTubeImportError {
            XCTAssertEqual(error, .kannadaCaptionsUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testImportVideoUsesKannadaTranslationWhenOnlyTranslatableTrackExists() async throws {
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
                    channelID: "channel-\(videoID)",
                    durationSeconds: 600,
                    thumbnailWidths: [120],
                    tracks: [
                        self.makeCaptionTrack(
                            languageCode: "en",
                            baseURL: "https://example.com/en.xml",
                            kind: nil,
                            isTranslatable: true
                        )
                    ]
                )
                return StubbedURLProtocol.response(for: url, data: payload)
            }
            if url.absoluteString.contains("en.xml") {
                guard let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                      query.contains(where: { $0.name == "tlang" && $0.value == "kn" }) else {
                    throw URLError(.badURL)
                }
                let xml = self.makeTranscriptXML(lines: [
                    "ಇದು ಕನ್ನಡದಲ್ಲಿ ಅನುವಾದಿತ ಉಪಶೀರ್ಷಿಕೆಯ ಪಾಠವಾಗಿದೆ.",
                    "ವಾಕ್ಯಗಳನ್ನು ನಿಧಾನವಾಗಿ ಓದಿ ಪದಗಳ ಅರ್ಥವನ್ನು ಗಮನಿಸಿ.",
                    "ಈ ಅಭ್ಯಾಸವು ಓದುಗನಿಗೆ ಸರಳವಾಗಿ ಗ್ರಹಿಸಲು ಸಹಾಯ ಮಾಡುತ್ತದೆ.",
                    "ಪ್ರತಿದಿನ ಓದಿದರೆ ಭಾಷೆಯ ನೆನಪು ಮತ್ತು ವೇಗ ಎರಡೂ ಉತ್ತಮವಾಗುತ್ತವೆ."
                ])
                return StubbedURLProtocol.response(for: url, data: Data(xml.utf8))
            }
            throw URLError(.badURL)
        }

        let service = YouTubeImportService(session: session)
        let content = try await service.importVideo(videoID: videoID)
        XCTAssertEqual(content.videoID, videoID)
        XCTAssertFalse(content.transcript.isEmpty)
    }

    func testImportVideoRejectsLowQualityTranscriptEvenWhenKannadaCaptionsExist() async {
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
                    channelID: "channel-\(videoID)",
                    durationSeconds: 600,
                    thumbnailWidths: [120],
                    tracks: [
                        self.makeCaptionTrack(
                            languageCode: "kn",
                            baseURL: "https://example.com/kn.xml",
                            kind: nil
                        )
                    ]
                )
                return StubbedURLProtocol.response(for: url, data: payload)
            }
            if url.absoluteString.contains("kn.xml") {
                let xml = "<transcript><text>ಹಲೋ</text></transcript>"
                return StubbedURLProtocol.response(for: url, data: Data(xml.utf8))
            }
            throw URLError(.badURL)
        }

        let service = YouTubeImportService(session: session)

        do {
            _ = try await service.importVideo(videoID: videoID)
            XCTFail("Expected importVideo to reject low quality transcript")
        } catch let error as YouTubeImportError {
            XCTAssertEqual(error, .lowQualityTranscript)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testImportVideoRejectsNumericSequenceTranscript() async {
        let videoID = "KaBYEZ6q2tY"
        let numericLines = (1...70).map(String.init)
        let transcriptLines = [
            "ಇದು ಸಂಖ್ಯೆಗಳ ಅಭ್ಯಾಸದ ವಿಡಿಯೋ.",
            "ಕನ್ನಡದಲ್ಲಿ ಕೆಲವು ಸೂಚನೆಗಳು ಇವೆ."
        ] + numericLines

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
                    channelID: "channel-\(videoID)",
                    durationSeconds: 600,
                    thumbnailWidths: [120],
                    tracks: [
                        self.makeCaptionTrack(
                            languageCode: "kn",
                            baseURL: "https://example.com/kn-numeric.xml",
                            kind: nil
                        )
                    ]
                )
                return StubbedURLProtocol.response(for: url, data: payload)
            }
            if url.absoluteString.contains("kn-numeric.xml") {
                let xml = self.makeTranscriptXML(lines: transcriptLines)
                return StubbedURLProtocol.response(for: url, data: Data(xml.utf8))
            }
            throw URLError(.badURL)
        }

        let service = YouTubeImportService(session: session)

        do {
            _ = try await service.importVideo(videoID: videoID)
            XCTFail("Expected importVideo to reject numeric sequence transcript")
        } catch let error as YouTubeImportError {
            XCTAssertEqual(error, .lowQualityTranscript)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLoadBeginnerSuggestionsFiltersOutsideDurationRangeAndKeepsRankOrder() async {
        let channelToVideoID = [
            "UChsgGgFHYTBL4m0dgRc78PQ": "KaBYEZ6q2tY",
            "UClhQBYN17XW_lA4568Qtu3A": "Pho7XZTsPis",
            "UCirKrUfKVP2ebtwEWCObTbw": "RpJ-qH_vfD8",
            "UCqZRKIkmWX2L2iAIDjYi0Fw": "UKWBtAYAo5I",
            "UCe-zK4ux-tMl9Y8JJJqxL7Q": "ebQ0LPgoFkQ",
            "UCOG5uDioDLiIZsSmyYSKYHw": "m4llekMMKEg"
        ]
        let transcriptLines = [
            "ಇದು ಕನ್ನಡ ಅಭ್ಯಾಸಕ್ಕೆ ಉಪಯುಕ್ತವಾದ ಚಿಕ್ಕ ಪಾಠವಾಗಿದೆ.",
            "ಪ್ರತಿ ವಾಕ್ಯವನ್ನು ನಿಧಾನವಾಗಿ ಓದಿ ಅರ್ಥ ಮಾಡಿಕೊಂಡು ಮುಂದೆ ಸಾಗಿರಿ.",
            "ಕೇಳಿ, ಓದಿ, ಮತ್ತೆ ಪುನರಾವರ್ತನೆ ಮಾಡಿದರೆ ನೆನಪು ಗಟ್ಟಿಯಾಗುತ್ತದೆ.",
            "ಈ ಭಾಗವು ಪದಸಂಪತ್ತಿ ಮತ್ತು ಸರಳ ವ್ಯಾಕರಣವನ್ನು ಒಟ್ಟಿಗೆ ಅಭ್ಯಾಸ ಮಾಡಿಸುತ್ತದೆ."
        ]

        let session = makeStubbedSession { request in
            let url = try XCTUnwrap(request.url)
            if url.absoluteString.contains("youtube.com/feeds/videos.xml") {
                let channelID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "channel_id" })?
                    .value
                let videoID = channelID.flatMap { channelToVideoID[$0] }
                let xml = self.makeFeedXML(
                    channelID: channelID ?? "missing",
                    channelTitle: "Feed \(channelID ?? "missing")",
                    videos: videoID.map { [($0, "Seed \($0)", "2026-02-26T00:00:00+00:00")] } ?? []
                )
                return StubbedURLProtocol.response(for: url, data: Data(xml.utf8))
            }
            if url.absoluteString.contains("youtube.com/watch") {
                return StubbedURLProtocol.response(
                    for: url,
                    data: Data(self.makeWatchHTML(apiKey: "test-key").utf8)
                )
            }
            if url.absoluteString.contains("youtubei/v1/player") {
                let videoID = try self.extractVideoID(from: request)
                let duration = videoID == "RpJ-qH_vfD8" ? 1500 : 600
                let payload = self.makePlayerPayload(
                    videoID: videoID,
                    channelID: "channel-\(videoID)",
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
            if url.absoluteString.contains("example.com/"),
               url.pathExtension == "xml" {
                let xml = self.makeTranscriptXML(lines: transcriptLines)
                return StubbedURLProtocol.response(for: url, data: Data(xml.utf8))
            }
            throw URLError(.badURL)
        }

        let service = YouTubeImportService(session: session)
        let suggestions = await service.loadBeginnerSuggestions(forceRefresh: true)
        let ids = suggestions.map(\.videoID)

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

    func testLoadBeginnerSuggestionsFiltersLowQualityTranscriptCandidates() async {
        let validID = "KaBYEZ6q2tY"
        let lowQualityID = "UKWBtAYAo5I"

        let session = makeStubbedSession { request in
            let url = try XCTUnwrap(request.url)
            if url.absoluteString.contains("youtube.com/feeds/videos.xml") {
                let channelID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "channel_id" })?
                    .value
                let xml = self.makeFeedXML(
                    channelID: channelID ?? "missing",
                    channelTitle: "Feed \(channelID ?? "missing")",
                    videos: channelID == "UChsgGgFHYTBL4m0dgRc78PQ"
                        ? [
                            (validID, "Valid", "2026-02-26T00:00:00+00:00"),
                            (lowQualityID, "Low Quality", "2026-02-25T00:00:00+00:00")
                        ]
                        : []
                )
                return StubbedURLProtocol.response(for: url, data: Data(xml.utf8))
            }
            if url.absoluteString.contains("youtube.com/watch") {
                return StubbedURLProtocol.response(
                    for: url,
                    data: Data(self.makeWatchHTML(apiKey: "test-key").utf8)
                )
            }
            if url.absoluteString.contains("youtubei/v1/player") {
                let videoID = try self.extractVideoID(from: request)
                let payload = self.makePlayerPayload(
                    videoID: videoID,
                    channelID: "channel-\(videoID)",
                    durationSeconds: 600,
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
            if url.absoluteString.contains("\(validID).xml") {
                let xml = self.makeTranscriptXML(lines: [
                    "ಇದು ಕನ್ನಡದಲ್ಲಿ ಸ್ಪಷ್ಟವಾಗಿ ಓದಬಹುದಾದ ಪಾಠವಾಗಿದೆ.",
                    "ಈ ವಾಕ್ಯಗಳು ಆರಂಭಿಕರಿಗೆ ಸರಳವಾಗಿ ಅರ್ಥವಾಗುವಂತೆ ರಚಿಸಲಾಗಿದೆ.",
                    "ಪ್ರತಿದಿನ ಅಭ್ಯಾಸ ಮಾಡಿದರೆ ಓದುವ ವೇಗವೂ ಅರ್ಥೈಸುವ ಶಕ್ತಿಯೂ ಹೆಚ್ಚುತ್ತದೆ.",
                    "ಪದಗಳನ್ನು ಉಚ್ಚರಿಸಿ ಪುನರಾವರ್ತಿಸುವುದು ನೆನಪನ್ನು ಬಲಪಡಿಸುತ್ತದೆ."
                ])
                return StubbedURLProtocol.response(for: url, data: Data(xml.utf8))
            }
            if url.absoluteString.contains("\(lowQualityID).xml") {
                let xml = "<transcript><text>123 ABC</text></transcript>"
                return StubbedURLProtocol.response(for: url, data: Data(xml.utf8))
            }
            throw URLError(.badURL)
        }

        let service = YouTubeImportService(session: session)
        let suggestions = await service.loadBeginnerSuggestions(forceRefresh: true)

        XCTAssertEqual(suggestions.map(\.videoID), [validID])
    }

    func testLoadBeginnerSuggestionsFiltersVideosShorterThanFiveMinutes() async {
        let shortID = "ShrtA000001"
        let validID = "ValdA000001"

        let session = makeStubbedSession { request in
            let url = try XCTUnwrap(request.url)
            if url.absoluteString.contains("youtube.com/feeds/videos.xml") {
                let channelID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "channel_id" })?
                    .value
                let xml = self.makeFeedXML(
                    channelID: channelID ?? "missing",
                    channelTitle: "Feed \(channelID ?? "missing")",
                    videos: channelID == "UChsgGgFHYTBL4m0dgRc78PQ"
                        ? [
                            (shortID, "Too Short", "2026-02-26T00:00:00+00:00"),
                            (validID, "Valid", "2026-02-25T00:00:00+00:00")
                        ]
                        : []
                )
                return StubbedURLProtocol.response(for: url, data: Data(xml.utf8))
            }
            if url.absoluteString.contains("youtube.com/watch") {
                return StubbedURLProtocol.response(
                    for: url,
                    data: Data(self.makeWatchHTML(apiKey: "test-key").utf8)
                )
            }
            if url.absoluteString.contains("youtubei/v1/player") {
                let videoID = try self.extractVideoID(from: request)
                let duration = videoID == shortID ? 240 : 600
                let payload = self.makePlayerPayload(
                    videoID: videoID,
                    channelID: "channel-\(videoID)",
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
            if url.absoluteString.contains("example.com/"),
               url.pathExtension == "xml" {
                let xml = self.makeTranscriptXML(lines: [
                    "ಇದು ಕನ್ನಡ ಓದುವ ಅಭ್ಯಾಸಕ್ಕೆ ರೂಪಿಸಿದ ಸ್ಪಷ್ಟ ಮತ್ತು ಹಂತಹಂತದ ಪಾಠವಾಗಿದೆ.",
                    "ಪ್ರತಿ ವಾಕ್ಯವನ್ನು ಎರಡು ಬಾರಿ ಓದಿ ಪದಗಳ ಅರ್ಥವನ್ನು ಮನಸ್ಸಿನಲ್ಲಿ ದೃಢಪಡಿಸಿ.",
                    "ಶ್ರವಣದೊಂದಿಗೆ ಓದುವಿಕೆಯನ್ನೂ ಸೇರಿಸಿದರೆ ಭಾಷೆಯ ಅರಿವು ವೇಗವಾಗಿ ಹೆಚ್ಚುತ್ತದೆ.",
                    "ಪ್ರತಿದಿನ ಈ ರೀತಿಯ ಚಿಕ್ಕ ಅಭ್ಯಾಸ ಮಾಡಿದರೆ ಕನ್ನಡದಲ್ಲಿ ಆತ್ಮವಿಶ್ವಾಸ ಹೆಚ್ಚುತ್ತದೆ."
                ])
                return StubbedURLProtocol.response(for: url, data: Data(xml.utf8))
            }
            throw URLError(.badURL)
        }

        let service = YouTubeImportService(session: session)
        let suggestions = await service.loadBeginnerSuggestions(forceRefresh: true)

        XCTAssertEqual(suggestions.map(\.videoID), [validID])
    }
}

private final class StubbedURLProtocol: URLProtocol {
    private static var handlers: [String: (URLRequest) throws -> (HTTPURLResponse, Data)] = [:]
    private static let lock = NSLock()

    static func registerHandler(_ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> String {
        let id = UUID().uuidString
        lock.lock()
        handlers[id] = handler
        lock.unlock()
        return id
    }

    static func reset() {
        lock.lock()
        handlers.removeAll()
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        let handlers = Self.handlers
        Self.lock.unlock()

        let sessionID = request.value(forHTTPHeaderField: "X-Stub-Session-ID")
        if let sessionID, let handler = handlers[sessionID] {
            respond(using: handler)
            return
        }

        for handler in handlers.values {
            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
                return
            } catch let error as URLError where error.code == .badURL {
                continue
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
                return
            }
        }

        client?.urlProtocol(self, didFailWithError: URLError(.badURL))
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

    private func respond(using handler: (URLRequest) throws -> (HTTPURLResponse, Data)) {
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
}

private extension YouTubeImportServiceTests {
    func makeStubbedSession(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> URLSession {
        let sessionID = StubbedURLProtocol.registerHandler(handler)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubbedURLProtocol.self]
        config.httpAdditionalHeaders = ["X-Stub-Session-ID": sessionID]
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

    func makeCaptionTrack(
        languageCode: String,
        baseURL: String,
        kind: String?,
        isTranslatable: Bool?
    ) -> [String: Any] {
        var track = makeCaptionTrack(languageCode: languageCode, baseURL: baseURL, kind: kind)
        if let isTranslatable {
            track["isTranslatable"] = isTranslatable
        }
        return track
    }

    func makePlayerPayload(
        videoID: String,
        channelID: String,
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
                "channelId": channelID,
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

    func makeFeedXML(
        channelID: String,
        channelTitle: String,
        videos: [(videoID: String, title: String, published: String)]
    ) -> String {
        let entries = videos.map { video in
            """
            <entry>
                <yt:videoId>\(video.videoID)</yt:videoId>
                <title>\(video.title)</title>
                <published>\(video.published)</published>
                <author>
                    <name>\(channelTitle)</name>
                    <uri>https://www.youtube.com/channel/\(channelID)</uri>
                </author>
            </entry>
            """
        }.joined()

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns:yt="http://www.youtube.com/xml/schemas/2015">
            \(entries)
        </feed>
        """
    }

    func makeTranscriptXML(lines: [String]) -> String {
        let body = lines.enumerated().map { index, line in
            let start = Double(index) * 1.2
            return #"<text start="\#(start)" dur="1.0">\#(line)</text>"#
        }.joined()
        return "<transcript>\(body)</transcript>"
    }

    func extractVideoID(from request: URLRequest) throws -> String {
        if let body = bodyData(from: request),
           let json = try JSONSerialization.jsonObject(with: body) as? [String: Any],
           let videoID = json["videoId"] as? String {
            return videoID
        }
        throw URLError(.badURL)
    }

    private func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: buffer.count)
            if bytesRead < 0 {
                return nil
            }
            if bytesRead == 0 {
                break
            }
            data.append(buffer, count: bytesRead)
        }

        return data.isEmpty ? nil : data
    }
}
