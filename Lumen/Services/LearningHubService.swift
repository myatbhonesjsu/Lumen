//
//  LearningHubService.swift
//  Lumen
//
//  AI-powered Learning Hub with chatbot, RAG, and personalized recommendations
//

import Foundation

// MARK: - Models

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: String
    let role: String // "user" or "assistant"
    let message: String
    let timestamp: Date
    let sources: [Source]?
    
    init(id: String = UUID().uuidString, role: String, message: String, timestamp: Date = Date(), sources: [Source]? = nil) {
        self.id = id
        self.role = role
        self.message = message
        self.timestamp = timestamp
        self.sources = sources
    }
    
    struct Source: Codable, Equatable {
        let text: String
        let source: String
    }
}

struct ArticleRecommendation: Identifiable, Codable {
    let id: String
    let title: String
    let category: String
    let summary: String
    let url: String
    let source: String
    let keywords: [String]
    let relevanceScore: Double
    let matchScore: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, title, category, summary, url, source, keywords
        case relevanceScore = "relevance_score"
        case matchScore = "match_score"
    }
}

struct PersonalizedRecommendations: Codable {
    let recommendations: [ArticleRecommendation]
    let basedOnConditions: [String]
    let totalAnalyses: Int
    
    enum CodingKeys: String, CodingKey {
        case recommendations
        case basedOnConditions = "based_on_conditions"
        case totalAnalyses = "total_analyses"
    }
}

struct AutocompleteResponse: Codable {
    let suggestions: [String]
}

// MARK: - Service

class LearningHubService {
    static let shared = LearningHubService()
    
    private let baseURL = "https://ocbpgt6ebc.execute-api.us-east-1.amazonaws.com/dev"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Chat Functions
    
    /// Send a chat message and get AI response
    func sendMessage(
        message: String,
        userId: String = "anonymous",
        sessionId: String? = nil,
        localAnalyses: [[String: Any]] = []
    ) async throws -> ChatResponse {
        let url = URL(string: "\(baseURL)/learning-hub/chat")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "user_id": userId,
            "message": message,
            "session_id": sessionId ?? UUID().uuidString
        ]

        // Only add local analyses if not empty
        if !localAnalyses.isEmpty {
            body["local_analyses"] = localAnalyses
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LearningHubError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw LearningHubError.serverError(httpResponse.statusCode)
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        return chatResponse
    }
    
    /// Get chat history for a session
    func getChatHistory(userId: String = "anonymous", sessionId: String) async throws -> [ChatMessage] {
        let url = URL(string: "\(baseURL)/learning-hub/chat-history?user_id=\(userId)&session_id=\(sessionId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LearningHubError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LearningHubError.serverError(httpResponse.statusCode)
        }
        
        let historyResponse = try JSONDecoder().decode(ChatHistoryResponse.self, from: data)
        
        // Convert to ChatMessage objects
        return historyResponse.history.map { item in
            ChatMessage(
                id: "\(item.timestamp)",
                role: item.role,
                message: item.message,
                timestamp: Date(timeIntervalSince1970: TimeInterval(item.timestamp))
            )
        }
    }
    
    // MARK: - Recommendations
    
    /// Get personalized article recommendations based on user's analysis history
    func getPersonalizedRecommendations(userId: String = "anonymous") async throws -> PersonalizedRecommendations {
        let url = URL(string: "\(baseURL)/learning-hub/recommendations?user_id=\(userId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LearningHubError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LearningHubError.serverError(httpResponse.statusCode)
        }
        
        let recommendations = try JSONDecoder().decode(PersonalizedRecommendations.self, from: data)
        return recommendations
    }
    
    /// Get educational articles with optional filtering
    func getArticles(category: String? = nil, searchQuery: String? = nil) async throws -> [ArticleRecommendation] {
        var urlString = "\(baseURL)/learning-hub/articles"
        var queryParams: [String] = []
        
        if let category = category {
            queryParams.append("category=\(category)")
        }
        if let query = searchQuery {
            queryParams.append("query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        }
        
        if !queryParams.isEmpty {
            urlString += "?" + queryParams.joined(separator: "&")
        }
        
        let url = URL(string: urlString)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LearningHubError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LearningHubError.serverError(httpResponse.statusCode)
        }
        
        let articlesResponse = try JSONDecoder().decode(ArticlesResponse.self, from: data)
        return articlesResponse.articles
    }

    func fetchAutocompleteSuggestions(
        prefix: String,
        userId: String = "anonymous"
    ) async throws -> [String] {
        guard let encodedPrefix = prefix.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }

        let url = URL(string: "\(baseURL)/learning-hub/suggestions?user_id=\(userId)&q=\(encodedPrefix)")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LearningHubError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw LearningHubError.serverError(httpResponse.statusCode)
        }

        let suggestionsResponse = try JSONDecoder().decode(AutocompleteResponse.self, from: data)
        return suggestionsResponse.suggestions
    }
}

// MARK: - Response Models

struct ChatResponse: Codable {
    let sessionId: String
    let response: String
    let sources: [ChatMessage.Source]?
    let relatedArticles: [ArticleRecommendation]
    let timestamp: Int
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case response
        case sources
        case relatedArticles = "related_articles"
        case timestamp
    }
}

struct ChatHistoryResponse: Codable {
    let history: [ChatHistoryItem]
    let sessionId: String
    
    enum CodingKeys: String, CodingKey {
        case history
        case sessionId = "session_id"
    }
    
    struct ChatHistoryItem: Codable {
        let userId: String
        let sessionId: String
        let timestamp: Int
        let role: String
        let message: String
        
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case sessionId = "session_id"
            case timestamp
            case role
            case message
        }
    }
}

struct ArticlesResponse: Codable {
    let articles: [ArticleRecommendation]
    let count: Int
}

// MARK: - Errors

enum LearningHubError: LocalizedError {
    case invalidResponse
    case serverError(Int)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

