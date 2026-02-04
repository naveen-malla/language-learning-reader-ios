import SwiftUI

/// Root content view containing the main tab navigation.
struct ContentView: View {
    var body: some View {
        TabView {
            ReaderView()
                .tabItem {
                    Label("Reader", systemImage: "doc.text")
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Document.self, VocabEntry.self], inMemory: true)
}
