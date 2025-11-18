//
//  DailyInsight.swift
//  Lumen
//
//  Data model for daily AI-generated skincare insights
//

import Foundation

struct DailyInsight: Codable, Identifiable, Sendable {
    let id: String
    let userId: String
    let generatedAt: Date
    let dailyTip: String
    let checkInQuestion: String?
    let progressPrediction: String?
    let environmentalRecommendation: String?
    let expiresAt: Date?
    let recommendedProducts: [RecommendedProduct]?
    
    struct RecommendedProduct: Codable, Identifiable, Sendable {
        let id: String
        let name: String
        let brand: String
        let description: String?
        let priceRange: String?
        let amazonUrl: String?
        var isCompleted: Bool?
        
        enum CodingKeys: String, CodingKey {
            case id = "product_id"
            case name
            case brand
            case description
            case priceRange = "price_range"
            case amazonUrl = "amazon_url"
            case isCompleted = "is_completed"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "insight_id"
        case userId = "user_id"
        case generatedAt = "generated_at"
        case dailyTip = "daily_tip"
        case checkInQuestion = "check_in_question"
        case progressPrediction = "progress_prediction"
        case environmentalRecommendation = "environmental_recommendation"
        case expiresAt = "expires_at"
        case recommendedProducts = "recommended_products"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        
        // Parse ISO 8601 date strings - handle multiple formats
        let generatedAtString = try container.decode(String.self, forKey: .generatedAt)
        let formatter = ISO8601DateFormatter()
        
        // Try with fractional seconds first
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: generatedAtString) {
            generatedAt = date
        } else {
            // Fallback to without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            generatedAt = formatter.date(from: generatedAtString) ?? Date()
        }
        
        dailyTip = try container.decode(String.self, forKey: .dailyTip)
        checkInQuestion = try container.decodeIfPresent(String.self, forKey: .checkInQuestion)
        progressPrediction = try container.decodeIfPresent(String.self, forKey: .progressPrediction)
        environmentalRecommendation = try container.decodeIfPresent(String.self, forKey: .environmentalRecommendation)
        recommendedProducts = try container.decodeIfPresent([RecommendedProduct].self, forKey: .recommendedProducts)
        
        if let expiresAtString = try container.decodeIfPresent(String.self, forKey: .expiresAt) {
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: expiresAtString) {
                expiresAt = date
            } else {
                formatter.formatOptions = [.withInternetDateTime]
                expiresAt = formatter.date(from: expiresAtString)
            }
        } else {
            expiresAt = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(formatter.string(from: generatedAt), forKey: .generatedAt)
        
        try container.encode(dailyTip, forKey: .dailyTip)
        try container.encodeIfPresent(checkInQuestion, forKey: .checkInQuestion)
        try container.encodeIfPresent(progressPrediction, forKey: .progressPrediction)
        try container.encodeIfPresent(environmentalRecommendation, forKey: .environmentalRecommendation)
        try container.encodeIfPresent(recommendedProducts, forKey: .recommendedProducts)
        
        if let expiresAt = expiresAt {
            try container.encode(formatter.string(from: expiresAt), forKey: .expiresAt)
        }
    }
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(generatedAt)
    }
}

// Check-in response model
struct CheckInResponse: Codable, Sendable {
    let question: String
    let response: String
    let responseType: String
    
    enum CodingKeys: String, CodingKey {
        case question
        case response
        case responseType = "response_type"
    }
}

// API request/response models
struct GenerateDailyInsightRequest: Codable, Sendable {
    let location: Location
    
    struct Location: Codable, Sendable {
        let latitude: Double
        let longitude: Double
    }
}

struct DailyInsightResponse: Codable, Sendable {
    let success: Bool
    let data: DailyInsight?
    let error: String?
}

struct SubmitCheckInRequest: Codable, Sendable {
    let response: CheckInResponse
}

struct SubmitCheckInResponse: Codable, Sendable {
    let success: Bool
    let data: CheckInData?
    let error: String?
    
    struct CheckInData: Codable, Sendable {
        let responseId: String
        let status: String
        
        enum CodingKeys: String, CodingKey {
            case responseId = "response_id"
            case status
        }
    }
}

