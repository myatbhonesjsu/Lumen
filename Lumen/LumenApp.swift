//
//  LumenApp.swift
//  Lumen
//
//  AI Skincare Assistant
//

import SwiftUI
import SwiftData

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - App

@main
struct LumenApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SkinMetric.self,
            UserProfile.self,
            DailyRoutine.self,
            PersonalizedRoutine.self,
            PersistedChatMessage.self
        ])
        
        // Try default configuration first
        let defaultConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // Delete old database files proactively to avoid migration issues
        resetDatabaseIfNeeded()

        do {
            return try ModelContainer(for: schema, configurations: [defaultConfig])
        } catch {
            // Schema migration failed - reset database
            print("⚠️ ModelContainer creation failed: \(error)")
            print("🔄 Resetting database due to schema changes...")

            // Force delete all database files
            resetDatabase()

            // SwiftData stores data in Application Support by default
            // Try to find and delete all possible database files
            let fileManager = FileManager.default
            let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

            let possiblePaths = [
                "default.store",
                "default.store.sqlite",
                "default.store-wal",
                "default.store-shm"
            ]

            for path in possiblePaths {
                let url = appSupportURL.appendingPathComponent(path)
                if fileManager.fileExists(atPath: url.path) {
                    do {
                        try fileManager.removeItem(at: url)
                        print("🗑️ Deleted: \(path)")
                    } catch {
                        print("⚠️ Could not delete \(path): \(error)")
                    }
                }
            }
            
            // Try creating container again with fresh database
            do {
                let newContainer = try ModelContainer(for: schema, configurations: [defaultConfig])
                print("✅ Database reset successful - starting fresh")
                return newContainer
            } catch {
                // If still failing, use in-memory database as fallback
                print("❌ Database reset failed: \(error)")
                print("⚠️ Using in-memory database (data will not persist)")
                
                let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                if let inMemoryContainer = try? ModelContainer(for: schema, configurations: [inMemoryConfig]) {
                    return inMemoryContainer
                }
                
                // Last resort - but provide helpful error message
                let errorMessage = """
                Could not create ModelContainer: \(error)
                
                This usually happens when the database schema has changed.
                Please delete the app and reinstall it, or contact support.
                """
                fatalError(errorMessage)
            }
        }
    }()

    // MARK: - Database Reset Helpers

    static func resetDatabaseIfNeeded() {
        // Check if schema version changed (simplified check)
        let userDefaults = UserDefaults.standard
        let currentSchemaVersion = "1.2.0" // Increment when schema changes
        let savedSchemaVersion = userDefaults.string(forKey: "schemaVersion")

        if savedSchemaVersion != currentSchemaVersion {
            print("🔄 Schema version changed from \(savedSchemaVersion ?? "none") to \(currentSchemaVersion)")
            print("🗑️ Resetting database for clean migration...")
            resetDatabase()
            userDefaults.set(currentSchemaVersion, forKey: "schemaVersion")
        }
    }

    static func resetDatabase() {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

        // Delete all SwiftData/CoreData files
        let patterns = [
            "default.store",
            "default.store.sqlite",
            "default.store-wal",
            "default.store-shm",
            ".default.store.sqlite",
            ".default.store-wal",
            ".default.store-shm"
        ]

        for pattern in patterns {
            let url = appSupportURL.appendingPathComponent(pattern)
            try? fileManager.removeItem(at: url)
        }

        // Also try to find and delete any .sqlite files
        if let enumerator = fileManager.enumerator(at: appSupportURL, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "sqlite" || fileURL.pathExtension == "wal" || fileURL.pathExtension == "shm" {
                    try? fileManager.removeItem(at: fileURL)
                    print("🗑️ Deleted: \(fileURL.lastPathComponent)")
                }
            }
        }

        print("✅ Database reset complete")
    }

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
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @State private var isOnboardingComplete = false
    @State private var hasCheckedOnboarding = false
    @State private var isAuthenticating = true
    @State private var authenticationError: String?

    var body: some View {
        Group {
            if isAuthenticating {
                // Show authentication loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                        .scaleEffect(2.0)

                    Text("Connecting securely...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let error = authenticationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
            } else if !hasCheckedOnboarding {
                // Show a loading state while checking onboarding
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
            authenticateAndInitialize()
        }
        .preferredColorScheme(appearanceMode.colorScheme)
    }

    private func authenticateAndInitialize() {
        // Step 1: Authenticate with Cognito demo user
        print("🔐 Starting authentication...")

        CognitoAuthService.shared.authenticateDemo { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Authentication successful")
                    print("   Status: \(CognitoAuthService.shared.statusDescription)")
                    authenticationError = nil
                    isAuthenticating = false

                    // Step 2: Check onboarding status after authentication
                    checkOnboardingStatus()

                case .failure(let error):
                    print("❌ Authentication failed: \(error.localizedDescription)")
                    authenticationError = "Authentication failed. Using demo mode."

                    // Continue anyway for demo purposes
                    // In production, you might want to retry or show an error screen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isAuthenticating = false
                        checkOnboardingStatus()
                    }
                }
            }
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
