import XCTest
import SwiftUI
@testable import LanguageReader

final class AppAppearanceModeTests: XCTestCase {
    func testDefaultModeIsDark() {
        XCTAssertEqual(AppAppearanceMode.defaultValue, .dark)
    }

    func testPreferredColorSchemeMapping() {
        XCTAssertNil(AppAppearanceMode.system.preferredColorScheme)
        XCTAssertEqual(AppAppearanceMode.light.preferredColorScheme, .light)
        XCTAssertEqual(AppAppearanceMode.dark.preferredColorScheme, .dark)
        XCTAssertEqual(AppAppearanceMode.midnight.preferredColorScheme, .dark)
    }

    func testMidnightFlagOnlyEnabledForMidnight() {
        XCTAssertFalse(AppAppearanceMode.system.usesMidnightPalette)
        XCTAssertFalse(AppAppearanceMode.light.usesMidnightPalette)
        XCTAssertFalse(AppAppearanceMode.dark.usesMidnightPalette)
        XCTAssertTrue(AppAppearanceMode.midnight.usesMidnightPalette)
    }
}
