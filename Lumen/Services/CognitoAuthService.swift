/**
 * CognitoAuthService.swift
 * Simple Cognito authentication service for demo purposes
 *
 * This service automatically authenticates with a demo user on app launch,
 * eliminating the need for sign-up/sign-in UI while still demonstrating
 * proper API authentication.
 */

import Foundation

// MARK: - Cognito Configuration
enum CognitoConfig {
    static let userPoolId = "us-east-1_NBBGEaCAW"
    static let clientId = "6kf024iqqn4hqopqn72hsvlmr7"
    static let region = "us-east-1"

    // Demo user credentials (hardcoded for demo purposes)
    static let demoEmail = "demo@lumen-app.com"
    static let demoPassword = "DemoPass123!"

    #if DEBUG
    static let enableLogging = true
    #else
    static let enableLogging = false
    #endif
}

// MARK: - Logging Helper
private func authLog(_ message: String) {
    if CognitoConfig.enableLogging {
        print("[CognitoAuth] \(message)")
    }
}

// MARK: - Authentication Error
enum CognitoAuthError: Error, LocalizedError {
    case authenticationFailed(String)
    case networkError(Error)
    case invalidResponse
    case tokenExpired

    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from Cognito"
        case .tokenExpired:
            return "Token expired, please re-authenticate"
        }
    }
}

// MARK: - Authentication Response Models
private struct CognitoAuthResponse: Codable, @unchecked Sendable {
    struct AuthenticationResult: Codable, @unchecked Sendable {
        let AccessToken: String
        let ExpiresIn: Int
        let IdToken: String
        let RefreshToken: String?
        let TokenType: String
    }

    let AuthenticationResult: AuthenticationResult
    let ChallengeParameters: [String: String]?
}

// MARK: - Cognito Auth Service
class CognitoAuthService {
    static let shared = CognitoAuthService()

    private var idToken: String?
    private var accessToken: String?
    private var tokenExpiry: Date?
    private var isAuthenticating = false

    private init() {
        authLog("CognitoAuthService initialized")
    }

    // MARK: - Public API

    /**
     * Get the current ID token (used for API authentication)
     * Returns nil if not authenticated
     */
    func getIdToken() -> String? {
        // Check if token is still valid
        if let expiry = tokenExpiry, Date() > expiry {
            authLog("⚠️ Token expired, needs re-authentication")
            idToken = nil
            return nil
        }
        return idToken
    }

    /**
     * Check if user is currently authenticated
     */
    var isAuthenticated: Bool {
        guard let _ = idToken, let expiry = tokenExpiry else {
            return false
        }
        return Date() < expiry
    }

    /**
     * Authenticate with demo user credentials
     * This is called automatically on app launch
     */
    func authenticateDemo(completion: @escaping (Result<Void, Error>) -> Void) {
        // Prevent multiple simultaneous authentication attempts
        guard !isAuthenticating else {
            authLog("⏳ Authentication already in progress")
            return
        }

        // Check if already authenticated with valid token
        if isAuthenticated {
            authLog("✅ Already authenticated with valid token")
            completion(.success(()))
            return
        }

        isAuthenticating = true
        authLog("🔐 Starting demo user authentication...")

        // Use Cognito InitiateAuth API with USER_PASSWORD_AUTH flow
        let cognitoEndpoint = "https://cognito-idp.\(CognitoConfig.region).amazonaws.com/"

        guard let url = URL(string: cognitoEndpoint) else {
            isAuthenticating = false
            completion(.failure(CognitoAuthError.invalidResponse))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("AWSCognitoIdentityProviderService.InitiateAuth", forHTTPHeaderField: "X-Amz-Target")
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "AuthFlow": "USER_PASSWORD_AUTH",
            "ClientId": CognitoConfig.clientId,
            "AuthParameters": [
                "USERNAME": CognitoConfig.demoEmail,
                "PASSWORD": CognitoConfig.demoPassword
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            isAuthenticating = false
            completion(.failure(CognitoAuthError.networkError(error)))
            return
        }

        authLog("📤 Sending authentication request to Cognito...")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            self.isAuthenticating = false

            if let error = error {
                authLog("❌ Network error: \(error.localizedDescription)")
                completion(.failure(CognitoAuthError.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                authLog("❌ Invalid HTTP response")
                completion(.failure(CognitoAuthError.invalidResponse))
                return
            }

            authLog("📥 Received response with status code: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode), let data = data else {
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                authLog("❌ Authentication failed: \(errorMessage)")
                completion(.failure(CognitoAuthError.authenticationFailed(errorMessage)))
                return
            }

            do {
                let authResponse = try JSONDecoder().decode(CognitoAuthResponse.self, from: data)

                // Store tokens
                self.idToken = authResponse.AuthenticationResult.IdToken
                self.accessToken = authResponse.AuthenticationResult.AccessToken

                // Calculate token expiry (expires in seconds from now)
                let expiresIn = TimeInterval(authResponse.AuthenticationResult.ExpiresIn)
                self.tokenExpiry = Date().addingTimeInterval(expiresIn)

                authLog("✅ Demo user authenticated successfully")
                authLog("   Token expires in: \(expiresIn / 60) minutes")
                authLog("   Token type: \(authResponse.AuthenticationResult.TokenType)")

                completion(.success(()))

            } catch {
                authLog("❌ Failed to decode auth response: \(error)")
                #if DEBUG
                if let responseString = String(data: data, encoding: .utf8) {
                    authLog("   Raw response: \(responseString)")
                }
                #endif
                completion(.failure(CognitoAuthError.invalidResponse))
            }
        }.resume()
    }

    /**
     * Clear authentication state (logout)
     */
    func logout() {
        authLog("🚪 Logging out and clearing tokens")
        idToken = nil
        accessToken = nil
        tokenExpiry = nil
    }

    /**
     * Get authentication status string for debugging
     */
    var statusDescription: String {
        if isAuthenticated {
            if let expiry = tokenExpiry {
                let remaining = expiry.timeIntervalSinceNow / 60
                return "Authenticated (expires in \(Int(remaining)) minutes)"
            }
            return "Authenticated"
        } else {
            return "Not authenticated"
        }
    }
}
