//
//  ImprovedOnboardingView.swift
//  Lumen
//
//  Enhanced onboarding with personalization
//

import SwiftUI
import SwiftData

struct ImprovedOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isOnboardingComplete: Bool
    @State private var currentPage = 0
    @State private var selectedConcerns: Set<SkinConcern> = []
    @State private var selectedGoal: SkincareGoal?
    @State private var userName = ""
    @State private var age = ""
    @State private var height = ""
    @State private var weight = ""
    @FocusState private var isInputFocused: Bool

    private var hasValidBodyMetrics: Bool {
        if age.isEmpty && height.isEmpty && weight.isEmpty {
            return true
        }

        let validAge = age.isEmpty || Int(age) != nil
        let validHeight = height.isEmpty || Double(height) != nil
        let validWeight = weight.isEmpty || Double(weight) != nil

        return validAge && validHeight && validWeight
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
                .onTapGesture {
                    isInputFocused = false
                }

            VStack(spacing: 0) {
                // Progress Indicator
                ProgressBar(currentStep: currentPage, totalSteps: 5)
                    .padding(.top, 16)

                TabView(selection: $currentPage) {
                    WelcomePageImproved()
                        .tag(0)

                    NameInputPage(name: $userName, isInputFocused: $isInputFocused)
                        .tag(1)

                    SkinConcernsPage(selectedConcerns: $selectedConcerns)
                        .tag(2)

                    GoalsPage(selectedGoal: $selectedGoal)
                        .tag(3)

                    BodyMetricsPage(age: $age, height: $height, weight: $weight)
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Navigation Controls
                NavigationControls(
                    currentPage: $currentPage,
                    userName: userName,
                    hasSelectedConcerns: !selectedConcerns.isEmpty,
                    hasBodyMetrics: hasValidBodyMetrics,
                    hasSelectedGoal: selectedGoal != nil,
                    isInputFocused: $isInputFocused,
                    onComplete: completeOnboarding
                )
            }
        }
        .onChange(of: currentPage) { _, _ in
            isInputFocused = false
        }
    }

    private func completeOnboarding() {
        // Check if profile already exists
        let fetchDescriptor = FetchDescriptor<UserProfile>()
        let existingProfiles = try? modelContext.fetch(fetchDescriptor)

        let parsedAge = Int(age)
        let parsedHeight = Double(height)
        let parsedWeight = Double(weight)

        if let existingProfile = existingProfiles?.first {
            // Update existing profile
            existingProfile.name = userName.isEmpty ? "User" : userName
            existingProfile.hasCompletedOnboarding = true
            existingProfile.privacySettingsAccepted = true
            existingProfile.age = parsedAge
            existingProfile.height = parsedHeight
            existingProfile.weight = parsedWeight
        } else {
            // Create new profile
            let profile = UserProfile(
                name: userName.isEmpty ? "User" : userName,
                hasCompletedOnboarding: true,
                privacySettingsAccepted: true,
                lastScanDate: nil,
                age: parsedAge,
                height: parsedHeight,
                weight: parsedWeight
            )
            modelContext.insert(profile)
        }

        try? modelContext.save()

        withAnimation(.spring()) {
            isOnboardingComplete = true
        }
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.yellow : Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .animation(.spring(), value: currentStep)
            }
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Welcome Page

struct WelcomePageImproved: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                // Animated circles
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(Color.yellow.opacity(0.2), lineWidth: 2)
                        .frame(width: 120 + CGFloat(index * 40),
                               height: 120 + CGFloat(index * 40))
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }

                Image(systemName: "sun.max.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.yellow)
            }

            VStack(spacing: 16) {
                Text("Welcome to Lumen")
                    .font(.system(size: 36, weight: .bold))

                Text("Your AI-powered skincare companion")
                    .font(.title3)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                Text("Track your skin health journey with personalized insights and recommendations")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Name Input Page

struct NameInputPage: View {
    @Binding var name: String
    @FocusState.Binding var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.yellow)

                Text("What should we call you?")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Personalize your experience")
                    .font(.body)
                    .foregroundColor(.gray)
            }

            VStack(spacing: 12) {
                TextField("Your name", text: $name)
                    .accessibilityIdentifier("onboarding.nameField")
                    .font(.title3)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .focused($isInputFocused)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 48)
                    .submitLabel(.done)
                    .onSubmit {
                        isInputFocused = false
                    }

                Text("We'll use this to make Lumen feel more personal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            isInputFocused = false
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }
    }
}

