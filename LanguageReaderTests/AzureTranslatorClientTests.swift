import XCTest
@testable import LanguageReader

final class AzureTranslatorClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AzureTranslatorStubURLProtocol.reset()
    }

    override func tearDown() {
        AzureTranslatorStubURLProtocol.reset()
        super.tearDown()
    }

    func testParseTranslationReadsFirstTranslationText() throws {
        let client = AzureTranslatorClient(session: .shared)
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
        let client = AzureTranslatorClient(session: .shared)
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

    func testTranslateOmitsRegionHeaderWhenRegionMissing() async throws {
        let client = AzureTranslatorClient(session: makeStubbedSession { request in
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            let data = Data("""
            [
              { "translations": [ { "text": "impressed", "to": "en" } ] }
            ]
            """.utf8)
            return (response, data)
        })

        let config = AzureTranslatorConfiguration(
            endpoint: URL(string: "https://api.cognitive.microsofttranslator.com")!,
            region: nil,
            apiKey: "secret",
            sourceLanguage: "kn",
            targetLanguage: "en"
        )

        let output = try await client.translate(text: "ಇಂಪ್ರೆಸ್ ಮಾಡಬಹುದು", configuration: config)
        XCTAssertEqual(output, "impressed")

        let requests = AzureTranslatorStubURLProtocol.requests
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Ocp-Apim-Subscription-Key"), "secret")
        XCTAssertNil(request.value(forHTTPHeaderField: "Ocp-Apim-Subscription-Region"))
        XCTAssertEqual(request.url?.queryValue(named: "from"), "kn")
        XCTAssertEqual(request.url?.queryValue(named: "to"), "en")
    }

    func testTranslateIncludesRegionHeaderWhenProvided() async throws {
        let client = AzureTranslatorClient(session: makeStubbedSession { request in
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            let data = Data("""
            [
              { "translations": [ { "text": "forward movement", "to": "en" } ] }
            ]
            """.utf8)
            return (response, data)
        })

        let config = AzureTranslatorConfiguration(
            endpoint: URL(string: "https://api.cognitive.microsofttranslator.com")!,
            region: "eastus",
            apiKey: "secret",
            sourceLanguage: "kn",
            targetLanguage: "en"
        )

        _ = try await client.translate(text: "ಇದೊಂದು ಚಲನೆ", configuration: config)

        let request = try XCTUnwrap(AzureTranslatorStubURLProtocol.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Ocp-Apim-Subscription-Region"), "eastus")
    }

    func testTranslateRetriesWithoutFromWhenSourceRejected() async throws {
        var callCount = 0
        let client = AzureTranslatorClient(session: makeStubbedSession { request in
            callCount += 1
            if callCount == 1 {
                let response = try XCTUnwrap(
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 400,
                        httpVersion: nil,
                        headerFields: nil
                    )
                )
                let data = Data("""
                {
                  "error": {
                    "code": 400036,
                    "message": "The 'from' language is not valid."
                  }
                }
                """.utf8)
                return (response, data)
            }

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            let data = Data("""
            [
              { "translations": [ { "text": "this is fine", "to": "en" } ] }
            ]
            """.utf8)
            return (response, data)
        })

        let config = AzureTranslatorConfiguration(
            endpoint: URL(string: "https://api.cognitive.microsofttranslator.com")!,
            region: nil,
            apiKey: "secret",
            sourceLanguage: "invalid-code",
            targetLanguage: "en"
        )

        let output = try await client.translate(text: "ಇದು ಚೆನ್ನಾಗಿದೆ", configuration: config)
        XCTAssertEqual(output, "this is fine")
        XCTAssertEqual(callCount, 2)

        let requests = AzureTranslatorStubURLProtocol.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0].url?.queryValue(named: "from"), "invalid-code")
        XCTAssertNil(requests[1].url?.queryValue(named: "from"))
        XCTAssertEqual(requests[1].url?.queryValue(named: "to"), "en")
    }

    func testTranslateRetriesAutoDetectWhenResponseUnchangedForKannada() async throws {
        var callCount = 0
        let sourceText = "ಇಂಪ್ರೆಸ್ ಮಾಡಬಹುದು ಯಾರಿಂದಾದರೂ ನಿಮ್ಮ"
        let client = AzureTranslatorClient(session: makeStubbedSession { request in
            callCount += 1
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )

            if callCount == 1 {
                let data = Data("""
                [
                  { "translations": [ { "text": "\(sourceText)", "to": "en" } ] }
                ]
                """.utf8)
                return (response, data)
            }

            let data = Data("""
            [
              { "translations": [ { "text": "you can impress anyone", "to": "en" } ] }
            ]
            """.utf8)
            return (response, data)
        })

        let config = AzureTranslatorConfiguration(
            endpoint: URL(string: "https://api.cognitive.microsofttranslator.com")!,
            region: nil,
            apiKey: "secret",
            sourceLanguage: "kn",
            targetLanguage: "en"
        )

        let output = try await client.translate(text: sourceText, configuration: config)
        XCTAssertEqual(output, "you can impress anyone")
        XCTAssertEqual(callCount, 2)

        let requests = AzureTranslatorStubURLProtocol.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0].url?.queryValue(named: "from"), "kn")
        XCTAssertNil(requests[1].url?.queryValue(named: "from"))
    }

    private func makeStubbedSession(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> URLSession {
        AzureTranslatorStubURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AzureTranslatorStubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private extension URL {
    func queryValue(named key: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == key })?
            .value
    }
}

private final class AzureTranslatorStubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    private static var storedRequests: [URLRequest] = []
    private static let lock = NSLock()

    static var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storedRequests
    }

    static func reset() {
        lock.lock()
        storedRequests = []
        handler = nil
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            Self.lock.lock()
            Self.storedRequests.append(request)
            Self.lock.unlock()

            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
