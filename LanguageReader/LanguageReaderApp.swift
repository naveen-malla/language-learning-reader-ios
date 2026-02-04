import SwiftUI
import UIKit

/// Main application entry point for LanguageReader.
/// Configures SwiftData model container and tab bar appearance.
@main
struct LanguageReaderApp: App {
    init() {
        // Configure tab bar appearance for consistent styling
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Document.self, VocabEntry.self])
    }
}
