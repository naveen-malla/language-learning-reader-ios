import XCTest
@testable import LanguageReader

final class PublicWebTranslatorClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PublicTranslatorStubURLProtocol.reset()
    }

    override func tearDown() {
        PublicTranslatorStubURLProtocol.reset()
        super.tearDown()
    }

    func testParseTranslationReadsJoinedSegments() throws {
        let client = PublicWebTranslatorClient(session: .shared)
        let data = Data("""
        [
          [
            ["you can", "ಇದು", null, null, 1],
            [" translate", " ಪರೀಕ್ಷೆ", null, null, 1]
          ],
          null,
          "kn"
        ]
        """.utf8)

        let output = try client.parseTranslation(data: data)
        XCTAssertEqual(output, "you can translate")
    }

    func testTranslateBuildsExpectedRequestAndParsesResponse() async throws {
        let client = PublicWebTranslatorClient(session: makeStubbedSession { request in
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
              [["this is a test", "ಇದು ಒಂದು ಪರೀಕ್ಷೆ", null, null, 1]],
              null,
              "kn"
            ]
            """.utf8)
            return (response, data)
        })

        let output = try await client.translate(
            text: "ಇದು ಒಂದು ಪರೀಕ್ಷೆ",
            sourceLanguage: "kn",
            targetLanguage: "en"
        )

        XCTAssertEqual(output, "this is a test")
        let request = try XCTUnwrap(PublicTranslatorStubURLProtocol.requests.first)
        XCTAssertEqual(request.url?.host, "translate.googleapis.com")
        XCTAssertEqual(request.url?.queryValue(named: "client"), "gtx")
        XCTAssertEqual(request.url?.queryValue(named: "sl"), "kn")
        XCTAssertEqual(request.url?.queryValue(named: "tl"), "en")
    }

    private func makeStubbedSession(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> URLSession {
        PublicTranslatorStubURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PublicTranslatorStubURLProtocol.self]
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

private final class PublicTranslatorStubURLProtocol: URLProtocol {
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
