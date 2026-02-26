import Foundation
import XCTest
@testable import LanguageReader

final class YouTubeDiscoveryServiceTests: XCTestCase {
    override func tearDown() {
        DiscoveryStubURLProtocol.reset()
        super.tearDown()
    }

    func testLoadSuggestionsSkipsMalformedFeedsAndValidationFailures() async {
        let defaults = UserDefaults(suiteName: "YouTubeDiscoveryServiceTests.\(UUID().uuidString)")!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = SuggestionCacheStore(defaults: defaults, storageKey: "cache", now: { now })
        let validator = DiscoveryValidatorStub(failingVideoIDs: ["BBBBBBBBBBB"])
        let session = makeStubbedSession { request in
            let url = try XCTUnwrap(request.url)
            guard url.absoluteString.contains("youtube.com/feeds/videos.xml") else {
                throw URLError(.badURL)
            }

            let channelID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "channel_id" })?
                .value ?? ""

            switch channelID {
            case "UChsgGgFHYTBL4m0dgRc78PQ":
                let xml = self.makeFeedXML(
                    channelID: channelID,
                    channelTitle: "Channel One",
                    videos: [
                        ("AAAAAAAAAAA", "Valid One", "2026-02-25T00:00:00+00:00"),
                        ("BBBBBBBBBBB", "Filtered Two", "2026-02-24T00:00:00+00:00")
                    ]
                )
                return DiscoveryStubURLProtocol.response(for: url, data: Data(xml.utf8))
            case "UClhQBYN17XW_lA4568Qtu3A":
                let malformed = "<feed><entry><yt:videoId>BAD</yt:videoId>"
                return DiscoveryStubURLProtocol.response(for: url, data: Data(malformed.utf8))
            default:
                let empty = self.makeFeedXML(channelID: channelID, channelTitle: "Empty", videos: [])
                return DiscoveryStubURLProtocol.response(for: url, data: Data(empty.utf8))
            }
        }

        let service = YouTubeDiscoveryService(
            session: session,
            cacheStore: cache,
            validator: validator,
            now: { now }
        )

        let suggestions = await service.loadSuggestions(existingVideoIDs: [], forceRefresh: true)
        XCTAssertEqual(suggestions.map(\.videoID), ["AAAAAAAAAAA"])

        let calls = await validator.callCount(for: "AAAAAAAAAAA")
        let filteredCalls = await validator.callCount(for: "BBBBBBBBBBB")
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(filteredCalls, 1)
    }

    func testLoadSuggestionsUsesCacheWithoutRevalidating() async {
        let defaults = UserDefaults(suiteName: "YouTubeDiscoveryServiceTests.\(UUID().uuidString)")!
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = SuggestionCacheStore(defaults: defaults, storageKey: "cache", now: { now })
        let validator = DiscoveryValidatorStub(failingVideoIDs: [])
        let requestCounter = DiscoveryRequestCounter()
        let session = makeStubbedSession { request in
            let url = try XCTUnwrap(request.url)
            guard url.absoluteString.contains("youtube.com/feeds/videos.xml") else {
                throw URLError(.badURL)
            }
            await requestCounter.increment()

            let channelID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "channel_id" })?
                .value ?? ""
            let xml = self.makeFeedXML(
                channelID: channelID,
                channelTitle: "Channel",
                videos: channelID == "UChsgGgFHYTBL4m0dgRc78PQ"
                    ? [("CCCCCCCCCCC", "Cached Candidate", "2026-02-26T00:00:00+00:00")]
                    : []
            )
            return DiscoveryStubURLProtocol.response(for: url, data: Data(xml.utf8))
        }

        let service = YouTubeDiscoveryService(
            session: session,
            cacheStore: cache,
            validator: validator,
            now: { now }
        )

        let first = await service.loadSuggestions(existingVideoIDs: [], forceRefresh: true)
        XCTAssertEqual(first.map(\.videoID), ["CCCCCCCCCCC"])
        let firstValidationCalls = await validator.callCount(for: "CCCCCCCCCCC")
        XCTAssertEqual(firstValidationCalls, 1)

        let firstRequestCount = await requestCounter.value()
        XCTAssertGreaterThan(firstRequestCount, 0)

        now = now.addingTimeInterval(60)
        let second = await service.loadSuggestions(existingVideoIDs: [], forceRefresh: false)
        XCTAssertEqual(second.map(\.videoID), ["CCCCCCCCCCC"])

        let secondValidationCalls = await validator.callCount(for: "CCCCCCCCCCC")
        let secondRequestCount = await requestCounter.value()
        XCTAssertEqual(secondValidationCalls, 1)
        XCTAssertEqual(secondRequestCount, firstRequestCount)
    }

    func testLoadSuggestionsReturnsExpiredCacheDuringBackoff() async {
        let defaults = UserDefaults(suiteName: "YouTubeDiscoveryServiceTests.\(UUID().uuidString)")!
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = SuggestionCacheStore(defaults: defaults, storageKey: "cache", now: { now })
        let cachedSuggestion = YouTubeSuggestedVideo(
            videoID: "DDDDDDDDDDD",
            title: "Cached",
            channelTitle: "Cached Channel",
            channelID: "UC-CACHED",
            category: "Basics",
            durationSeconds: 120,
            thumbnailURL: nil,
            publishedAt: now
        )

        await cache.saveSuggestions([cachedSuggestion])
        now = now.addingTimeInterval(9 * 60 * 60) // Expire normal cache window.
        await cache.recordDiscoveryFailure() // Enables backoff.

        let validator = DiscoveryValidatorStub(failingVideoIDs: [])
        let requestCounter = DiscoveryRequestCounter()
        let session = makeStubbedSession { request in
            let url = try XCTUnwrap(request.url)
            if url.absoluteString.contains("youtube.com/feeds/videos.xml") {
                await requestCounter.increment()
            }
            throw URLError(.badURL)
        }

        let service = YouTubeDiscoveryService(
            session: session,
            cacheStore: cache,
            validator: validator,
            now: { now }
        )

        let suggestions = await service.loadSuggestions(existingVideoIDs: [], forceRefresh: false)
        let requestCount = await requestCounter.value()
        XCTAssertEqual(suggestions.map(\.videoID), ["DDDDDDDDDDD"])
        XCTAssertEqual(requestCount, 0)
    }
}

