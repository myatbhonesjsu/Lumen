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

    struct Product: Equatable {
        let name: String
        let brand: String
        let description: String
        let priceRange: String
        let amazonUrl: String
        let rating: Double
    }
}

class SkinAnalysisService {
    static let shared = SkinAnalysisService()

    private init() {}

    // MARK: - Public API

    /// Analyzes skin using AWS backend
    /// - Parameters:
    ///   - image: The skin image to analyze
    ///   - onProgress: Progress updates during analysis
    ///   - completion: Called when analysis completes with result
    func analyzeSkin(
        image: UIImage,
        onProgress: @escaping (String) -> Void,
        completion: @escaping (Result<AnalysisResult, Error>) -> Void
    ) {
        AWSBackendService.shared.analyzeSkin(
            image: image,
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

                    let result = AnalysisResult(
                        condition: predData.condition,
                        confidence: predData.confidence,
                        allConditions: predData.all_conditions ?? [:],
                        products: products,
                        timestamp: Date(),
                        summary: summary
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
