//
//  LumenApp.swift
//  Lumen
//
//  AI Skincare Assistant
//

import SwiftUI
import SwiftData

@main
struct LumenApp: App {
    @State private var isOnboardingComplete = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SkinMetric.self,
            Recommendation.self,
            UserProfile.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if isOnboardingComplete {
                MainTabView()
            } else {
                OnboardingView(isOnboardingComplete: $isOnboardingComplete)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
