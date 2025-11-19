//
//  SkinAnalysisService.swift
//  Lumen
//
//  Simplified AWS backend service wrapper
//  AWS Lambda handles: HuggingFace → Product recommendations
//

import Foundation
import UIKit

/// Complete analysis result from AWS
struct AnalysisResult: Equatable {
    let condition: String
    let confidence: Double
    let allConditions: [String: Double]
    let products: [Product]
    let timestamp: Date
    let summary: String?

    // Dual Independent Analysis (HuggingFace + Claude)
    let isClaudeValidated: Bool      // True if dual analysis was performed
    let claudeConfidence: Double?    // Claude's independent confidence
    let agreesWithPrimary: Bool?     // True if both models agree
    let validationSeverity: String?  // Severity from Claude analysis
    let validationInsights: String?  // Claude's clinical insights
    let confidenceBoost: Double?     // Confidence boost from consensus

    struct Product: Equatable {
        let name: String
        let brand: String
        let description: String
        let priceRange: String
        let amazonUrl: String
        let rating: Double
    }
    
    // MARK: - Helper Methods
    
    /// Get secondary conditions above threshold
    func getSecondaryConditions(threshold: Double = 0.15, limit: Int = 3) -> [(name: String, confidence: Double)] {
        return allConditions
            .filter { $0.key.lowercased() != condition.lowercased() && $0.value >= threshold }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (name: $0.key, confidence: $0.value) }
    }
    
    /// Get recommended solutions for a condition
    func getSolutions(for condition: String) -> [String] {
        let conditionLower = condition.lowercased().replacingOccurrences(of: " ", with: "_")
        
        let solutionMap: [String: [String]] = [
            "acne": [
                "Use a gentle cleanser with salicylic acid or benzoyl peroxide",
                "Apply non-comedogenic moisturizer daily",
                "Consider retinoid treatments (consult dermatologist)",
                "Avoid touching your face frequently"
            ],
            "dark_circles": [
                "Get adequate sleep (7-9 hours)",
                "Use caffeine-based eye creams",
                "Apply cold compresses in the morning",
                "Stay hydrated throughout the day"
            ],
            "dark_spots": [
                "Use vitamin C serum daily",
                "Apply broad-spectrum SPF 30+ sunscreen",
                "Consider niacinamide or alpha arbutin products",
                "Exfoliate 1-2 times per week"
            ],
            "eye_bags": [
                "Elevate your head while sleeping",
                "Use retinol-based eye creams",
                "Apply cold cucumber slices or tea bags",
                "Reduce salt intake"
            ],
            "wrinkles": [
                "Use retinol or retinoid creams",
                "Apply peptide-rich serums",
                "Always wear sunscreen (SPF 30+)",
                "Stay hydrated and moisturize regularly"
            ],
            "oily_skin": [
                "Use oil-free, non-comedogenic products",
                "Wash face twice daily with gentle cleanser",
                "Apply mattifying moisturizer",
                "Use blotting papers throughout the day"
            ],
            "dry_skin": [
                "Use gentle, hydrating cleansers",
                "Apply hyaluronic acid serum",
                "Use rich moisturizer with ceramides",
                "Avoid hot water when washing face"
            ],
            "rosacea": [
                "Avoid triggers like spicy foods and alcohol",
                "Use gentle, fragrance-free products",
                "Apply sunscreen daily (mineral-based)",
                "Consider prescription treatments"
            ],
            "eczema": [
                "Keep skin moisturized with thick creams",
                "Avoid harsh soaps and hot water",
                "Use fragrance-free products",
                "Consider prescription treatments"
            ]
        ]
        
        // Try exact match first
        if let solutions = solutionMap[conditionLower] {
            return solutions
        }
        
        // Check for partial matches
        for (key, solutions) in solutionMap {
            if conditionLower.contains(key) || key.contains(conditionLower) {
                return solutions
            }
        }
        
        // Default recommendations
        return [
            "Maintain a consistent skincare routine",
            "Use gentle, fragrance-free products",
            "Always wear sunscreen (SPF 30+)",
            "Consult a dermatologist for personalized advice"
        ]
    }
}

class SkinAnalysisService {
    static let shared = SkinAnalysisService()

    private init() {}

    // MARK: - Public API

    /// Analyzes skin using AWS backend
    /// - Parameters:
    ///   - imageData: The skin image data to analyze
    ///   - onProgress: Progress updates during analysis
    ///   - completion: Called when analysis completes with result
    func analyzeSkin(
        imageData: Data,
        onProgress: @escaping (String) -> Void,
        completion: @escaping (Result<AnalysisResult, Error>) -> Void
    ) {
        AWSBackendService.shared.analyzeSkin(
            imageData: imageData,
            onProgress: onProgress,
            completion: { result in
                switch result {
                case .success(let awsResponse):
                    guard let predData = awsResponse.prediction else {
                        completion(.failure(AnalysisError.invalidResponseFormat))
                        return
                    }

                    let products = (awsResponse.products ?? []).map { p in
                        #if DEBUG
                        print("[SkinAnalysis] Product: \(p.name)")
                        print("[SkinAnalysis] Amazon URL from API: '\(p.amazon_url)'")
                        #endif

                        return AnalysisResult.Product(
                            name: p.name,
                            brand: p.brand,
                            description: p.description,
                            priceRange: p.price_range,
                            amazonUrl: p.amazon_url,
                            rating: p.rating
                        )
                    }

                    // Get summary from enhanced analysis if available
                    let summary = awsResponse.enhanced_analysis?.summary

                    // Extract Claude validation data
                    let validation = awsResponse.claude_validation
                    let isValidated = predData.claude_validated ?? false
                    let claudeConf = validation?.claude_confidence
                    let agrees = validation?.agrees_with_primary
                    let severity = validation?.severity
                    let insights = validation?.full_analysis
                    let boost = validation?.confidence_boost

                    let result = AnalysisResult(
                        condition: predData.condition,
                        confidence: predData.confidence,
                        allConditions: predData.all_conditions ?? [:],
                        products: products,
                        timestamp: Date(),
                        summary: summary,
                        isClaudeValidated: isValidated,
                        claudeConfidence: claudeConf,
                        agreesWithPrimary: agrees,
                        validationSeverity: severity,
                        validationInsights: insights,
                        confidenceBoost: boost
                    )

                    completion(.success(result))

                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }
}

// MARK: - Error Types

enum AnalysisError: LocalizedError {
    case invalidURL
    case imageProcessingFailed
    case invalidResponse
    case invalidResponseFormat
    case parsingFailed
    case jsonEncodingFailed
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid service URL"
        case .imageProcessingFailed:
            return "Failed to process image"
        case .invalidResponse:
            return "Invalid server response"
        case .invalidResponseFormat:
            return "Unexpected response format"
        case .parsingFailed:
            return "Failed to parse response"
        case .jsonEncodingFailed:
            return "Failed to encode request"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        }
    }
}
