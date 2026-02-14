import XCTest
@testable import LanguageReader

final class AzureTranslatorClientTests: XCTestCase {
    private let client = AzureTranslatorClient(session: .shared)

    func testParseTranslationReadsFirstTranslationText() throws {
        let data = Data("""
        [
          {
            "translations": [
              { "text": "hello world", "to": "en" }
            ]
          }
        ]
        """.utf8)

        let translated = try client.parseTranslation(data: data)
        XCTAssertEqual(translated, "hello world")
    }

    func testParseServiceErrorReadsMessage() {
        let data = Data("""
        {
          "error": {
            "code": 401000,
            "message": "The request is not authorized."
          }
        }
        """.utf8)

        XCTAssertEqual(client.parseServiceError(data: data), "The request is not authorized.")
    }
}
