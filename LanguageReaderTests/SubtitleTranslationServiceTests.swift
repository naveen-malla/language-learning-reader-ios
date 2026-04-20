import XCTest
@testable import LanguageReader

final class SubtitleTranslationServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SubtitleTranslatorStubURLProtocol.reset()
    }

    override func tearDown() {
        SubtitleTranslatorStubURLProtocol.reset()
        super.tearDown()
    }

    func testUsesCachedTranslationsWhenCompatible() async throws {
        let sourceCues = makeSourceCues()
        let cachedCues = [
            TranslatedSubtitleCue(startTime: 0, duration: 1.1, translatedText: "First"),
            TranslatedSubtitleCue(startTime: 1.4, duration: 1.0, translatedText: "Second")
        ]
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: FakeAzureSubtitleCueTranslator(results: [.success(["unused"])])
        )

        let result = await service.translateIfNeeded(sourceCues: sourceCues, cachedCues: cachedCues)

        XCTAssertEqual(result, .cached(cachedCues))
    }

    func testTranslatesThenReusesCacheOnNextCall() async throws {
        let sourceCues = makeSourceCues()
        let translator = FakeAzureSubtitleCueTranslator(results: [
            .success(["First", "Second"])
        ])
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: translator
        )

        let first = await service.translateIfNeeded(sourceCues: sourceCues, cachedCues: nil)
        guard case .translated(let translatedCues) = first else {
            return XCTFail("Expected translated cues on first call")
        }

        let second = await service.translateIfNeeded(sourceCues: sourceCues, cachedCues: translatedCues)

        XCTAssertEqual(second, .cached(translatedCues))
        let callCount = await translator.getCallCount()
        XCTAssertEqual(callCount, 1)
    }

    func testUsesPublicFallbackWhenAzureConfigurationIsMissing() async {
        let defaults = testDefaults()
        let publicTranslator = FakePublicSubtitleTranslator(results: [.success("First"), .success("Second")])
        let service = SubtitleTranslationService(
            settingsStore: TranslationSettingsStore(defaults: defaults, keychain: InMemorySecretStore()),
            translator: FakeAzureSubtitleCueTranslator(results: [.success(["unused"])]),
            publicTranslator: publicTranslator
        )

        let result = await service.translateIfNeeded(sourceCues: makeSourceCues(), cachedCues: nil)

        guard case .translated(let translated) = result else {
            return XCTFail("Expected public fallback translation")
        }
        XCTAssertEqual(translated.map(\.translatedText), ["First", "Second"])
        XCTAssertEqual(publicTranslator.callCount, 2)
    }

    func testReturnsUnavailableMessageWhenSourceCuesAreEmpty() async {
        let translator = FakeAzureSubtitleCueTranslator(results: [.success(["unused"])])
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: translator
        )

        let result = await service.translateIfNeeded(sourceCues: [], cachedCues: nil)

        XCTAssertEqual(result, .unavailable(SubtitleTranslationService.unavailableMessage))
        let callCount = await translator.getCallCount()
        XCTAssertEqual(callCount, 0)
    }

    func testFallsBackToPublicTranslationWhenAzureRequestFails() async throws {
        let publicTranslator = FakePublicSubtitleTranslator(results: [.success("First"), .success("Second")])
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: FakeAzureSubtitleCueTranslator(results: [
                .failure(AzureTranslatorClient.ClientError.serviceError("The request is not authorized."))
            ]),
            publicTranslator: publicTranslator
        )

        let result = await service.translateIfNeeded(sourceCues: makeSourceCues(), cachedCues: nil)

        guard case .translated(let translated) = result else {
            return XCTFail("Expected public fallback translation after Azure failure")
        }
        XCTAssertEqual(translated.map(\.translatedText), ["First", "Second"])
        XCTAssertEqual(publicTranslator.callCount, 2)
    }

    func testFallsBackToPublicTranslationWhenAzureReturnsUnreadableOutput() async throws {
        let publicTranslator = FakePublicSubtitleTranslator(results: [.success("First"), .success("Second")])
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: FakeAzureSubtitleCueTranslator(results: [
                .success([
                    "ಮೊದಲ ಸಾಲು",
                    "ಎರಡನೇ ಸಾಲು"
                ])
            ]),
            publicTranslator: publicTranslator
        )

        let result = await service.translateIfNeeded(sourceCues: makeSourceCues(), cachedCues: nil)

        guard case .translated(let translated) = result else {
            return XCTFail("Expected public fallback translation after unreadable Azure output")
        }
        XCTAssertEqual(translated.map(\.translatedText), ["First", "Second"])
        XCTAssertEqual(publicTranslator.callCount, 2)
    }

    func testCachedTranslationsAreStillReusedAfterTransientFailure() async throws {
        let sourceCues = makeSourceCues()
        let cachedCues = [
            TranslatedSubtitleCue(startTime: 0, duration: 1.1, translatedText: "First"),
            TranslatedSubtitleCue(startTime: 1.4, duration: 1.0, translatedText: "Second")
        ]
        let translator = FakeAzureSubtitleCueTranslator(results: [
            .failure(FakeAzureSubtitleCueTranslator.FakeError.failed),
            .success(["First", "Second"])
        ])
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: translator,
            publicTranslator: FakePublicSubtitleTranslator(results: [
                .failure(FakePublicSubtitleTranslator.FakeError.failed),
                .failure(FakePublicSubtitleTranslator.FakeError.failed)
            ])
        )

        let first = await service.translateIfNeeded(sourceCues: sourceCues, cachedCues: nil)
        XCTAssertEqual(first, .unavailable(SubtitleTranslationService.unavailableMessage))

        let second = await service.translateIfNeeded(sourceCues: sourceCues, cachedCues: cachedCues)

        XCTAssertEqual(second, .cached(cachedCues))
        let callCount = await translator.getCallCount()
        XCTAssertEqual(callCount, 1)
    }

    func testFallsBackToPublicTranslationWhenAzureReturnsWrongCueCount() async throws {
        let publicTranslator = FakePublicSubtitleTranslator(results: [.success("First"), .success("Second")])
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: FakeAzureSubtitleCueTranslator(results: [
                .success(["Only one line"])
            ]),
            publicTranslator: publicTranslator
        )

        let result = await service.translateIfNeeded(sourceCues: makeSourceCues(), cachedCues: nil)

        guard case .translated(let translated) = result else {
            return XCTFail("Expected public fallback translation after wrong cue count")
        }
        XCTAssertEqual(translated.map(\.translatedText), ["First", "Second"])
        XCTAssertEqual(publicTranslator.callCount, 2)
    }

    func testIncompatibleCachedCuesDoNotBypassRetranslation() async throws {
        let sourceCues = makeSourceCues()
        let incompatibleCachedCues = [
            TranslatedSubtitleCue(startTime: 0, duration: 1.1, translatedText: "Stale First"),
            TranslatedSubtitleCue(startTime: 5.0, duration: 1.0, translatedText: "Stale Second")
        ]
        let translator = FakeAzureSubtitleCueTranslator(results: [
            .success(["First", "Second"])
        ])
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: translator
        )

        let result = await service.translateIfNeeded(
            sourceCues: sourceCues,
            cachedCues: incompatibleCachedCues
        )

        guard case .translated(let translated) = result else {
            return XCTFail("Expected fresh translation when cache is incompatible")
        }

        XCTAssertEqual(translated.map(\.translatedText), ["First", "Second"])
        let callCount = await translator.getCallCount()
        XCTAssertEqual(callCount, 1)
    }

    func testReturnsUnavailableWhenAzureAndPublicOutputsAreUnreadable() async throws {
        let publicTranslator = FakePublicSubtitleTranslator(results: [.success("ಮೊದಲ ಸಾಲು"), .success("ಎರಡನೇ ಸಾಲು")])
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: FakeAzureSubtitleCueTranslator(results: [
                .success(["First line", "ಎರಡನೇ ಸಾಲು"])
            ]),
            publicTranslator: publicTranslator
        )

        let result = await service.translateIfNeeded(sourceCues: makeSourceCues(), cachedCues: nil)

        XCTAssertEqual(result, .unavailable(SubtitleTranslationService.unavailableMessage))
    }

    func testTranslatorReceivesEnglishTargetLanguage() async throws {
        let translator = FakeAzureSubtitleCueTranslator(results: [
            .success(["First", "Second"])
        ])
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: translator
        )

        _ = await service.translateIfNeeded(sourceCues: makeSourceCues(), cachedCues: nil)

        let configurations = await translator.getReceivedConfigurations()
        XCTAssertEqual(configurations.count, 1)
        XCTAssertEqual(configurations.first?.targetLanguage, "en")
        XCTAssertEqual(configurations.first?.sourceLanguage, "kn")
    }

    func testTranslatorReceivesExplicitGermanSourceLanguage() async throws {
        let translator = FakeAzureSubtitleCueTranslator(results: [
            .success(["This is a house."])
        ])
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: translator
        )

        _ = await service.translateIfNeeded(
            sourceCues: [
                TimedSubtitleCue(startTime: 0, duration: 1.2, sourceText: "Das ist ein Haus.")
            ],
            cachedCues: nil,
            sourceLanguage: "de-DE",
            targetLanguage: "en-US"
        )

        let configurations = await translator.getReceivedConfigurations()
        XCTAssertEqual(configurations.count, 1)
        XCTAssertEqual(configurations.first?.sourceLanguage, "de")
        XCTAssertEqual(configurations.first?.targetLanguage, "en")
    }

    func testFallsBackToPublicWhenGermanAzureOutputMatchesSource() async throws {
        let publicTranslator = FakePublicSubtitleTranslator(results: [.success("This is a house.")])
        let service = SubtitleTranslationService(
            settingsStore: configuredSettings(),
            translator: FakeAzureSubtitleCueTranslator(results: [
                .success(["Das ist ein Haus."])
            ]),
            publicTranslator: publicTranslator
        )

        let result = await service.translateIfNeeded(
            sourceCues: [
                TimedSubtitleCue(startTime: 0, duration: 1.2, sourceText: "Das ist ein Haus.")
            ],
            cachedCues: nil,
            sourceLanguage: "de",
            targetLanguage: "en"
        )

        guard case .translated(let translated) = result else {
            return XCTFail("Expected public fallback translation for German cue")
        }
        XCTAssertEqual(translated.map(\.translatedText), ["This is a house."])
        XCTAssertEqual(publicTranslator.callCount, 1)
    }

    func testAzureSubtitleCueTranslatorRetriesWithoutSourceLanguageOnServiceError() async throws {
        var callCount = 0
        let translator = AzureSubtitleCueTranslator(session: makeSubtitleTranslatorStubbedSession { [self] request in
            callCount += 1
            let response: HTTPURLResponse
            let data: Data

            if callCount == 1 {
                response = try XCTUnwrap(
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 400,
                        httpVersion: nil,
                        headerFields: nil
                    )
                )
                data = Data("""
                {
                  "error": {
                    "code": 400036,
                    "message": "The 'from' language code is invalid."
                  }
                }
                """.utf8)
            } else {
                response = try XCTUnwrap(
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )
                )
                data = Data("""
                [
                  { "translations": [ { "text": "First", "to": "en" } ] },
                  { "translations": [ { "text": "Second", "to": "en" } ] }
                ]
                """.utf8)
            }

            return (response, data)
        })

        let output = try await translator.translate(
            texts: ["ಮೊದಲ ಸಾಲು", "ಎರಡನೇ ಸಾಲು"],
            configuration: translatorConfig(sourceLanguage: "kn")
        )

        XCTAssertEqual(output, ["First", "Second"])
        XCTAssertEqual(callCount, 2)

        let requests = SubtitleTranslatorStubURLProtocol.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0].url?.queryValue(named: "from"), "kn")
        XCTAssertNil(requests[1].url?.queryValue(named: "from"))
        XCTAssertEqual(requests[1].url?.queryValue(named: "to"), "en")
    }

    func testAzureSubtitleCueTranslatorSplitsRequestsWhenElementLimitIsExceeded() async throws {
        let inputCount = 1_001
        let sourceTexts = (0..<inputCount).map { index in
            "ಸಾಲು \(index)"
        }

        let translator = AzureSubtitleCueTranslator(session: makeSubtitleTranslatorStubbedSession { request in
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )

            let payload = try self.translatorRequestPayload(request)
            let translatedPayload = payload.map { item -> String in
                let text = item["Text"] ?? ""
                return "EN: \(text)"
            }
            let data = Data(self.makeTranslatorResponseJSON(texts: translatedPayload).utf8)
            return (response, data)
        })

        let translated = try await translator.translate(
            texts: sourceTexts,
            configuration: translatorConfig(sourceLanguage: "kn")
        )

        XCTAssertEqual(translated.count, inputCount)
        XCTAssertEqual(translated.first, "EN: ಸಾಲು 0")
        XCTAssertEqual(translated.last, "EN: ಸಾಲು 1000")

        let requests = SubtitleTranslatorStubURLProtocol.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(try translatorRequestBodyCount(requests[0]), 1_000)
        XCTAssertEqual(try translatorRequestBodyCount(requests[1]), 1)
    }

    func testAzureSubtitleCueTranslatorRetriesWithAutoDetectWhenOutputIsUnchanged() async throws {
        var callCount = 0
        let sourceTexts = ["ಮೊದಲ ಸಾಲು", "ಎರಡನೇ ಸಾಲು"]
        let translator = AzureSubtitleCueTranslator(session: makeSubtitleTranslatorStubbedSession { request in
            callCount += 1
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )

            let outputTexts: [String]
            if callCount == 1 {
                outputTexts = sourceTexts
            } else {
                outputTexts = ["First line", "Second line"]
            }

            return (response, Data(self.makeTranslatorResponseJSON(texts: outputTexts).utf8))
        })

        let translated = try await translator.translate(
            texts: sourceTexts,
            configuration: translatorConfig(sourceLanguage: "kn")
        )

        XCTAssertEqual(translated, ["First line", "Second line"])
        XCTAssertEqual(callCount, 2)

        let requests = SubtitleTranslatorStubURLProtocol.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0].url?.queryValue(named: "from"), "kn")
        XCTAssertNil(requests[1].url?.queryValue(named: "from"))
    }

    func testAzureSubtitleCueTranslatorDoesNotRetryWithAutoDetectForNonKannadaSource() async throws {
        var callCount = 0
        let sourceTexts = ["hola", "adios"]
        let translator = AzureSubtitleCueTranslator(session: makeSubtitleTranslatorStubbedSession { request in
            callCount += 1
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, Data(self.makeTranslatorResponseJSON(texts: sourceTexts).utf8))
        })

        let translated = try await translator.translate(
            texts: sourceTexts,
            configuration: translatorConfig(sourceLanguage: "es")
        )

        XCTAssertEqual(translated, sourceTexts)
        XCTAssertEqual(callCount, 1)

        let requests = SubtitleTranslatorStubURLProtocol.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].url?.queryValue(named: "from"), "es")
    }

    private func configuredSettings() -> TranslationSettingsStore {
        let defaults = testDefaults()
        let keychain = InMemorySecretStore()
        let settings = TranslationSettingsStore(defaults: defaults, keychain: keychain)
        settings.regionText = "eastus"
        try! settings.saveAPIKey("secret")
        return settings
    }

    private func makeSourceCues() -> [TimedSubtitleCue] {
        [
            TimedSubtitleCue(startTime: 0, duration: 1.1, sourceText: "ಮೊದಲ ಸಾಲು"),
            TimedSubtitleCue(startTime: 1.4, duration: 1.0, sourceText: "ಎರಡನೇ ಸಾಲು")
        ]
    }

    private func testDefaults() -> UserDefaults {
        let name = "SubtitleTranslationServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func translatorConfig(sourceLanguage: String) -> AzureTranslatorConfiguration {
        AzureTranslatorConfiguration(
            endpoint: URL(string: "https://api.cognitive.microsofttranslator.com")!,
            region: nil,
            apiKey: "secret",
            sourceLanguage: sourceLanguage,
            targetLanguage: "en"
        )
    }

    private func makeSubtitleTranslatorStubbedSession(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> URLSession {
        SubtitleTranslatorStubURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SubtitleTranslatorStubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeTranslatorResponseJSON(texts: [String]) -> String {
        let rows = texts.map { text in
            "{ \"translations\": [ { \"text\": \"\(text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\", \"to\": \"en\" } ] }"
        }
        return "[\(rows.joined(separator: ","))]"
    }

    private func translatorRequestBodyCount(_ request: URLRequest) throws -> Int {
        try translatorRequestPayload(request).count
    }

    private func translatorRequestPayload(_ request: URLRequest) throws -> [[String: String]] {
        let body = try requestBodyData(from: request)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [[String: String]]
        )
    }

    private func requestBodyData(from request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            return body
        }

        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open()
        defer { stream.close() }

        var buffer = Array(repeating: UInt8(0), count: 4096)
        var data = Data()

        while stream.hasBytesAvailable {
            let readCount = stream.read(&buffer, maxLength: buffer.count)
            if readCount < 0 {
                throw try XCTUnwrap(stream.streamError)
            }
            if readCount == 0 {
                break
            }
            data.append(buffer, count: readCount)
        }

        return data
    }
}

