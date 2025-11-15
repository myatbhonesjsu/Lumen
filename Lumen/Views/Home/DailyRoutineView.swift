//
//  DailyRoutineView.swift
//  Lumen
//
//  Daily skincare routine tracker with AI personalization
//

import SwiftUI
import SwiftData

struct DailyRoutineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var routines: [DailyRoutine]
    @Query private var skinMetrics: [SkinMetric]
    @Query private var personalizedRoutines: [PersonalizedRoutine]
    @Query private var userProfiles: [UserProfile]

    @State private var selectedTab = 0 // 0 = Morning, 1 = Evening
    @State private var isGeneratingRoutine = false
    @State private var showRoutineInfo = false
    @State private var errorMessage: String?

    private var todayRoutine: DailyRoutine {
        let today = Calendar.current.startOfDay(for: Date())
        if let routine = routines.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }) {
            return routine
        } else {
            let newRoutine = DailyRoutine(date: today)
            modelContext.insert(newRoutine)
            try? modelContext.save()
            return newRoutine
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Time of Day", selection: $selectedTab) {
                    Text("Morning").tag(0)
                    Text("Evening").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                // Progress Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                            .frame(width: 120, height: 120)

                        Circle()
                            .trim(from: 0, to: CGFloat(currentProgress) / 100)
                            .stroke(Color.yellow, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(), value: currentProgress)

                        VStack(spacing: 4) {
                            Text("\(currentProgress)%")
                                .font(.system(size: 32, weight: .bold))
                            Text("Complete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text(selectedTab == 0 ? "Morning Routine" : "Evening Routine")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("\(completedSteps) of \(totalSteps) steps")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 24)

                Divider()

                // Steps List
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(currentSteps.enumerated()), id: \.offset) { index, step in
                            let stepId = getStepId(from: step)
                            RoutineStepRow(
                                step: step,
                                isCompleted: isStepCompleted(stepId),
                                onToggle: {
                                    toggleStep(stepId)
                                }
                            )
                        }
                    }
                    .padding(20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Daily Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if latestPersonalizedRoutine != nil {
                        Button(action: { showRoutineInfo = true }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.yellow)
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if latestPersonalizedRoutine == nil && !skinMetrics.isEmpty {
                    personalizedRoutineCallToAction
                }
            }
            .sheet(isPresented: $showRoutineInfo) {
                if let routine = latestPersonalizedRoutine {
                    RoutineInfoSheet(routine: routine)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var latestPersonalizedRoutine: PersonalizedRoutine? {
        guard let userId = userProfiles.first?.name else { return nil }
        return personalizedRoutines
            .filter { $0.userId == userId }
            .sorted { $0.generatedAt > $1.generatedAt }
            .first
    }

    private var currentSteps: [Any] {
        // Use personalized routine if available, otherwise fall back to default
        if let personalizedRoutine = latestPersonalizedRoutine {
            return selectedTab == 0 ? personalizedRoutine.morningSteps : personalizedRoutine.eveningSteps
        } else {
            return selectedTab == 0 ? RoutineStep.morningSteps : RoutineStep.eveningSteps
        }
    }

    private var currentProgress: Int {
        selectedTab == 0 ? todayRoutine.morningCompletion : todayRoutine.eveningCompletion
    }

    private var completedSteps: Int {
        selectedTab == 0 ? todayRoutine.morningSteps.count : todayRoutine.eveningSteps.count
    }

    private var totalSteps: Int {
        currentSteps.count
    }

    private func isStepCompleted(_ stepId: String) -> Bool {
        if selectedTab == 0 {
            return todayRoutine.morningSteps.contains(stepId)
        } else {
            return todayRoutine.eveningSteps.contains(stepId)
        }
    }

    private func toggleStep(_ stepId: String) {
        HapticManager.shared.light()

        if selectedTab == 0 {
            if let index = todayRoutine.morningSteps.firstIndex(of: stepId) {
                todayRoutine.morningSteps.remove(at: index)
            } else {
                todayRoutine.morningSteps.append(stepId)
            }
        } else {
            if let index = todayRoutine.eveningSteps.firstIndex(of: stepId) {
                todayRoutine.eveningSteps.remove(at: index)
            } else {
                todayRoutine.eveningSteps.append(stepId)
            }
        }

        try? modelContext.save()
    }

    private func getStepId(from step: Any) -> String {
        if let routineStep = step as? RoutineStep {
            return routineStep.id
        } else if let routineStepData = step as? RoutineStepData {
            return routineStepData.id.uuidString
        }
        return ""
    }

    // MARK: - Call to Action View

    private var personalizedRoutineCallToAction: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.yellow)

                Text("Get Your Personalized Routine")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            Text("Let AI create a custom routine based on your latest skin analysis")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: generatePersonalizedRoutine) {
                if isGeneratingRoutine {
                    ProgressView()
                        .tint(.black)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Generate Routine")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .controlSize(.large)
            .disabled(isGeneratingRoutine || skinMetrics.isEmpty)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, y: -2)
    }

    // MARK: - Actions

    private func generatePersonalizedRoutine() {
        guard let latestMetric = skinMetrics.sorted(by: { $0.timestamp > $1.timestamp }).first else {
            errorMessage = "No skin analysis found. Please analyze your skin first."
            return
        }

        guard let userId = userProfiles.first?.name else {
            errorMessage = "User profile not found"
            return
        }

        isGeneratingRoutine = true
        errorMessage = nil

        Task {
            do {
                let routine = try await RoutineService.shared.generatePersonalizedRoutine(
                    userId: userId,
                    latestMetric: latestMetric,
                    budget: "moderate"
                )

                // Save to SwiftData
                await MainActor.run {
                    RoutineService.shared.saveRoutine(routine, to: modelContext)
                    isGeneratingRoutine = false
                    HapticManager.shared.success()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to generate routine: \(error.localizedDescription)"
                    isGeneratingRoutine = false
                    HapticManager.shared.error()
                }
            }
        }
    }
}

struct RoutineStepRow: View {
    let step: Any
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    // Checkbox
                    ZStack {
                        Circle()
                            .fill(isCompleted ? Color.yellow : Color.gray.opacity(0.1))
                            .frame(width: 28, height: 28)

                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                    }

                    // Icon and Title
                    HStack(spacing: 12) {
                        Image(systemName: stepIcon)
                            .font(.title3)
                            .foregroundColor(isCompleted ? .yellow : .gray)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(stepTitle)
                                .font(.body)
                                .fontWeight(isCompleted ? .semibold : .regular)
                                .foregroundColor(isCompleted ? .primary : .secondary)

                            if let productType = stepProductType {
                                Text(productType)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    // Completion indicator
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                }

                // Show reason for AI-generated steps
                if let reason = stepReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 44)
                }
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCompleted ? Color.yellow.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var stepTitle: String {
        if let routineStep = step as? RoutineStep {
            return routineStep.title
        } else if let routineStepData = step as? RoutineStepData {
            return routineStepData.step
        }
        return ""
    }

    private var stepIcon: String {
        if let routineStep = step as? RoutineStep {
            return routineStep.icon
        } else if let routineStepData = step as? RoutineStepData {
            return routineStepData.icon
        }
        return "drop.fill"
    }

    private var stepProductType: String? {
        if let routineStepData = step as? RoutineStepData {
            return routineStepData.productType
        }
        return nil
    }

    private var stepReason: String? {
        if let routineStepData = step as? RoutineStepData {
            return routineStepData.reason
        }
        return nil
    }
}

// MARK: - Routine Info Sheet

struct RoutineInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let routine: PersonalizedRoutine

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Key Concerns
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Skin Concerns")
                            .font(.headline)

                        FlowLayout(spacing: 8) {
                            ForEach(routine.keyConcerns, id: \.self) { concern in
                                Text(concern)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.yellow.opacity(0.2))
                                    .foregroundColor(.yellow)
                                    .cornerRadius(8)
                            }
                        }
                    }

                    Divider()

                    // Overall Strategy
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Routine Strategy")
                            .font(.headline)

                        Text(routine.overallStrategy)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Expected Timeline
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expected Results")
                            .font(.headline)

                        Text(routine.expectedTimeline)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Important Notes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Important Notes")
                            .font(.headline)

                        ForEach(routine.importantNotes, id: \.self) { note in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)

                                Text(note)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Routine Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Flow Layout Helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)

                if x + subviewSize.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, subviewSize.height)
                x += subviewSize.width + spacing
            }

            size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

#Preview {
    DailyRoutineView()
        .modelContainer(for: [DailyRoutine.self, PersonalizedRoutine.self], inMemory: true)
}
