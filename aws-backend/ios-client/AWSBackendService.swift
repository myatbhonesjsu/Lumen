/**
 * AWSBackendService.swift
 * iOS client for AWS backend
 * 
 * Replace the direct Gemini/HuggingFace calls with this service
 */

import Foundation
import UIKit

// MARK: - Configuration
enum AWSConfig {
    // TODO: Replace with your API Gateway URL after deployment
    static let apiEndpoint = "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/dev"
    
    static let requestTimeout: TimeInterval = 60.0
}

// MARK: - Error Types
enum AWSBackendError: Error, LocalizedError {
    case invalidURL
    case uploadFailed(String)
    case analysisFailed(String)
    case networkError(Error)
    case decodingError(Error)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API endpoint URL"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .analysisFailed(let message):
            return "Analysis failed: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out"
        }
    }
}

// MARK: - Response Models
struct UploadResponse: Codable {
    let analysis_id: String
    let upload_url: String
    let message: String
}

struct AnalysisResponse: Codable {
    let analysis_id: String
    let status: String
    let timestamp: Int?
    let prediction: PredictionData?
    let enhanced_analysis: EnhancedAnalysisData?
    let products: [ProductData]?
    
    struct PredictionData: Codable {
        let condition: String
        let confidence: Double
        let all_conditions: [String: Double]?
    }
    
    struct EnhancedAnalysisData: Codable {
        let summary: String
        let recommendations: [String]
        let severity: String
        let care_instructions: [String]
    }
    
    struct ProductData: Codable {
        let product_id: String
        let name: String
        let brand: String
        let description: String
        let price_range: String
        let amazon_url: String
        let rating: Double
        let review_count: Int
    }
}

// MARK: - AWS Backend Service
class AWSBackendService {
    static let shared = AWSBackendService()
    
    private init() {}
    
    // MARK: - Public API
    
