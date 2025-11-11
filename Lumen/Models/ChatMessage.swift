//
//  ChatMessage.swift
//  Lumen
//
//  Persistent chat message storage
//

import Foundation
import SwiftData

@Model
final class PersistedChatMessage {
    var id: UUID
    var role: String // "user" or "assistant"
    var message: String
    var timestamp: Date
    var sessionId: String
    var sourcesJSON: String? // JSON-encoded sources

    init(
        id: UUID = UUID(),
        role: String,
        message: String,
        timestamp: Date = Date(),
        sessionId: String,
        sources: [ChatSource]? = nil
    ) {
        self.id = id
        self.role = role
        self.message = message
        self.timestamp = timestamp
        self.sessionId = sessionId

        // Encode sources to JSON
        if let sources = sources, !sources.isEmpty {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(sources),
               let json = String(data: data, encoding: .utf8) {
                self.sourcesJSON = json
            }
        }
    }

    // Computed property to decode sources
    var sources: [ChatSource]? {
        guard let json = sourcesJSON,
              let data = json.data(using: .utf8) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode([ChatSource].self, from: data)
    }
}

// MARK: - Chat Source

struct ChatSource: Codable, Identifiable {
    let id: String
    let source: String
    let url: String?

    init(id: String = UUID().uuidString, source: String, url: String? = nil) {
        self.id = id
        self.source = source
        self.url = url
    }
}
