import Foundation

struct StudyLanguageSettingsStore {
    static let studyLanguageKey = "study_language.code.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var studyLanguage: SupportedLanguage {
        get {
            if let explicit = SupportedLanguage.resolve(defaults.string(forKey: Self.studyLanguageKey)) {
                return explicit
            }

            return SupportedLanguage.freshInstallDefault
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Self.studyLanguageKey)
        }
    }

    var studyLanguageCode: String {
        get { studyLanguage.rawValue }
        nonmutating set {
            studyLanguage = SupportedLanguage.resolve(newValue) ?? SupportedLanguage.freshInstallDefault
        }
    }

    func bootstrapIfNeeded(hasPersistedContent: Bool) {
        guard defaults.object(forKey: Self.studyLanguageKey) == nil else {
            return
        }

        if hasPersistedContent || hasLegacyTranslationSettings {
            defaults.set(SupportedLanguage.legacyDefault.rawValue, forKey: Self.studyLanguageKey)
        } else {
            defaults.set(SupportedLanguage.freshInstallDefault.rawValue, forKey: Self.studyLanguageKey)
        }
    }

    private var hasLegacyTranslationSettings: Bool {
        defaults.object(forKey: "translation.azure.sourceLanguage") != nil
    }
}