private actor DiscoveryValidatorStub: YouTubeCandidateValidating {
    private var counts: [String: Int] = [:]
    private let failingVideoIDs: Set<String>

    init(failingVideoIDs: Set<String>) {
        self.failingVideoIDs = failingVideoIDs
    }

    func validateCandidate(
        videoID: String,
        category: String,
        publishedAt: Date?,
        fallbackTitle: String?,
        fallbackChannelTitle: String?,
        fallbackChannelID: String?
    ) async throws -> YouTubeSuggestedVideo {
        counts[videoID, default: 0] += 1
        if failingVideoIDs.contains(videoID) {
            throw YouTubeImportError.kannadaCaptionsUnavailable
        }

        return YouTubeSuggestedVideo(
            videoID: videoID,
            title: fallbackTitle ?? "Title \(videoID)",
            channelTitle: fallbackChannelTitle ?? "Channel \(videoID)",
            channelID: fallbackChannelID,
            category: category,
            durationSeconds: 180,
            thumbnailURL: nil,
            publishedAt: publishedAt
        )
    }

    func callCount(for videoID: String) -> Int {
        counts[videoID, default: 0]
    }
}

private actor DiscoveryRequestCounter {
    private var count = 0

    func increment() {
        count += 1
    }

    func value() -> Int {
        count
    }
}

private final class DiscoveryStubURLProtocol: URLProtocol {
    private static var handlers: [String: (URLRequest) async throws -> (HTTPURLResponse, Data)] = [:]
    private static let lock = NSLock()

    static func registerHandler(_ handler: @escaping (URLRequest) async throws -> (HTTPURLResponse, Data)) -> String {
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

        let sessionID = request.value(forHTTPHeaderField: "X-Discovery-Stub-ID")
        guard let sessionID, let handler = handlers[sessionID] else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        Task {
            do {
                let (response, data) = try await handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
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

private extension YouTubeDiscoveryServiceTests {
    func makeStubbedSession(
        handler: @escaping (URLRequest) async throws -> (HTTPURLResponse, Data)
    ) -> URLSession {
        let sessionID = DiscoveryStubURLProtocol.registerHandler(handler)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DiscoveryStubURLProtocol.self]
        config.httpAdditionalHeaders = ["X-Discovery-Stub-ID": sessionID]
        return URLSession(configuration: config)
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
}