    /**
     * Analyze skin image using AWS backend
     * 
     * This replaces the current two-stage analysis (HuggingFace + Gemini)
     * with a single AWS backend call.
     */
    func analyzeSkin(
        image: UIImage,
        onProgress: @escaping (String) -> Void,
        completion: @escaping (Result<AnalysisResponse, Error>) -> Void
    ) {
        // Step 1: Get upload URL
        onProgress("Preparing upload...")
        
        requestUploadURL { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let uploadResponse):
                // Step 2: Upload image to S3
                onProgress("Uploading image...")
                
                self.uploadImage(image, to: uploadResponse.upload_url) { uploadResult in
                    switch uploadResult {
                    case .success:
                        // Step 3: Poll for results
                        onProgress("Analyzing skin condition...")
                        
                        self.pollForResults(
                            analysisId: uploadResponse.analysis_id,
                            onProgress: onProgress,
                            completion: completion
                        )
                        
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /**
     * Get product recommendations for a condition
     */
    func getRecommendations(
        condition: String,
        limit: Int = 5,
        completion: @escaping (Result<[AnalysisResponse.ProductData], Error>) -> Void
    ) {
        guard let url = URL(string: "\(AWSConfig.apiEndpoint)/products/recommendations?condition=\(condition)&limit=\(limit)") else {
            completion(.failure(AWSBackendError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: AWSConfig.requestTimeout)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(AWSBackendError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                completion(.failure(AWSBackendError.analysisFailed("Invalid response")))
                return
            }
            
            do {
                struct RecommendationsResponse: Codable {
                    let products: [AnalysisResponse.ProductData]
                }
                
                let decoded = try JSONDecoder().decode(RecommendationsResponse.self, from: data)
                completion(.success(decoded.products))
            } catch {
                completion(.failure(AWSBackendError.decodingError(error)))
            }
        }.resume()
    }
    
    // MARK: - Private Methods
    
    private func requestUploadURL(completion: @escaping (Result<UploadResponse, Error>) -> Void) {
        guard let url = URL(string: "\(AWSConfig.apiEndpoint)/upload-image") else {
            completion(.failure(AWSBackendError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: AWSConfig.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Optional: Add user ID header
        // request.setValue(userID, forHTTPHeaderField: "x-user-id")
        
        print("🔄 Requesting upload URL...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Upload URL request failed: \(error.localizedDescription)")
                completion(.failure(AWSBackendError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                print("❌ Invalid response from server")
                completion(.failure(AWSBackendError.uploadFailed("Invalid response")))
                return
            }
            
            do {
                let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
                print("✅ Upload URL received: \(uploadResponse.analysis_id)")
                completion(.success(uploadResponse))
            } catch {
                print("❌ Failed to decode upload response: \(error)")
                completion(.failure(AWSBackendError.decodingError(error)))
            }
        }.resume()
    }
    
    private func uploadImage(_ image: UIImage, to presignedURL: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: presignedURL),
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(AWSBackendError.uploadFailed("Failed to prepare image")))
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: AWSConfig.requestTimeout)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        print("⬆️ Uploading image (\(imageData.count / 1024) KB)...")
        let startTime = Date()
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            let duration = Date().timeIntervalSince(startTime)
            
            if let error = error {
                print("❌ Image upload failed (\(String(format: "%.1f", duration))s): \(error.localizedDescription)")
                completion(.failure(AWSBackendError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("❌ Upload failed with invalid status code")
                completion(.failure(AWSBackendError.uploadFailed("Server error")))
                return
            }
            
            print("✅ Image uploaded successfully (\(String(format: "%.1f", duration))s)")
            completion(.success(()))
        }.resume()
    }
    
    private func pollForResults(
        analysisId: String,
        maxAttempts: Int = 30,
        pollInterval: TimeInterval = 2.0,
        onProgress: @escaping (String) -> Void,
        completion: @escaping (Result<AnalysisResponse, Error>) -> Void
    ) {
        var attempts = 0
        
        func poll() {
            attempts += 1
            
            guard attempts <= maxAttempts else {
                completion(.failure(AWSBackendError.timeout))
                return
            }
            
            getAnalysisResults(analysisId: analysisId) { result in
                switch result {
                case .success(let response):
                    if response.status == "completed" {
                        print("✅ Analysis completed after \(attempts) attempts")
                        completion(.success(response))
                    } else if response.status == "failed" {
                        completion(.failure(AWSBackendError.analysisFailed("Analysis failed on server")))
                    } else {
                        // Still processing, poll again
                        onProgress("Processing... (\(attempts)/\(maxAttempts))")
                        DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) {
                            poll()
                        }
                    }
                    
                case .failure(let error):
                    // Retry on transient errors
                    if attempts < maxAttempts {
                        DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) {
                            poll()
                        }
                    } else {
                        completion(.failure(error))
                    }
                }
            }
        }
        
        poll()
    }
    
    private func getAnalysisResults(analysisId: String, completion: @escaping (Result<AnalysisResponse, Error>) -> Void) {
        guard let url = URL(string: "\(AWSConfig.apiEndpoint)/analysis/\(analysisId)") else {
            completion(.failure(AWSBackendError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: AWSConfig.requestTimeout)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(AWSBackendError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                completion(.failure(AWSBackendError.analysisFailed("Invalid response")))
                return
            }
            
            do {
                let analysisResponse = try JSONDecoder().decode(AnalysisResponse.self, from: data)
                completion(.success(analysisResponse))
            } catch {
                completion(.failure(AWSBackendError.decodingError(error)))
            }
        }.resume()
    }
}

// MARK: - Integration Example

/**
 * To integrate this into your existing app:
 *
 * 1. Replace SkinAnalysisService.shared.analyzeSkin() with:
 *
 * AWSBackendService.shared.analyzeSkin(
 *     image: capturedImage,
 *     onProgress: { message in
 *         // Update UI with progress message
 *     },
 *     completion: { result in
 *         switch result {
 *         case .success(let analysis):
 *             // Map AWS response to your existing models
 *             let prediction = InitialPrediction(
 *                 condition: analysis.prediction?.condition ?? "Unknown",
 *                 confidence: analysis.prediction?.confidence ?? 0.0,
 *                 allConditions: analysis.prediction?.all_conditions ?? [:]
 *             )
 *
 *             let enhanced = ComprehensiveAnalysis(
 *                 summary: analysis.enhanced_analysis?.summary ?? "",
 *                 recommendations: analysis.enhanced_analysis?.recommendations ?? [],
 *                 severity: analysis.enhanced_analysis?.severity ?? "mild",
 *                 careInstructions: analysis.enhanced_analysis?.care_instructions ?? []
 *             )
 *
 *             // Update UI
 *             self.initialPrediction = prediction
 *             self.enhancedAnalysis = enhanced
 *
 *         case .failure(let error):
 *             print("Analysis failed: \(error)")
 *             self.analysisError = error
 *         }
 *     }
 * )
 *
 * 2. Update AWSConfig.apiEndpoint with your deployed API Gateway URL
 *
 * 3. That's it! No more Gemini API keys in the app.
 */

