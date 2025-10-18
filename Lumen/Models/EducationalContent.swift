//
//  EducationalContent.swift
//  Lumen
//
//  AI Skincare Assistant - Educational Resources
//

import Foundation

struct EducationalContent: Identifiable {
    let id: UUID
    let title: String
    let category: String
    let content: String
    let imageIcon: String // SF Symbol name
    let readTime: Int // minutes

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        content: String,
        imageIcon: String = "book.fill",
        readTime: Int = 5
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.content = content
        self.imageIcon = imageIcon
        self.readTime = readTime
    }
}
