import SwiftUI
import UIKit
import SwiftData

@main
struct LanguageReaderApp: App {
    private static let seedVersion = "sample_documents_seed_v1"
    @AppStorage(AppAppearanceMode.storageKey) private var appearanceModeRawValue = AppAppearanceMode.defaultValue.rawValue
    private let sharedModelContainer: ModelContainer

    init() {
        Self.configureTabBarAppearance()

        do {
            sharedModelContainer = try ModelContainer(for: Document.self, VocabEntry.self)
            seedInitialDocumentsIfNeeded(container: sharedModelContainer)
        } catch {
            fatalError("Failed to initialize model container: \(error)")
        }
    }

    private static func configureTabBarAppearance() {
        let selectedColor = UIColor(red: 0.13, green: 0.45, blue: 0.9, alpha: 1)
        let normalColor = UIColor.label.withAlphaComponent(0.86)

        let itemAppearance = UITabBarItemAppearance(style: .stacked)
        itemAppearance.normal.iconColor = normalColor
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalColor,
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]
        itemAppearance.selected.iconColor = selectedColor
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]

        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.45)
        appearance.shadowColor = UIColor.clear
        appearance.selectionIndicatorTintColor = selectedColor.withAlphaComponent(0.16)
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appAppearanceMode, selectedAppearanceMode)
                .preferredColorScheme(selectedAppearanceMode.preferredColorScheme)
        }
        .modelContainer(sharedModelContainer)
    }

    private var selectedAppearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRawValue) ?? .defaultValue
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
