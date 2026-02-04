import SwiftUI

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
}
