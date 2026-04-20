import XCTest
@testable import LanguageReader

final class ScreenshotLaunchConfigurationTests: XCTestCase {
    func testParseRouteMapsSupportedTabs() {
        XCTAssertEqual(ScreenshotLaunchConfiguration.parseRoute("library"), .tab(.library))
        XCTAssertEqual(ScreenshotLaunchConfiguration.parseRoute("vocab"), .tab(.vocab))
        XCTAssertEqual(ScreenshotLaunchConfiguration.parseRoute("flashcards"), .tab(.flashcards))
        XCTAssertEqual(ScreenshotLaunchConfiguration.parseRoute("settings"), .tab(.settings))
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
                "\(ScreenshotLaunchConfiguration.routeArgumentPrefix)flashcards"
            ]
        )

        let configuration = ScreenshotLaunchConfiguration(processInfo: processInfo)

        XCTAssertEqual(configuration.route, .tab(.flashcards))
        XCTAssertTrue(configuration.shouldSeedDemoData)
        XCTAssertFalse(configuration.shouldRunAutoTopUp)
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
