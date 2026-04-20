import Foundation
import SwiftData

enum AppLaunchTab: String, CaseIterable, Hashable {
    case library
    case vocab
    case flashcards
    case settings
}

struct ScreenshotLaunchConfiguration {
    enum Route: Equatable {
        case tab(AppLaunchTab)
        case flashcardsSession
        case reader
        case watch
    }

    static let routeArgumentPrefix = "--screenshot-route="
    static let seedDemoDataArgument = "--screenshot-demo"
    static let routeEnvironmentKey = "LANGUAGEREADER_SCREENSHOT_ROUTE"
    static let seedDemoDataEnvironmentKey = "LANGUAGEREADER_SCREENSHOT_DEMO"
    private static let seedMarkerKey = "screenshot_demo_seed_v1"
    private static let flashcardMigrationKey = "flashcards_simple_mode_migrated_v1"

    let route: Route?
    let shouldSeedDemoData: Bool

    init(processInfo: ProcessInfo = .processInfo) {
        route = Self.parseRoute(
            Self.argumentValue(
                matching: Self.routeArgumentPrefix,
                in: processInfo.arguments
            ) ?? processInfo.environment[Self.routeEnvironmentKey]
        )
        shouldSeedDemoData = processInfo.arguments.contains(Self.seedDemoDataArgument) ||
            Self.parseBoolean(processInfo.environment[Self.seedDemoDataEnvironmentKey])
    }

    var initialTab: AppLaunchTab {
        if case .tab(let tab) = route {
            return tab
        }
        if route == .flashcardsSession {
            return .flashcards
        }
        return .library
    }

    var shouldRunAutoTopUp: Bool {
        route == nil && !shouldSeedDemoData
    }

    var readerDocument: Document {
        let seed = SampleDocuments.german.first ?? SampleSeedDocument(
            title: "German Reading Sample",
            body: "Heute lese ich einen kurzen deutschen Text und überprüfe nur die wichtigsten Wörter.",
            language: .german
        )

        return Document(
            title: seed.title,
            body: seed.body,
            languageCode: seed.language,
            sourceType: .sample
        )
    }

    var watchDocument: Document {
        let cues = [
            TimedSubtitleCue(startTime: 0, duration: 3.5, sourceText: "Heute sprechen wir ueber kleine Alltagsroutinen."),
            TimedSubtitleCue(startTime: 3.5, duration: 3.8, sourceText: "Ich mache Kaffee und oeffne danach das Fenster."),
            TimedSubtitleCue(startTime: 7.3, duration: 4.0, sourceText: "So beginnt mein Morgen ganz ruhig und klar.")
        ]
        let translated = [
            TranslatedSubtitleCue(startTime: 0, duration: 3.5, translatedText: "Today we are talking about small daily routines."),
            TranslatedSubtitleCue(startTime: 3.5, duration: 3.8, translatedText: "I make coffee and then open the window."),
            TranslatedSubtitleCue(startTime: 7.3, duration: 4.0, translatedText: "That is how my morning starts, calm and clear.")
        ]

        let body = cues.map(\.sourceText).joined(separator: "\n")

        return Document(
            title: "German Watch Sample",
            body: body,
            languageCode: .german,
            sourceType: .youtube,
            sourceURL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            sourceVideoID: "dQw4w9WgXcQ",
            sourceDurationSeconds: 45,
            subtitleCuesRaw: SubtitleCueCoder.encode(cues),
            translatedSubtitleCuesRaw: SubtitleCueCoder.encode(translated)
        )
    }

    static func seedDemoDataIfNeeded(
        container: ModelContainer,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) {
        let processInfo = ProcessInfo.processInfo
        let shouldSeedDemoData = processInfo.arguments.contains(seedDemoDataArgument) ||
            parseBoolean(processInfo.environment[seedDemoDataEnvironmentKey])
        guard shouldSeedDemoData else { return }

        let context = ModelContext(container)
        let studyLanguageStore = StudyLanguageSettingsStore(defaults: defaults)
        studyLanguageStore.studyLanguage = .german
        defaults.set(true, forKey: flashcardMigrationKey)

        let descriptor = FetchDescriptor<VocabEntry>(predicate: #Predicate { entry in
            entry.languageCodeRaw == "de"
        })

        let existingGermanEntries = (try? context.fetch(descriptor)) ?? []
        let existingEntriesByKey = Dictionary(uniqueKeysWithValues: existingGermanEntries.map { ($0.normalizedKey, $0) })

        let demoEntries = [
            VocabEntry(
                word: "Straße",
                normalizedKey: "straße",
                languageCode: .german,
                meaning: "street",
                status: .level1,
                createdAt: now,
                lastSeenAt: now.addingTimeInterval(-3_600),
                encounterCount: 2,
                dueAt: now.addingTimeInterval(-900)
            ),
            VocabEntry(
                word: "Woche",
                normalizedKey: "woche",
                languageCode: .german,
                meaning: "week",
                status: .level2,
                createdAt: now.addingTimeInterval(-86_400 * 2),
                lastSeenAt: now.addingTimeInterval(-86_400),
                encounterCount: 4,
                dueAt: now.addingTimeInterval(-1_800)
            ),
            VocabEntry(
                word: "Fortschritt",
                normalizedKey: "fortschritt",
                languageCode: .german,
                meaning: "progress",
                status: .level3,
                createdAt: now.addingTimeInterval(-86_400 * 5),
                lastSeenAt: now.addingTimeInterval(-86_400 * 2),
                encounterCount: 6,
                dueAt: now.addingTimeInterval(86_400)
            )
        ]

        for entry in demoEntries {
            if let existing = existingEntriesByKey[entry.normalizedKey] {
                existing.word = entry.word
                existing.meaning = entry.meaning
                existing.status = entry.status
                existing.createdAt = entry.createdAt
                existing.lastSeenAt = entry.lastSeenAt
                existing.encounterCount = entry.encounterCount
                existing.dueAt = entry.dueAt
                existing.isSuspended = false
                existing.srsIntervalDays = entry.srsIntervalDays
                existing.srsAlgorithm = "simple_level"
            } else {
                entry.srsAlgorithm = "simple_level"
                context.insert(entry)
            }
        }

        do {
            try context.save()
            defaults.set(true, forKey: seedMarkerKey)
        } catch {
            print("Failed to seed screenshot demo data: \(error)")
        }
    }

    static func parseRoute(_ rawValue: String?) -> Route? {
        guard let normalized = rawValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !normalized.isEmpty else {
            return nil
        }

        switch normalized {
        case AppLaunchTab.library.rawValue:
            return .tab(.library)
        case AppLaunchTab.vocab.rawValue:
            return .tab(.vocab)
        case AppLaunchTab.flashcards.rawValue:
            return .tab(.flashcards)
        case "flashcards-session":
            return .flashcardsSession
        case AppLaunchTab.settings.rawValue:
            return .tab(.settings)
        case "reader":
            return .reader
        case "watch":
            return .watch
        default:
            return nil
        }
    }

    private static func parseBoolean(_ rawValue: String?) -> Bool {
        guard let normalized = rawValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !normalized.isEmpty else {
            return false
        }

        switch normalized {
        case "1", "true", "yes", "y", "on":
            return true
        default:
            return false
        }
    }

    private static func argumentValue(matching prefix: String, in arguments: [String]) -> String? {
        arguments.first(where: { $0.hasPrefix(prefix) })
            .map { String($0.dropFirst(prefix.count)) }
    }
}