// MARK: - Body Metrics Page

struct BodyMetricsPage: View {
    @Binding var age: String
    @Binding var height: String
    @Binding var weight: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "figure.wave")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)

                Text("Tell us about you (Optional)")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Age, height, and weight help personalize insights. You can update this anytime.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 16) {
                TextField("Age (years)", text: $age)
                    .accessibilityIdentifier("metrics.age")
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)

                TextField("Height (cm)", text: $height)
                    .accessibilityIdentifier("metrics.height")
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)

                TextField("Weight (kg)", text: $weight)
                    .accessibilityIdentifier("metrics.weight")
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Skin Concerns Page

struct SkinConcernsPage: View {
    @Binding var selectedConcerns: Set<SkinConcern>

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 60))
                        .foregroundStyle(.yellow)

                    Text("What are your skin concerns?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Select all that apply")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .padding(.top, 32)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(SkinConcern.allCases, id: \.self) { concern in
                        ConcernCard(
                            concern: concern,
                            isSelected: selectedConcerns.contains(concern)
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                if selectedConcerns.contains(concern) {
                                    selectedConcerns.remove(concern)
                                } else {
                                    selectedConcerns.insert(concern)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 100)
            }
        }
    }
}

struct ConcernCard: View {
    let concern: SkinConcern
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: concern.icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .yellow : .gray)
                }

                Text(concern.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.yellow.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.yellow : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .accessibilityIdentifier("concern.\(concern.rawValue)")
        .buttonStyle(.plain)
    }
}

// MARK: - Goals Page

struct GoalsPage: View {
    @Binding var selectedGoal: SkincareGoal?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 60))
                        .foregroundStyle(.yellow)

                    Text("What's your main goal?")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("We'll tailor your experience to help you achieve it")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 32)

                VStack(spacing: 12) {
                    ForEach(SkincareGoal.allCases, id: \.self) { goal in
                        GoalCard(
                            goal: goal,
                            isSelected: selectedGoal == goal
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedGoal = goal
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 100)
            }
        }
    }
}

struct GoalCard: View {
    let goal: SkincareGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 50, height: 50)

                    Image(systemName: goal.icon)
                        .font(.title3)
                        .foregroundColor(isSelected ? .yellow : .gray)
                }

                Text(goal.rawValue)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                }
            }
            .padding(16)
            .background(isSelected ? Color.yellow.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.yellow : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .accessibilityIdentifier("goal.\(goal.rawValue)")
        .buttonStyle(.plain)
    }
}

// MARK: - Navigation Controls

struct NavigationControls: View {
    @Binding var currentPage: Int
    let userName: String
    let hasSelectedConcerns: Bool
    let hasBodyMetrics: Bool
    let hasSelectedGoal: Bool
    @FocusState.Binding var isInputFocused: Bool
    let onComplete: () -> Void

    var canProceed: Bool {
        switch currentPage {
        case 0: return true
        case 1: return !userName.isEmpty
        case 2: return hasSelectedConcerns
        case 3: return hasSelectedGoal
        case 4: return hasBodyMetrics
        default: return false
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            if currentPage > 0 {
                Button(action: {
                    isInputFocused = false
                    withAnimation { currentPage -= 1 }
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .accessibilityIdentifier("nav.back")
            }

            Spacer()

            Button(action: {
                isInputFocused = false
                if currentPage < 4 {
                    withAnimation { currentPage += 1 }
                } else {
                    onComplete()
                }
            }) {
                HStack {
                    Text(currentPage == 4 ? "Get Started" : "Next")
                        .fontWeight(.semibold)
                    if currentPage < 4 {
                        Image(systemName: "chevron.right")
                    }
                }
                .foregroundColor(canProceed ? .white : .gray)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(canProceed ? Color.yellow : Color.gray.opacity(0.3))
                .cornerRadius(12)
            }
            .accessibilityIdentifier(currentPage == 4 ? "nav.getStarted" : "nav.next")
            .disabled(!canProceed)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}

#Preview {
    ImprovedOnboardingView(isOnboardingComplete: .constant(false))
        .modelContainer(for: UserProfile.self, inMemory: true)
}
