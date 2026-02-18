import XCTest
@testable import LanguageReader

final class YouTubeImportServiceTests: XCTestCase {
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
}
