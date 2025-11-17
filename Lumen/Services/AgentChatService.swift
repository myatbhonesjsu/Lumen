//
//  AgentChatService.swift
//  Lumen
//
//  Service for invoking OpenAI GPT-4o agents with analysis data and getting conversational responses
//

import Foundation

enum AgentType: String {
    case skinAnalyst = "skin-analyst"
    case routineCoach = "routine-coach"
}

enum AgentChatError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case apiFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API endpoint URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .apiFailed(let message):
            return "API failed: \(message)"
        }
    }
}

struct AgentChatRequest: Codable {
    let analysisId: String?
    let message: String?
}

struct AgentChatResponse: Codable {
    let success: Bool
    let data: AgentChatData?
    let error: String?
}

struct AgentChatData: Codable {
    let response: String
    let sessionId: String?
    let agentType: String?
    let model: String?

    enum CodingKeys: String, CodingKey {
        case response
        case sessionId
        case agentType = "agent_type"
        case model
    }
}

class AgentChatService {
    static let shared = AgentChatService()
    
    private let apiEndpoint = AWSConfig.apiEndpoint
    private let requestTimeout: TimeInterval = 120.0 // 2 minutes for agent processing
    
    private init() {}
    
    // MARK: - Authentication Helper
    
    private func addAuthHeader(to request: inout URLRequest) {
        if let idToken = CognitoAuthService.shared.getIdToken() {
            request.setValue(idToken, forHTTPHeaderField: "Authorization")
        }
    }
    
    // MARK: - Invoke Agent with Analysis
    
    /// Invoke an OpenAI GPT-4o agent with analysis data and get conversational response
    /// - Parameters:
    ///   - agentType: The type of agent to invoke (skinAnalyst or routineCoach)
    ///   - analysisId: Optional analysis ID to include context
    ///   - message: Optional custom message (if nil, will use default with analysis context)
    ///   - completion: Completion handler with agent's conversational response
    func invokeAgent(
        agentType: AgentType,
        analysisId: String? = nil,
        message: String? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "\(apiEndpoint)/agent-chat/\(agentType.rawValue)") else {
            completion(.failure(AgentChatError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)
        
        let requestBody = AgentChatRequest(analysisId: analysisId, message: message)
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(AgentChatError.decodingError(error)))
            return
        }
        
        print("🤖 Invoking \(agentType.rawValue) agent with analysis: \(analysisId ?? "none")")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(AgentChatError.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response")
                completion(.failure(AgentChatError.networkError(
                    NSError(domain: "AgentChatService", code: -1,
                           userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                )))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let statusCode = httpResponse.statusCode
                let errorBody = data != nil ? String(data: data!, encoding: .utf8) ?? "No error details" : "No response body"
                print("❌ API Error [\(statusCode)]: \(errorBody)")
                completion(.failure(AgentChatError.apiFailed("HTTP \(statusCode): \(errorBody)")))
                return
            }
            
            guard let data = data, !data.isEmpty else {
                print("❌ Empty response body")
                completion(.failure(AgentChatError.apiFailed("Empty response")))
                return
            }
            
            // Debug: Print raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Agent Response: \(responseString.prefix(500))")
            }
            
            do {
                let apiResponse = try JSONDecoder().decode(AgentChatResponse.self, from: data)
                
                if apiResponse.success, let chatData = apiResponse.data {
                    print("✅ Successfully received agent response")
                    completion(.success(chatData.response))
                } else {
                    let errorMessage = apiResponse.error ?? "Unknown error from agent"
                    print("❌ Agent returned error: \(errorMessage)")
                    completion(.failure(AgentChatError.apiFailed(errorMessage)))
                }
            } catch {
                print("❌ Decoding error: \(error.localizedDescription)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("   Response body: \(jsonString.prefix(1000))")
                }
                completion(.failure(AgentChatError.decodingError(error)))
            }
        }.resume()
    }
}

