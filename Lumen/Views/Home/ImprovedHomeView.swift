//
//  ImprovedHomeView.swift
//  Lumen
//
//  Enhanced home dashboard with actionable insights
//

import SwiftUI
import SwiftData

struct ImprovedHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SkinMetric.timestamp, order: .reverse) private var skinMetrics: [SkinMetric]
    @Query private var userProfiles: [UserProfile]
    @State private var showCamera = false
    @State private var showAnalysis = false
    @State private var completedToday: Set<String> = []

    var latestMetric: SkinMetric? {
        skinMetrics.first
    }

    var userName: String {
        userProfiles.first?.name ?? "there"
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Greeting Header
                        GreetingHeader(greeting: greeting, userName: userName)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        // Today's Focus Card
                        TodaysFocusCard(latestMetric: latestMetric)
                            .padding(.horizontal, 20)

                        // Quick Stats
                        if let metric = latestMetric {
                            QuickStatsCard(metric: metric)
                                .padding(.horizontal, 20)
                        }

                        // Daily Checklist
                        DailyChecklistCard(completedItems: $completedToday)
                            .padding(.horizontal, 20)

                        // This Week's Progress
                        if skinMetrics.count >= 2 {
                            WeeklyProgressCard(metrics: Array(skinMetrics.prefix(7)))
                                .padding(.horizontal, 20)
                        }

                        // Quick Actions
                        QuickActionsGrid(showCamera: $showCamera)
                            .padding(.horizontal, 20)

                        // Recent Analysis
                        if let metric = latestMetric {
                            RecentAnalysisCard(metric: metric, showAnalysis: $showAnalysis)
                                .padding(.horizontal, 20)
                        } else {
                            EmptyStateCardImproved(showCamera: $showCamera)
                                .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 16)
                }
                .background(Color(.systemGroupedBackground))

                // Floating Action Button
                FloatingActionButton(showCamera: $showCamera)
                    .padding(24)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCamera) {
                CameraView()
            }
            .sheet(isPresented: $showAnalysis) {
                if let metric = latestMetric {
                    AnalysisDetailView(metric: metric)
                }
            }
        }
    }
}

// MARK: - Greeting Header

struct GreetingHeader: View {
    let greeting: String
    let userName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.title3)
                    .foregroundColor(.gray)

                Text(userName)
                    .font(.system(size: 32, weight: .bold))
            }

            Spacer()

            NavigationLink(destination: SettingsView()) {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    )
            }
        }
    }
}

// MARK: - Today's Focus Card

struct TodaysFocusCard: View {
    let latestMetric: SkinMetric?

    var todaysTip: (icon: String, title: String, description: String) {
        guard let metric = latestMetric else {
            return ("sun.max.fill", "Start Your Journey", "Take your first skin analysis photo today")
        }

        if metric.drynessLevel > 50 {
            return ("drop.fill", "Focus: Hydration", "Your skin needs extra moisture today. Use a hydrating serum.")
        } else if metric.acneLevel > 40 {
            return ("sparkles", "Focus: Clear Skin", "Keep your routine consistent. Avoid touching your face.")
        } else {
            return ("leaf.fill", "Focus: Maintain", "Your skin looks good! Keep up your current routine.")
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.yellow.opacity(0.3), Color.yellow.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)

                Image(systemName: todaysTip.icon)
                    .font(.title2)
                    .foregroundStyle(.yellow)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(todaysTip.title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(todaysTip.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.15), Color.yellow.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: .yellow.opacity(0.1), radius: 10, y: 4)
    }
}

// MARK: - Quick Stats Card

struct QuickStatsCard: View {
    let metric: SkinMetric

