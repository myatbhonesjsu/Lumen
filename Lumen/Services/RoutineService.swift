//
//  RoutineService.swift
//  Lumen
//
//  Service for generating personalized skincare routines via AI
//

import Foundation
import SwiftData

class RoutineService {
    static let shared = RoutineService()

    private let baseURL = "https://ocbpgt6ebc.execute-api.us-east-1.amazonaws.com/dev"

    private init() {}

    /// Generate a personalized routine based on latest skin analysis
    func generatePersonalizedRoutine(
        userId: String,
        latestMetric: SkinMetric,
        budget: String = "moderate",
        preferences: [String: String]? = nil
    ) async throws -> PersonalizedRoutine {

        // Build request
        let request = RoutineGenerationRequest(
            userId: userId,
            latestAnalysis: LatestAnalysisData(from: latestMetric),
            budget: budget,
            preferences: preferences
        )

        // Create URL
        guard let url = URL(string: "\(baseURL)/learning-hub/routines/generate") else {
            throw RoutineError.invalidURL
        }

        // Create HTTP request
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Encode request body
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        print("🔄 Generating personalized routine for user: \(userId)")
        print("📊 Analysis data: Acne=\(Int(latestMetric.acneLevel))%, Dryness=\(Int(latestMetric.drynessLevel))%")

        // Send request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RoutineError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ Routine generation failed with status: \(httpResponse.statusCode)")
            if let errorStr = String(data: data, encoding: .utf8) {
                print("Error response: \(errorStr)")
            }
            throw RoutineError.serverError(statusCode: httpResponse.statusCode)
        }

        // Decode response
        let decoder = JSONDecoder()
        let routineResponse = try decoder.decode(RoutineGenerationResponse.self, from: data)

        print("✅ Personalized routine generated successfully!")
        print("📋 Morning steps: \(routineResponse.routine.morningRoutine.count)")
        print("📋 Evening steps: \(routineResponse.routine.eveningRoutine.count)")
        print("🎯 Key concerns: \(routineResponse.routine.keyConcerns.joined(separator: ", "))")

        // Create PersonalizedRoutine model
        let routine = PersonalizedRoutine(from: routineResponse)

        return routine
    }

    /// Save routine to SwiftData
    func saveRoutine(_ routine: PersonalizedRoutine, to context: ModelContext) {
        context.insert(routine)
        try? context.save()
        print("💾 Routine saved to local storage")
    }

    /// Get latest saved routine for user
    func getLatestRoutine(for userId: String, from context: ModelContext) -> PersonalizedRoutine? {
        let descriptor = FetchDescriptor<PersonalizedRoutine>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )

        let routines = try? context.fetch(descriptor)
        return routines?.first
    }

    /// Check if routine is outdated (older than 30 days)
    func isRoutineOutdated(_ routine: PersonalizedRoutine) -> Bool {
        let daysSinceGeneration = Calendar.current.dateComponents([.day], from: routine.generatedAt, to: Date()).day ?? 0
        return daysSinceGeneration > 30
    }

    /// Determine if a new routine should be generated based on analysis changes
    func shouldRegenerateRoutine(
        currentRoutine: PersonalizedRoutine?,
        newMetric: SkinMetric
    ) -> Bool {

        guard let current = currentRoutine else {
            return true // No routine exists
        }

        // Regenerate if routine is outdated
        if isRoutineOutdated(current) {
            print("🔄 Routine is outdated (>30 days), should regenerate")
            return true
        }

        // Regenerate if skin concerns changed significantly
        let acneChanged = abs(newMetric.acneLevel - current.overallHealth) > 20
        let drynessChanged = abs(newMetric.drynessLevel - current.overallHealth) > 20

        if acneChanged || drynessChanged {
            print("🔄 Skin concerns changed significantly, should regenerate")
            return true
        }

        return false
    }
}

// MARK: - Errors

enum RoutineError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error (Status: \(code))"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
