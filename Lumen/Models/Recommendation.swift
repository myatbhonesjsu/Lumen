//
//  Recommendation.swift
//  Lumen
//
//  AI Skincare Assistant - Product Recommendations
//

import Foundation
import SwiftData

@Model
final class Recommendation {
    var id: UUID
    var title: String
    var category: String // "moisturizer", "sunscreen", "acne_treatment", etc.
    var productDescription: String
    var reason: String
    var priority: Int // 1-5, 1 being highest
    var timestamp: Date

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        productDescription: String,
        reason: String,
        priority: Int = 3,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.productDescription = productDescription
        self.reason = reason
        self.priority = priority
        self.timestamp = timestamp
    }
}
