import Foundation
import SwiftData

@Model
final class Document {
    @Attribute(.unique) var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date

    init(title: String, body: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
