import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var hasRunLaunchTopUp = false

    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }

            VocabView()
                .tabItem {
                    Label("Vocab", systemImage: "list.bullet")
                }

            FlashcardsView()
                .tabItem {
                    Label("Flashcards", systemImage: "rectangle.stack")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(Theme.accent)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .task {
            guard !hasRunLaunchTopUp else { return }
            hasRunLaunchTopUp = true
            _ = await AutoImportCoordinator.shared.performAutoTopUpIfNeeded(
                modelContext: modelContext,
                trigger: .appLaunch
            )
        }
    }
}

#Preview {
    ContentView()
}