private actor FakeAzureSubtitleCueTranslator: AzureSubtitleCueTranslating {
    enum FakeError: Error {
        case failed
    }

    private let results: [Result<[String], Error>]
    private var callCount = 0
    private var receivedConfigurations: [AzureTranslatorConfiguration] = []

    init(results: [Result<[String], Error>]) {
        self.results = results.isEmpty ? [.success([])] : results
    }

    func translate(texts: [String], configuration: AzureTranslatorConfiguration) async throws -> [String] {
        callCount += 1
        receivedConfigurations.append(configuration)
        let index = min(callCount - 1, results.count - 1)
        return try results[index].get()
    }

    func getCallCount() -> Int {
        callCount
    }

    func getReceivedConfigurations() -> [AzureTranslatorConfiguration] {
        receivedConfigurations
    }
}

private final class FakePublicSubtitleTranslator: PublicSentenceTranslating {
    enum FakeError: Error {
        case failed
    }

    private let results: [Result<String, Error>]
    private(set) var callCount = 0

    init(results: [Result<String, Error>]) {
        self.results = results.isEmpty ? [.failure(FakeError.failed)] : results
    }

    func translate(text: String, sourceLanguage: String, targetLanguage: String) async throws -> String {
        callCount += 1
        let index = min(callCount - 1, results.count - 1)
        return try results[index].get()
    }
}

private final class InMemorySecretStore: SecretStoring {
    private var values: [String: String] = [:]

    func read(account: String) -> String? {
        values[account]
    }

    func write(_ value: String, account: String) throws {
        values[account] = value
    }

    func delete(account: String) throws {
        values.removeValue(forKey: account)
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

private final class SubtitleTranslatorStubURLProtocol: URLProtocol {
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
