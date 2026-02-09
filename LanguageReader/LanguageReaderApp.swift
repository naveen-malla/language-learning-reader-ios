import SwiftUI
import UIKit
import SwiftData

@main
struct LanguageReaderApp: App {
    private static let seedVersion = "sample_documents_seed_v1"
    private let sharedModelContainer: ModelContainer

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        do {
            sharedModelContainer = try ModelContainer(for: Document.self, VocabEntry.self)
            seedInitialDocumentsIfNeeded(container: sharedModelContainer)
        } catch {
            fatalError("Failed to initialize model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }

    private func seedInitialDocumentsIfNeeded(container: ModelContainer) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Self.seedVersion) == false else { return }

        let context = ModelContext(container)
        let fetch = FetchDescriptor<Document>()
        if let existing = try? context.fetch(fetch), existing.isEmpty == false {
            defaults.set(true, forKey: Self.seedVersion)
            return
        }

        let now = Date()
        for seed in SampleDocuments.initial {
            let document = Document(title: seed.title, body: seed.body, createdAt: now, updatedAt: now)
            context.insert(document)
        }

        do {
            try context.save()
            defaults.set(true, forKey: Self.seedVersion)
        } catch {
            print("Failed to seed documents: \(error)")
        }
    }
}
