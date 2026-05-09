import XCTest
@testable import LanguageReader

final class ScreenshotLaunchConfigurationTests: XCTestCase {
    func testParseRouteMapsSupportedTabs() {
        XCTAssertEqual(ScreenshotLaunchConfiguration.parseRoute("library"), .tab(.library))
        XCTAssertEqual(ScreenshotLaunchConfiguration.parseRoute("vocab"), .tab(.vocab))
        XCTAssertEqual(ScreenshotLaunchConfiguration.parseRoute("flashcards"), .tab(.flashcards))
        XCTAssertEqual(ScreenshotLaunchConfiguration.parseRoute("settings"), .tab(.settings))
        XCTAssertEqual(ScreenshotLaunchConfiguration.parseRoute("flashcards-session"), .flashcardsSession)
        XCTAssertEqual(ScreenshotLaunchConfiguration.parseRoute("watch"), .watch)
    }

    func testParseRouteSupportsReaderAndIgnoresUnknownValues() {
        XCTAssertEqual(ScreenshotLaunchConfiguration.parseRoute("reader"), .reader)
        XCTAssertNil(ScreenshotLaunchConfiguration.parseRoute("unknown"))
        XCTAssertNil(ScreenshotLaunchConfiguration.parseRoute("   "))
    }

    func testScreenshotModeDisablesAutoTopUp() {
        let processInfo = ProcessInfoStub(environment: [
            ScreenshotLaunchConfiguration.routeEnvironmentKey: "vocab"
        ], arguments: [])

        let configuration = ScreenshotLaunchConfiguration(processInfo: processInfo)

        XCTAssertEqual(configuration.initialTab, .vocab)
        XCTAssertFalse(configuration.shouldRunAutoTopUp)
    }

    func testDefaultConfigurationKeepsAutoTopUpEnabled() {
        let configuration = ScreenshotLaunchConfiguration(
            processInfo: ProcessInfoStub(environment: [:], arguments: [])
        )

        XCTAssertEqual(configuration.initialTab, .library)
        XCTAssertTrue(configuration.shouldRunAutoTopUp)
    }

    func testLaunchArgumentsConfigureRouteAndDemoSeed() {
        let processInfo = ProcessInfoStub(
            environment: [:],
            arguments: [
                ScreenshotLaunchConfiguration.seedDemoDataArgument,
                "\(ScreenshotLaunchConfiguration.routeArgumentPrefix)flashcards-session"
            ]
        )

        let configuration = ScreenshotLaunchConfiguration(processInfo: processInfo)

        XCTAssertEqual(configuration.route, .flashcardsSession)
        XCTAssertEqual(configuration.initialTab, .flashcards)
        XCTAssertTrue(configuration.shouldSeedDemoData)
        XCTAssertFalse(configuration.shouldRunAutoTopUp)
    }

    func testRouteArgumentOverridesEnvironmentRoute() {
        let processInfo = ProcessInfoStub(
            environment: [
                ScreenshotLaunchConfiguration.routeEnvironmentKey: "vocab"
            ],
            arguments: [
                "\(ScreenshotLaunchConfiguration.routeArgumentPrefix)reader"
            ]
        )

        let configuration = ScreenshotLaunchConfiguration(processInfo: processInfo)

        XCTAssertEqual(configuration.route, .reader)
    }

    func testEnvironmentRouteIsTrimmedAndCaseInsensitive() {
        let processInfo = ProcessInfoStub(
            environment: [
                ScreenshotLaunchConfiguration.routeEnvironmentKey: "  WaTcH "
            ],
            arguments: []
        )

        let configuration = ScreenshotLaunchConfiguration(processInfo: processInfo)

        XCTAssertEqual(configuration.route, .watch)
        XCTAssertEqual(configuration.initialTab, .library)
        XCTAssertFalse(configuration.shouldRunAutoTopUp)
    }

    func testEnvironmentSeedFlagEnablesDemoModeWithoutRoute() {
        let processInfo = ProcessInfoStub(
            environment: [
                ScreenshotLaunchConfiguration.seedDemoDataEnvironmentKey: "YES"
            ],
            arguments: []
        )

        let configuration = ScreenshotLaunchConfiguration(processInfo: processInfo)

        XCTAssertTrue(configuration.shouldSeedDemoData)
        XCTAssertFalse(configuration.shouldRunAutoTopUp)
    }

    func testWatchDocumentContainsExpectedVideoAndCuePayloads() throws {
        let configuration = ScreenshotLaunchConfiguration(
            processInfo: ProcessInfoStub(environment: [:], arguments: [])
        )

        let document = configuration.watchDocument

        XCTAssertEqual(document.languageCode, .german)
        XCTAssertEqual(document.sourceType, .youtube)
        XCTAssertEqual(document.sourceVideoID, "dQw4w9WgXcQ")
        XCTAssertEqual(document.sourceDurationSeconds, 45)
        XCTAssertTrue(document.body.contains("Heute sprechen wir ueber kleine Alltagsroutinen."))

        let sourceCues = document.subtitleCues
        let translatedCues = document.translatedSubtitleCues
        XCTAssertEqual(sourceCues.count, 3)
        XCTAssertEqual(translatedCues.count, 3)
        XCTAssertEqual(sourceCues.first?.startTime, 0, accuracy: 0.001)
        XCTAssertEqual(translatedCues.last?.translatedText, "That is how my morning starts, calm and clear.")
    }
}

private final class ProcessInfoStub: ProcessInfo, @unchecked Sendable {
    private let stubEnvironment: [String: String]
    private let stubArguments: [String]

    init(environment: [String: String], arguments: [String]) {
        stubEnvironment = environment
        stubArguments = arguments
        super.init()
    }

    override var environment: [String: String] {
        stubEnvironment
    }

    override var arguments: [String] {
        stubArguments
    }
}
