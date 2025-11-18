import Foundation
import SwiftData

@Model
final class Feedback {
    var id: UUID
    var userId: String?
    var timestamp: Date
    var category: String // e.g. "Suggestion", "Issue", "Other"
    var message: String
    var analyzedCategory: String? // For auto-categorization
    var summary: String? // For auto-summarization

    init(id: UUID = UUID(), userId: String? = nil, timestamp: Date = Date(), category: String, message: String, analyzedCategory: String? = nil, summary: String? = nil) {
        self.id = id
        self.userId = userId
        self.timestamp = timestamp
        self.category = category
        self.message = message
        self.analyzedCategory = analyzedCategory
        self.summary = summary
    }
}
