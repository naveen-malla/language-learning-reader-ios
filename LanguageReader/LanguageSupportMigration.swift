import Foundation
import SwiftData

enum LanguageSupportMigration {
    static func applyIfNeeded(
        container: ModelContainer,
        defaults: UserDefaults = .standard
    ) {
        let context = ModelContext(container)
        let documents = (try? context.fetch(FetchDescriptor<Document>())) ?? []
        let vocabEntries = (try? context.fetch(FetchDescriptor<VocabEntry>())) ?? []
        let ignoredWordsStore = IgnoredWordsStore(defaults: defaults)
        let hasPersistedContent = !documents.isEmpty || !vocabEntries.isEmpty || ignoredWordsStore.hasLegacyEntries

        StudyLanguageSettingsStore(defaults: defaults).bootstrapIfNeeded(hasPersistedContent: hasPersistedContent)
        ignoredWordsStore.migrateLegacyEntriesIfNeeded(to: .legacyDefault)
        AutoImportSettings.migrateLegacyStateIfNeeded(defaults: defaults)

        var hasChanges = false

        for document in documents {
            if SupportedLanguage.resolve(document.languageCodeRaw) == nil {
                document.languageCode = .legacyDefault
                hasChanges = true
            }
        }

        for entry in vocabEntries {
            let resolvedLanguage = SupportedLanguage.resolve(entry.languageCodeRaw) ?? .legacyDefault
            if entry.languageCodeRaw != resolvedLanguage.rawValue {
                entry.languageCode = resolvedLanguage
                hasChanges = true
            }

            let expectedScopedKey = VocabEntry.makeScopedKey(
                languageCode: resolvedLanguage.rawValue,
                normalizedKey: entry.normalizedKey
            )
            if entry.scopedKey != expectedScopedKey {
                entry.scopedKey = expectedScopedKey
                hasChanges = true
            }
        }

        guard hasChanges else { return }
        try? context.save()
    }
}