    var stats: [(icon: String, label: String, value: String, color: Color)] {
        [
            ("face.smiling.fill", "Health", "\(Int(metric.overallHealth))%",
             metric.overallHealth > 65 ? .green : .orange),
            ("calendar", "Skin Age", "\(metric.skinAge)", .blue),
            ("chart.line.uptrend.xyaxis", "Trend", "Improving", .green)
        ]
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<stats.count, id: \.self) { index in
                VStack(spacing: 8) {
                    Image(systemName: stats[index].icon)
                        .font(.title3)
                        .foregroundColor(stats[index].color)

                    Text(stats[index].value)
                        .font(.title3)
                        .fontWeight(.bold)

                    Text(stats[index].label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                if index < stats.count - 1 {
                    Divider()
                        .frame(height: 50)
                }
            }
        }
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

// MARK: - Daily Checklist Card

struct DailyChecklistCard: View {
    @Binding var completedItems: Set<String>

    let morningRoutine = [
        ("Cleanser", "facemask.fill"),
        ("Toner", "drop.fill"),
        ("Moisturizer", "sparkles"),
        ("Sunscreen", "sun.max.fill")
    ]

    var progress: Double {
        Double(completedItems.count) / Double(morningRoutine.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Morning Routine")
                        .font(.headline)
                        .fontWeight(.bold)

                    Text("\(completedItems.count)/\(morningRoutine.count) completed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Progress Circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 40, height: 40)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
            }

            VStack(spacing: 12) {
                ForEach(morningRoutine, id: \.0) { item in
                    ChecklistItem(
                        title: item.0,
                        icon: item.1,
                        isCompleted: completedItems.contains(item.0)
                    ) {
                        withAnimation(.spring()) {
                            if completedItems.contains(item.0) {
                                completedItems.remove(item.0)
                            } else {
                                completedItems.insert(item.0)
                                // Haptic feedback would go here
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

struct ChecklistItem: View {
    let title: String
    let icon: String
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isCompleted ? .green : .gray.opacity(0.3))

                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(isCompleted ? .secondary : .gray)

                Text(title)
                    .font(.body)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted)

                Spacer()
            }
            .padding(12)
            .background(isCompleted ? Color.green.opacity(0.05) : Color.gray.opacity(0.05))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Weekly Progress Card

struct WeeklyProgressCard: View {
    let metrics: [SkinMetric]

    var weeklyAverage: Double {
        guard !metrics.isEmpty else { return 0 }
        return metrics.map { $0.overallHealth }.reduce(0, +) / Double(metrics.count)
    }

    var trend: String {
        guard metrics.count >= 2 else { return "neutral" }
        let latest = metrics[0].overallHealth
        let previous = metrics[1].overallHealth
        if latest > previous + 3 {
            return "up"
        } else if latest < previous - 3 {
            return "down"
        }
        return "stable"
    }

    var trendColor: Color {
        switch trend {
        case "up": return .green
        case "down": return .red
        default: return .orange
        }
    }

    var trendIcon: String {
        switch trend {
        case "up": return "arrow.up.right"
        case "down": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("This Week")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: trendIcon)
                    Text(trend.capitalized)
                }
                .font(.subheadline)
                .foregroundColor(trendColor)
            }

            HStack(spacing: 12) {
                ForEach(Array(metrics.prefix(7).enumerated()), id: \.offset) { index, metric in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.yellow.opacity(0.3))
                            .frame(width: 32, height: CGFloat(metric.overallHealth) * 1.2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.yellow)
                                    .frame(height: CGFloat(metric.overallHealth) * 1.2),
                                alignment: .bottom
                            )

                        Text(dayLabel(for: index))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }

    private func dayLabel(for index: Int) -> String {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let today = Calendar.current.component(.weekday, from: Date())
        let adjustedIndex = (today - 2 - index + 7) % 7
        return days[adjustedIndex]
    }
}

// MARK: - Quick Actions Grid

struct QuickActionsGrid: View {
    @Binding var showCamera: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.bold)

            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "drop.fill",
                    title: "Water",
                    color: .blue
                ) {
                    // Track water
                }

                QuickActionButton(
                    icon: "note.text",
                    title: "Notes",
                    color: .orange
                ) {
                    // Add note
                }

                QuickActionButton(
                    icon: "chart.bar.fill",
                    title: "Progress",
                    color: .green
                ) {
                    // View progress
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
    }
}

// MARK: - Recent Analysis Card

struct RecentAnalysisCard: View {
    let metric: SkinMetric
    @Binding var showAnalysis: Bool

    var body: some View {
        Button(action: { showAnalysis = true }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Scan")
                        .font(.headline)
                        .fontWeight(.bold)

                    Spacer()

                    Text(formatDate(metric.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 16) {
                    if let imageData = metric.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(Int(metric.overallHealth))%")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Health")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 12) {
                            MiniMetricBadge(label: "Acne", value: Int(metric.acneLevel), isGood: metric.acneLevel < 30)
                            MiniMetricBadge(label: "Dry", value: Int(metric.drynessLevel), isGood: metric.drynessLevel < 40)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct MiniMetricBadge: View {
    let label: String
    let value: Int
    let isGood: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isGood ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text("\(label) \(value)%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Empty State

struct EmptyStateCardImproved: View {
    @Binding var showCamera: Bool

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.yellow)
            }

            VStack(spacing: 8) {
                Text("Ready to start?")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Take your first skin analysis to unlock personalized insights")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button(action: { showCamera = true }) {
                Text("Take Photo")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.yellow)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    @Binding var showCamera: Bool

    var body: some View {
        Button(action: { showCamera = true }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow, Color.yellow.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: .yellow.opacity(0.4), radius: 15, y: 5)

                Image(systemName: "camera.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    ImprovedHomeView()
        .modelContainer(for: [SkinMetric.self, UserProfile.self], inMemory: true)
}
