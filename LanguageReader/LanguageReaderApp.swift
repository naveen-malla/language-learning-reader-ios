import SwiftUI

@main
struct LanguageReaderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Document.self, VocabEntry.self])
    }
}
