import Foundation
import SwiftData

enum DocumentSourceType: String {
    case text
    case youtube
    case sample
}

@Model
final class Document {
    @Attribute(.unique) var id: UUID
    var title: String
    var body: String
    var languageCodeRaw: String?
    var createdAt: Date
    var updatedAt: Date
    var sourceTypeRaw: String?
    var sourceURL: String?
    var sourceVideoID: String?
    var sourceChannel: String?
    var sourceChannelID: String?
    var sourceCategory: String?
    var sourceDurationSeconds: Int?
    var thumbnailURL: String?
    var subtitleCuesRaw: String?
    var translatedSubtitleCuesRaw: String?
    var importModeRaw: String?
    var autoBatchID: String?
    var firstOpenedAt: Date?
    var lastOpenedAt: Date?

    init(
        title: String,
        body: String,
        languageCode: SupportedLanguage = StudyLanguageSettingsStore().studyLanguage,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sourceType: DocumentSourceType = .text,
        sourceURL: String? = nil,
        sourceVideoID: String? = nil,
        sourceChannel: String? = nil,
        sourceChannelID: String? = nil,
        sourceCategory: String? = nil,
        sourceDurationSeconds: Int? = nil,
        thumbnailURL: String? = nil,
        subtitleCuesRaw: String? = nil,
        translatedSubtitleCuesRaw: String? = nil,
        importMode: DocumentImportMode? = nil,
        autoBatchID: String? = nil,
        firstOpenedAt: Date? = nil,
        lastOpenedAt: Date? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.languageCodeRaw = languageCode.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceTypeRaw = sourceType.rawValue
        self.sourceURL = sourceURL
        self.sourceVideoID = sourceVideoID
        self.sourceChannel = sourceChannel
        self.sourceChannelID = sourceChannelID
        self.sourceCategory = sourceCategory
        self.sourceDurationSeconds = sourceDurationSeconds
        self.thumbnailURL = thumbnailURL
        self.subtitleCuesRaw = subtitleCuesRaw
        self.translatedSubtitleCuesRaw = translatedSubtitleCuesRaw
        self.importModeRaw = importMode?.rawValue
        self.autoBatchID = autoBatchID
        self.firstOpenedAt = firstOpenedAt
        self.lastOpenedAt = lastOpenedAt
    }
}

extension Document {
    var languageCode: SupportedLanguage {
        get {
            SupportedLanguage.legacyResolved(languageCodeRaw)
        }
        set {
            languageCodeRaw = newValue.rawValue
        }
    }

    var sourceType: DocumentSourceType {
        get {
            guard let sourceTypeRaw, let sourceType = DocumentSourceType(rawValue: sourceTypeRaw) else {
                return .text
            }
            return sourceType
        }
        set {
            sourceTypeRaw = newValue.rawValue
        }
    }

    var isOpened: Bool {
        firstOpenedAt != nil
    }

    var importMode: DocumentImportMode? {
        get {
            guard let importModeRaw else { return nil }
            return DocumentImportMode(rawValue: importModeRaw)
        }
        set {
            importModeRaw = newValue?.rawValue
        }
    }

    var subtitleCues: [TimedSubtitleCue] {
        get {
            SubtitleCueCoder.decode([TimedSubtitleCue].self, from: subtitleCuesRaw) ?? []
        }
        set {
            subtitleCuesRaw = newValue.isEmpty ? nil : SubtitleCueCoder.encode(newValue)
        }
    }

    var translatedSubtitleCues: [TranslatedSubtitleCue]? {
        get {
            SubtitleCueCoder.decode([TranslatedSubtitleCue].self, from: translatedSubtitleCuesRaw)
        }
        set {
            translatedSubtitleCuesRaw = newValue.flatMap { cues in
                cues.isEmpty ? nil : SubtitleCueCoder.encode(cues)
            }
        }
    }
}
