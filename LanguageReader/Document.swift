import Foundation
import SwiftData

/// Represents a reading document with title and body text.
@Model
final class Document {
    /// Unique identifier for this document.
    @Attribute(.unique) var id: UUID
    
    /// The document's title.
    var title: String
    
    /// The document's text content.
    var body: String
    
    /// When this document was created.
    var createdAt: Date
    
    /// When this document was last modified.
    var updatedAt: Date

    /// Creates a new document.
    /// - Parameters:
    ///   - title: The document title.
    ///   - body: The document text content.
    ///   - createdAt: Creation timestamp (defaults to now).
    ///   - updatedAt: Last update timestamp (defaults to now).
    init(title: String, body: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
