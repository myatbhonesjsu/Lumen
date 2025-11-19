/**
 * AWSBackendService.swift
 * iOS client for AWS backend
 *
 *
 */

@preconcurrency import Foundation

// MARK: - Configuration
enum AWSConfig {
    // Updated to the live API Gateway URL (use the one deployed in the new account)
    static let apiEndpoint = "https://qwfgaxng4a.execute-api.us-east-1.amazonaws.com/dev"
    static let requestTimeout: TimeInterval = 60.0
    // Optional API key for API Gateway (if your deployment requires an API key)
    // If you have an API key from Terraform outputs or API Gateway, set it here for local testing.
    static let apiKey: String? = nil

    #if DEBUG
    static let enableLogging = true
    #else
    static let enableLogging = false
    #endif
}

// MARK: - Logging Helper
private func log(_ message: String) {
    if AWSConfig.enableLogging {
        print("[AWSBackend] \(message)")
    }
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
struct UploadResponse: Codable, @unchecked Sendable {
    let analysis_id: String
    let upload_url: String
    let message: String
}

struct AnalysisResponse: Codable, @unchecked Sendable {
    let analysis_id: String
    let status: String
    let timestamp: Int?
    let prediction: PredictionData?
    let enhanced_analysis: EnhancedAnalysisData?
    let products: [ProductData]?
    let claude_validation: ClaudeValidationData?  // Hybrid dual-analysis result

    struct PredictionData: Codable, @unchecked Sendable {
        let condition: String
        let confidence: Double
        let all_conditions: [String: Double]?
        let claude_validated: Bool?  // True if dual analysis was performed
    }

    struct EnhancedAnalysisData: Codable, @unchecked Sendable {
        let summary: String
        let recommendations: [String]
        let severity: String
        let care_instructions: [String]
    }

    struct ClaudeValidationData: Codable, @unchecked Sendable {
        // Hybrid Dual Analysis Result (HuggingFace + Claude)
        let status: String                    // "success" or "error"
        let agrees_with_primary: Bool?        // True if both models agree
        let claude_confidence: Double?        // Claude's independent confidence
        let overall_confidence: Double?       // Final hybrid confidence
        let confidence_boost: Double?         // Boost from consensus
        let severity: String?                 // Severity from Claude
        let full_analysis: String?            // Clinical insights
        let discrepancies: [String]?          // If models disagree
        let validation_mode: String?          // "consensus", "hybrid", or "single"
    }

    struct ProductData: Codable, @unchecked Sendable {
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

    // Debugging helpers surfaced to the UI when needed
    static var lastHTTPStatus: Int? = nil
    static var lastResponseBody: String? = nil
    static var lastAnalysisId: String? = nil

    private init() {}

    // MARK: - Nonisolated Decoding Helpers

    nonisolated private func decodeUploadResponse(from data: Data) throws -> UploadResponse {
        try JSONDecoder().decode(UploadResponse.self, from: data)
    }

    nonisolated private func decodeAnalysisResponse(from data: Data) throws -> AnalysisResponse {
        try JSONDecoder().decode(AnalysisResponse.self, from: data)
    }
    
    // MARK: - Public API
    
    /**
     * Analyze skin image using AWS backend
     *
     * This replaces the current two-stage analysis (HuggingFace + Gemini)
     * with a single AWS backend call.
     */
    func analyzeSkin(
        imageData: Data,
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
                
                self.uploadImage(imageData, to: uploadResponse.upload_url) { uploadResult in
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
    // Attach auth token if available
    attachAuthIfNeeded(to: &request)

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
    
    /**
     * Submit user feedback to AWS backend without CognitoAuthService
     */
    func submitFeedback(
        feedback: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let url = URL(string: "\(AWSConfig.apiEndpoint)/feedback") else {
            completion(.failure(AWSBackendError.invalidURL))
            return
        }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // Attach auth token if available
    attachAuthIfNeeded(to: &request)

        let feedbackData = ["feedback": feedback]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: feedbackData, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                AWSBackendService.lastHTTPStatus = httpResponse.statusCode
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(.failure(AWSBackendError.uploadFailed("Failed to submit feedback")))
                return
            }

            completion(.success(()))
        }

        task.resume()
    }

    // MARK: - Fetch simple metrics
    struct TimePoint: Codable, @unchecked Sendable {
        let timestamp: String
        let value: Int
    }

    struct Metrics: Codable, @unchecked Sendable {
        let total_analyses: Int
        let total_feedback: Int
        let thumbs_up: Int
        let thumbs_down: Int
        let timeseries: [TimePoint]?
    }

    func fetchMetrics(completion: @escaping (Result<Metrics, Error>) -> Void) {
        guard let url = URL(string: "\(AWSConfig.apiEndpoint)/metrics?timeseries=1") else {
            completion(.failure(AWSBackendError.invalidURL))
            return
        }

        var request = URLRequest(url: url, timeoutInterval: AWSConfig.requestTimeout)
        request.httpMethod = "GET"
        attachAuthIfNeeded(to: &request)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(AWSBackendError.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(AWSBackendError.analysisFailed("Invalid HTTP response")))
                return
            }

            // Record status and body for debugging
            AWSBackendService.lastHTTPStatus = httpResponse.statusCode
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                AWSBackendService.lastResponseBody = responseString
            } else {
                AWSBackendService.lastResponseBody = nil
            }

            guard (200...299).contains(httpResponse.statusCode), let data = data else {
                let errorBody = AWSBackendService.lastResponseBody ?? "No body"
                completion(.failure(AWSBackendError.analysisFailed("HTTP \(httpResponse.statusCode): \(errorBody)")))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(Metrics.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(AWSBackendError.decodingError(error)))
            }
        }.resume()
    }
    
    // MARK: - Private Methods

    // Attach authorization header when available (Cognito ID token)
    private func attachAuthIfNeeded(to request: inout URLRequest) {
        // Prefer Cognito ID token if available
        if let idToken = CognitoAuthService.shared.getIdToken() {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            log("Attached Authorization header (Bearer token)")
            return
        }

        // Fallback: attach API key header for API Gateway if configured
        if let key = AWSConfig.apiKey, !key.isEmpty {
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            log("Attached x-api-key header for API Gateway")
        }
    }
    
    private func requestUploadURL(completion: @escaping (Result<UploadResponse, Error>) -> Void) {
        guard let url = URL(string: "\(AWSConfig.apiEndpoint)/upload-image") else {
            log(" Invalid URL: \(AWSConfig.apiEndpoint)/upload-image")
            completion(.failure(AWSBackendError.invalidURL))
            return
        }

        var request = URLRequest(url: url, timeoutInterval: AWSConfig.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // Attach auth token if available
    attachAuthIfNeeded(to: &request)

        log(" Requesting upload URL from: \(url.absoluteString)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                log(" Upload URL request failed: \(error.localizedDescription)")
                completion(.failure(AWSBackendError.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                log(" Invalid HTTP response")
                AWSBackendService.lastHTTPStatus = nil
                AWSBackendService.lastResponseBody = nil
                completion(.failure(AWSBackendError.uploadFailed("Invalid response")))
                return
            }

            AWSBackendService.lastHTTPStatus = httpResponse.statusCode
            log(" HTTP Status Code: \(httpResponse.statusCode)")

            // Log response body for debugging
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                AWSBackendService.lastResponseBody = responseString
                log(" Response: \(responseString)")
            }

            guard (200...299).contains(httpResponse.statusCode), let data = data else {
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body"
                log(" Server error (\(httpResponse.statusCode)): \(errorMessage)")
                completion(.failure(AWSBackendError.uploadFailed("HTTP \(httpResponse.statusCode): \(errorMessage)")))
                return
            }

            do {
                let uploadResponse = try self.decodeUploadResponse(from: data)
                AWSBackendService.lastAnalysisId = uploadResponse.analysis_id
                log(" Upload URL received: \(uploadResponse.analysis_id)")
                completion(.success(uploadResponse))
            } catch {
                log(" Failed to decode upload response: \(error)")
                completion(.failure(AWSBackendError.decodingError(error)))
            }
        }.resume()
    }
    
    private func uploadImage(_ imageData: Data, to presignedURL: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: presignedURL) else {
            completion(.failure(AWSBackendError.uploadFailed("Invalid presigned URL")))
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: AWSConfig.requestTimeout)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        log("Uploading image (\(imageData.count / 1024) KB)...")
        let startTime = Date()
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            let duration = Date().timeIntervalSince(startTime)
            
            if let error = error {
                log("Image upload failed (\(String(format: "%.1f", duration))s): \(error.localizedDescription)")
                completion(.failure(AWSBackendError.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                if let httpResponse = response as? HTTPURLResponse {
                    AWSBackendService.lastHTTPStatus = httpResponse.statusCode
                }
                log("Upload failed with invalid status code")
                completion(.failure(AWSBackendError.uploadFailed("Server error")))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                AWSBackendService.lastHTTPStatus = httpResponse.statusCode
            }
            log("Image uploaded successfully (\(String(format: "%.1f", duration))s)")
            completion(.success(()))
        }.resume()
    }
    
    private func pollForResults(
        analysisId: String,
        maxAttempts: Int = 60,  // Increased from 30 to 60
        pollInterval: TimeInterval = 3.0,  // Increased from 2.0 to 3.0 seconds
        onProgress: @escaping (String) -> Void,
        completion: @escaping (Result<AnalysisResponse, Error>) -> Void
    ) {
        var attempts = 0
        let startTime = Date()

        func poll() {
            attempts += 1
            let elapsed = Date().timeIntervalSince(startTime)

            guard attempts <= maxAttempts else {
                log("Polling timed out after \(attempts) attempts (\(String(format: "%.1f", elapsed))s)")
                completion(.failure(AWSBackendError.timeout))
                return
            }

            log("Polling attempt \(attempts)/\(maxAttempts) (elapsed: \(String(format: "%.1f", elapsed))s)")

            getAnalysisResults(analysisId: analysisId) { result in
                switch result {
                case .success(let response):
                    log("Poll response - status: \(response.status)")

                    if response.status == "completed" {
                        log("Analysis completed after \(attempts) attempts (\(String(format: "%.1f", elapsed))s)")
                        log("  - Has prediction: \(response.prediction != nil)")
                        log("  - Has enhanced analysis: \(response.enhanced_analysis != nil)")
                        log("  - Has products: \(response.products?.count ?? 0) products")
                        completion(.success(response))
                    } else if response.status == "failed" {
                        log("Analysis failed on server after \(attempts) attempts")
                        completion(.failure(AWSBackendError.analysisFailed("Analysis failed on server")))
                    } else {
                        // Still processing, poll again
                        onProgress("Processing")
                        log("Still processing, will retry in \(pollInterval)s...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) {
                            poll()
                        }
                    }

                case .failure(let error):
                    log("Poll attempt \(attempts) failed: \(error.localizedDescription)")
                    // Retry on transient errors
                    if attempts < maxAttempts {
                        onProgress("Retrying")
                        DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) {
                            poll()
                        }
                    } else {
                        log("Max attempts reached with errors")
                        completion(.failure(error))
                    }
                }
            }
        }

        // Start first poll immediately
        poll()
    }
    
    private func getAnalysisResults(analysisId: String, completion: @escaping (Result<AnalysisResponse, Error>) -> Void) {
        guard let url = URL(string: "\(AWSConfig.apiEndpoint)/analysis/\(analysisId)") else {
            log("Invalid URL: \(AWSConfig.apiEndpoint)/analysis/\(analysisId)")
            completion(.failure(AWSBackendError.invalidURL))
            return
        }

    var request = URLRequest(url: url, timeoutInterval: AWSConfig.requestTimeout)
    request.httpMethod = "GET"
    // Attach auth token if available
    attachAuthIfNeeded(to: &request)

        log("GET request: \(url.absoluteString)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                log("Network error: \(error.localizedDescription)")
                completion(.failure(AWSBackendError.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                log("Invalid HTTP response")
                AWSBackendService.lastHTTPStatus = nil
                AWSBackendService.lastResponseBody = nil
                completion(.failure(AWSBackendError.analysisFailed("Invalid response")))
                return
            }

            AWSBackendService.lastHTTPStatus = httpResponse.statusCode
            log("HTTP Status: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode), let data = data else {
                let errorBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No body"
                AWSBackendService.lastResponseBody = errorBody
                log("HTTP error \(httpResponse.statusCode): \(errorBody)")
                completion(.failure(AWSBackendError.analysisFailed("HTTP \(httpResponse.statusCode): \(errorBody)")))
                return
            }

            // Log raw response for debugging in debug builds only
            #if DEBUG
            if let responseString = String(data: data, encoding: .utf8) {
                AWSBackendService.lastResponseBody = responseString
                log("Raw API response: \(responseString)")
            }
            #endif

            do {
                let analysisResponse = try self.decodeAnalysisResponse(from: data)
                log("Successfully decoded analysis response")
                completion(.success(analysisResponse))
            } catch {
                log("Decoding error: \(error)")
                if let decodingError = error as? DecodingError {
                    log("  Details: \(decodingError)")
                }
                completion(.failure(AWSBackendError.decodingError(error)))
            }
        }.resume()
    }
}
