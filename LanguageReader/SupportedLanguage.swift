import Foundation

enum SupportedLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case german = "de"
    case kannada = "kn"

    static let legacyDefault: SupportedLanguage = .kannada
    static let freshInstallDefault: SupportedLanguage = .german

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .german:
            return "German"
        case .kannada:
            return "Kannada"
        }
    }

    var shortLabel: String {
        switch self {
        case .german:
            return "DE"
        case .kannada:
            return "KN"
        }
    }

    var englishTargetLanguageCode: String { "en" }

    static func resolve(_ value: String?) -> SupportedLanguage? {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let normalized, !normalized.isEmpty else {
            return nil
        }

        return SupportedLanguage(rawValue: normalized)
    }

    static func legacyResolved(_ value: String?) -> SupportedLanguage {
        resolve(value) ?? legacyDefault
    }
}
