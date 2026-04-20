import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var hasRunLaunchTopUp = false
    @State private var selectedTab = ScreenshotLaunchConfiguration().initialTab
    private let screenshotLaunchConfiguration = ScreenshotLaunchConfiguration()

    var body: some View {
        Group {
            switch screenshotLaunchConfiguration.route {
            case .reader:
                NavigationStack {
                    DocumentReaderView(document: screenshotLaunchConfiguration.readerDocument)
                }
            case .tab, .none:
                tabShell
            }
        }
        .tint(Theme.accent)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .task {
            guard !hasRunLaunchTopUp else { return }
            guard screenshotLaunchConfiguration.shouldRunAutoTopUp else { return }
            hasRunLaunchTopUp = true
            _ = await AutoImportCoordinator.shared.performAutoTopUpIfNeeded(
                modelContext: modelContext,
                trigger: .appLaunch
            )
        }
    }

    private var tabShell: some View {
        TabView(selection: $selectedTab) {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .tag(AppLaunchTab.library)

            VocabView()
                .tabItem {
                    Label("Vocab", systemImage: "list.bullet")
                }
                .tag(AppLaunchTab.vocab)

            FlashcardsView()
                .tabItem {
                    Label("Flashcards", systemImage: "rectangle.stack")
                }
                .tag(AppLaunchTab.flashcards)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppLaunchTab.settings)
        }
        .onAppear {
            guard case .tab(let tab) = screenshotLaunchConfiguration.route else { return }
            selectedTab = tab
        }
    }
}

#Preview {
    ContentView()
}
