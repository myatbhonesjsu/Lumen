//
//  OnboardingView.swift
//  Lumen
//
//  AI Skincare Assistant - Onboarding Flow
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isOnboardingComplete: Bool
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)

                    HowItWorksPage()
                        .tag(1)

                    PrivacyPage()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation {
                                currentPage -= 1
                            }
                        }) {
                            Text("Back")
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer()

                    Button(action: {
                        if currentPage < 2 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    }) {
                        HStack {
                            Text(currentPage == 2 ? "Get Started" : "Next")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.yellow)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }

    private func completeOnboarding() {
        let profile = UserProfile(
            hasCompletedOnboarding: true,
            privacySettingsAccepted: true
        )
        modelContext.insert(profile)
        isOnboardingComplete = true
    }
}

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sun.max.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundStyle(.yellow)

            Text("Welcome to Lumen")
                .font(.system(size: 32, weight: .bold))

            Text("Your personal AI skincare assistant")
                .font(.title3)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }
}

struct HowItWorksPage: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("How Lumen Works")
                .font(.system(size: 28, weight: .bold))

            VStack(spacing: 24) {
                FeatureRow(
                    icon: "camera.fill",
                    title: "Capture",
                    description: "Take a clear photo of your face"
                )

                FeatureRow(
                    icon: "sparkles",
                    title: "Analyze",
                    description: "AI analyzes your skin health"
                )

                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Track",
                    description: "Monitor your progress over time"
                )

                FeatureRow(
                    icon: "lightbulb.fill",
                    title: "Recommend",
                    description: "Get personalized skincare tips"
                )
            }

            Spacer()
        }
        .padding()
    }
}

struct PrivacyPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .resizable()
                .frame(width: 80, height: 100)
                .foregroundStyle(.yellow)

            Text("Your Privacy Matters")
                .font(.system(size: 28, weight: .bold))

            VStack(alignment: .leading, spacing: 16) {
                PrivacyPoint(text: "All photos are stored locally on your device")
                PrivacyPoint(text: "No account or login required")
                PrivacyPoint(text: "Your data is never shared with third parties")
                PrivacyPoint(text: "Delete your data anytime")
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.yellow)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
    }
}

struct PrivacyPoint: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.yellow)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
