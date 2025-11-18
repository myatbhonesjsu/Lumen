//
//  DailyInsightsService.swift
//  Lumen
//
//  Service for fetching and managing daily AI-generated insights
//

import Foundation
import CoreLocation

enum DailyInsightsError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case noInsightAvailable
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API endpoint URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .noInsightAvailable:
            return "No daily insight available"
        case .generationFailed(let message):
            return "Failed to generate insight: \(message)"
        }
    }
}

class DailyInsightsService {
    static let shared = DailyInsightsService()
    
    private let apiEndpoint = AWSConfig.apiEndpoint
    private let requestTimeout: TimeInterval = 120.0 // 2 minutes for generation
    
    private init() {}
    
    // MARK: - Authentication Helper
    
    private func addAuthHeader(to request: inout URLRequest) {
        if let idToken = CognitoAuthService.shared.getIdToken() {
            request.setValue(idToken, forHTTPHeaderField: "Authorization")
        }
    }
    
    // MARK: - Generate Daily Insight
    
    /// Generate a new daily insight based on user location and context
    func generateDailyInsight(
        location: CLLocation,
        completion: @escaping (Result<DailyInsight, Error>) -> Void
    ) {
        guard let url = URL(string: "\(apiEndpoint)/daily-insights/generate") else {
            completion(.failure(DailyInsightsError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        addAuthHeader(to: &request)
        
        let requestBody = GenerateDailyInsightRequest(
            location: GenerateDailyInsightRequest.Location(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(DailyInsightsError.decodingError(error)))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(DailyInsightsError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(DailyInsightsError.networkError(NSError(domain: "DailyInsightsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let statusCode = httpResponse.statusCode
                let errorBody = data != nil ? String(data: data!, encoding: .utf8) ?? "No error details" : "No response body"
                print("❌ API Error [\(statusCode)]: \(errorBody)")
                completion(.failure(DailyInsightsError.generationFailed("HTTP \(statusCode): \(errorBody)")))
                return
            }
            
            guard let data = data, !data.isEmpty else {
                print("❌ Empty response body")
                completion(.failure(DailyInsightsError.decodingError(NSError(domain: "DailyInsightsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty response body"]))))
                return
            }
            
            // Debug: Print raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 API Response: \(responseString.prefix(500))")
            }
            
            do {
                let apiResponse = try JSONDecoder().decode(DailyInsightResponse.self, from: data)
                
                if apiResponse.success, let insight = apiResponse.data {
                    print("✅ Successfully decoded insight: \(insight.id)")
                    completion(.success(insight))
                } else {
                    let errorMessage = apiResponse.error ?? "Unknown error"
                    print("❌ API returned error: \(errorMessage)")
                    completion(.failure(DailyInsightsError.generationFailed(errorMessage)))
                }
            } catch {
                print("❌ Decoding error: \(error.localizedDescription)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("   Response body: \(jsonString)")
                }
                completion(.failure(DailyInsightsError.decodingError(error)))
            }
        }.resume()
    }
    
    // MARK: - Get Latest Insight
    
    /// Fetch the most recent daily insight for the user
    func getLatestInsight(
        completion: @escaping (Result<DailyInsight?, Error>) -> Void
    ) {
        guard let url = URL(string: "\(apiEndpoint)/daily-insights/latest") else {
            completion(.failure(DailyInsightsError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: AWSConfig.requestTimeout)
        request.httpMethod = "GET"
        
        addAuthHeader(to: &request)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(DailyInsightsError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                // 404 is acceptable - means no insight exists yet
                if (response as? HTTPURLResponse)?.statusCode == 404 {
                    completion(.success(nil))
                } else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    completion(.failure(DailyInsightsError.generationFailed("HTTP \(statusCode)")))
                }
                return
            }
            
            guard let data = data else {
                completion(.success(nil))
                return
            }
            
            do {
                let apiResponse = try JSONDecoder().decode(DailyInsightResponse.self, from: data)
                
                if apiResponse.success {
                    completion(.success(apiResponse.data))
                } else {
                    // No insight available is not an error
                    completion(.success(nil))
                }
            } catch {
                // If decoding fails but we got 200, assume no insight
                completion(.success(nil))
            }
        }.resume()
    }
    
    // MARK: - Submit Check-in Response
    
    /// Submit a user's response to a daily check-in question
    func submitCheckInResponse(
        _ response: CheckInResponse,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let url = URL(string: "\(apiEndpoint)/daily-insights/checkin") else {
            completion(.failure(DailyInsightsError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: AWSConfig.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        addAuthHeader(to: &request)
        
        let requestBody = SubmitCheckInRequest(response: response)
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(DailyInsightsError.decodingError(error)))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(DailyInsightsError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                completion(.failure(DailyInsightsError.generationFailed("HTTP \(statusCode)")))
                return
            }
            
            // Parse response to check for errors
            if let data = data {
                do {
                    let apiResponse = try JSONDecoder().decode(SubmitCheckInResponse.self, from: data)
                    if apiResponse.success {
                        completion(.success(()))
                    } else {
                        let errorMessage = apiResponse.error ?? "Unknown error"
                        completion(.failure(DailyInsightsError.generationFailed(errorMessage)))
                    }
                } catch {
                    // If we can't decode but got 200, assume success
                    completion(.success(()))
                }
            } else {
                completion(.success(()))
            }
        }.resume()
    }
    
    // MARK: - Mark Product Completed
    
    /// Mark a product as completed or uncompleted
    func markProductCompleted(
        productId: String,
        insightId: String,
        isCompleted: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let url = URL(string: "\(apiEndpoint)/daily-insights/products/\(productId)/complete") else {
            completion(.failure(DailyInsightsError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: AWSConfig.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        addAuthHeader(to: &request)
        
        let requestBody: [String: Any] = [
            "insight_id": insightId,
            "product_id": productId,
            "is_completed": isCompleted
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(DailyInsightsError.decodingError(error)))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(DailyInsightsError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                completion(.failure(DailyInsightsError.generationFailed("HTTP \(statusCode)")))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
    
    // MARK: - Submit Product Applications
    
    /// Submit multiple product applications at once
    func submitProductApplications(
        productIds: [String],
        insightId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let url = URL(string: "\(apiEndpoint)/daily-insights/products/apply") else {
            completion(.failure(DailyInsightsError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: AWSConfig.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        addAuthHeader(to: &request)
        
        let requestBody: [String: Any] = [
            "insight_id": insightId,
            "product_ids": productIds
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(DailyInsightsError.decodingError(error)))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(DailyInsightsError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                completion(.failure(DailyInsightsError.generationFailed("HTTP \(statusCode)")))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
}

