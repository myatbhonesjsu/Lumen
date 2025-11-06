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
            ContentRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

struct ContentRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]
    @State private var isOnboardingComplete = false
    @State private var hasCheckedOnboarding = false

    var body: some View {
        Group {
            if !hasCheckedOnboarding {
                // Show a loading state while checking
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                    .scaleEffect(2.0)
            } else if isOnboardingComplete {
                MainTabView()
            } else {
                ImprovedOnboardingView(isOnboardingComplete: $isOnboardingComplete)
            }
        }
        .onAppear {
            checkOnboardingStatus()
        }
    }

    private func checkOnboardingStatus() {
        // Check if user has completed onboarding
        if let profile = userProfiles.first, profile.hasCompletedOnboarding {
            isOnboardingComplete = true
        } else {
            isOnboardingComplete = false
        }
        hasCheckedOnboarding = true
    }
}
