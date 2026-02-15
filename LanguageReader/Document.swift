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
    var createdAt: Date
    var updatedAt: Date
    var sourceTypeRaw: String?
    var sourceURL: String?
    var sourceVideoID: String?
    var sourceChannel: String?
    var sourceCategory: String?
    var sourceDurationSeconds: Int?
    var thumbnailURL: String?
    var firstOpenedAt: Date?
    var lastOpenedAt: Date?

    init(
        title: String,
        body: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sourceType: DocumentSourceType = .text,
        sourceURL: String? = nil,
        sourceVideoID: String? = nil,
        sourceChannel: String? = nil,
        sourceCategory: String? = nil,
        sourceDurationSeconds: Int? = nil,
        thumbnailURL: String? = nil,
        firstOpenedAt: Date? = nil,
        lastOpenedAt: Date? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceTypeRaw = sourceType.rawValue
        self.sourceURL = sourceURL
        self.sourceVideoID = sourceVideoID
        self.sourceChannel = sourceChannel
        self.sourceCategory = sourceCategory
        self.sourceDurationSeconds = sourceDurationSeconds
        self.thumbnailURL = thumbnailURL
        self.firstOpenedAt = firstOpenedAt
        self.lastOpenedAt = lastOpenedAt
    }
}

extension Document {
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
}
