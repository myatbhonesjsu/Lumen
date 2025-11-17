//
//  ImprovedHomeView.swift
//  Lumen
//
//  Enhanced home dashboard with actionable insights
//

import SwiftUI
import SwiftData

struct ImprovedHomeView: View {
    @Binding var selectedTab: Int
    @Binding var learningHubTab: EnhancedLearningHubView.LearningTab?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SkinMetric.timestamp, order: .reverse) private var skinMetrics: [SkinMetric]
    @Query private var userProfiles: [UserProfile]
    @Query private var routines: [DailyRoutine]
    @State private var showCamera = false
    @State private var showAnalysis = false
    @State private var showRoutine = false
    @State private var completedToday: Set<String> = []

    var latestMetric: SkinMetric? {
        skinMetrics.first
    }

    var userName: String {
        userProfiles.first?.name ?? "User"
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var todayRoutine: DailyRoutine? {
        let today = Calendar.current.startOfDay(for: Date())
        return routines.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Greeting Header
                    GreetingHeader(greeting: greeting, userName: userName)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // Today's Focus Card
                    TodaysFocusCard(
                        latestMetric: latestMetric,
                        todayRoutine: todayRoutine,
                        onTap: { showRoutine = true }
                    )
                    .padding(.horizontal, 20)

                    // Quick Stats
                    if let metric = latestMetric {
                        QuickStatsCard(metric: metric)
                            .padding(.horizontal, 20)
                    }

                    // AI Learning Hub Shortcut
                    AILearningShortcutCard(
                        selectedTab: $selectedTab,
                        learningHubTab: $learningHubTab
                    )
                    .padding(.horizontal, 20)

                    // Progress Tracking
                    if skinMetrics.count >= 2 {
                        ProgressTrackingCard(metrics: Array(skinMetrics.prefix(30)))
                            .padding(.horizontal, 20)
                    }

                    // Skin Analysis Actions
                    SkinAnalysisActionsCard(
                        showCamera: $showCamera,
                        selectedTab: $selectedTab,
                        learningHubTab: $learningHubTab
                    )
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
            .navigationBarHidden(true)
            .sheet(isPresented: $showCamera) {
                CameraView()
            }
            .sheet(isPresented: $showAnalysis) {
                if let metric = latestMetric {
                    ModernAnalysisDetailView(metric: metric)
                }
            }
            .sheet(isPresented: $showRoutine) {
                DailyRoutineView()
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
            .accessibilityIdentifier("home.settings")
        }
    }
}

// MARK: - Today's Focus Card

struct TodaysFocusCard: View {
    let latestMetric: SkinMetric?
    let todayRoutine: DailyRoutine?
    let onTap: () -> Void

    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    private var isEvening: Bool {
        currentHour >= 17
    }

    private var routineCompletion: Int {
        guard let routine = todayRoutine else { return 0 }
        return isEvening ? routine.eveningCompletion : routine.morningCompletion
    }

    private var cardContent: (icon: String, title: String, description: String) {
        if todayRoutine != nil {
            let timeOfDay = isEvening ? "Evening" : "Morning"
            if routineCompletion == 100 {
                return ("checkmark.circle.fill", "\(timeOfDay) Routine Complete!", "Great job! Your skin will thank you.")
            } else if routineCompletion > 0 {
                return ("list.bullet.circle.fill", "\(timeOfDay) Routine: \(routineCompletion)%", "Tap to complete your \(timeOfDay.lowercased()) skincare steps")
            } else {
                return ("sparkles", "Start Your \(timeOfDay) Routine", "Build consistent skincare habits. Tap to begin!")
            }
        } else {
            return ("list.bullet.clipboard.fill", "Track Your Routine", "Start building consistent skincare habits today")
        }
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.light()
            onTap()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.yellow.opacity(0.3), Color.yellow.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 60)

                    if routineCompletion > 0 && routineCompletion < 100 {
                        Circle()
                            .trim(from: 0, to: CGFloat(routineCompletion) / 100)
                            .stroke(Color.yellow, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                    }

                    Image(systemName: cardContent.icon)
                        .font(.title2)
                        .foregroundStyle(.yellow)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(cardContent.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(cardContent.description)
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
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.routine")
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
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.adaptiveShadow, radius: 10, y: 4)
        .accessibilityIdentifier("home.stats")
    }
}

// MARK: - AI Learning Hub Shortcut

struct AILearningShortcutCard: View {
    @Binding var selectedTab: Int
    @Binding var learningHubTab: EnhancedLearningHubView.LearningTab?

    var body: some View {
        Button(action: {
            HapticManager.shared.tabSelection()
            learningHubTab = .chat  // Set to chat tab
            selectedTab = 3  // Navigate to Learning Hub tab
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.yellow.opacity(0.3), Color.yellow.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 60)

                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ask AI Assistant")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Get personalized skincare advice")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(20)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.adaptiveShadow, radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.aiAssistant")
    }
}

// MARK: - Progress Tracking Card

struct ProgressTrackingCard: View {
    let metrics: [SkinMetric]
    
    private var skinAgeTrend: SkinAgeTrend {
        guard !metrics.isEmpty else {
            return SkinAgeTrend(trend: .insufficient, change: 0, message: "No data")
        }
        return ProgressTrackingService.calculateSkinAgeTrend(metrics: metrics)
    }
    
    private var healthProgress: HealthProgress {
        guard !metrics.isEmpty else {
            return HealthProgress(percentChange: 0, isImproving: false, message: "No data")
        }
        return ProgressTrackingService.calculateHealthProgress(metrics: metrics)
    }
    
    private var trendColor: Color {
        switch skinAgeTrend.trend {
        case .improving: return .green
        case .declining: return .red
        case .stable: return .orange
        case .insufficient: return .gray
        }
    }
    
    private var trendIcon: String {
        switch skinAgeTrend.trend {
        case .improving: return "arrow.down.right.circle.fill"
        case .declining: return "arrow.up.right.circle.fill"
        case .stable: return "arrow.right.circle.fill"
        case .insufficient: return "chart.line.flattrend.xyaxis"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress Tracking")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("\(metrics.count) analyses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: trendIcon)
                    Text(skinAgeTrend.trend == .improving ? "Improving" : 
                         skinAgeTrend.trend == .declining ? "Declining" : "Stable")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(trendColor)
            }
            
            Divider()
            
            // Skin Age Trend
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Skin Age")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text("\(metrics.first?.skinAge ?? 0)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if skinAgeTrend.change != 0 {
                            HStack(spacing: 2) {
                                Image(systemName: skinAgeTrend.change < 0 ? "arrow.down" : "arrow.up")
                                    .font(.caption)
                                Text("\(abs(skinAgeTrend.change))")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(skinAgeTrend.change < 0 ? .green : .red)
                        }
                    }
                    
                    Text(skinAgeTrend.message)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Mini chart
                HStack(spacing: 4) {
                    ForEach(Array(metrics.prefix(7).enumerated()), id: \.offset) { index, metric in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.yellow)
                            .frame(width: 6, height: CGFloat(metric.overallHealth) * 0.6)
                            .opacity(index == 0 ? 1.0 : 0.5)
                    }
                }
                .frame(height: 60)
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.adaptiveShadow, radius: 10, y: 4)
        .accessibilityIdentifier("home.progress")
    }
}

// MARK: - Skin Analysis Actions Card

struct SkinAnalysisActionsCard: View {
    @Binding var showCamera: Bool
    @Binding var selectedTab: Int
    @Binding var learningHubTab: EnhancedLearningHubView.LearningTab?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Skin Analysis")
                .font(.headline)
                .fontWeight(.bold)

            HStack(spacing: 12) {
                AnalysisActionButton(
                    id: "home.analyze",
                    icon: "camera.fill",
                    title: "New Scan",
                    subtitle: "Analyze skin",
                    color: .yellow
                ) {
                    HapticManager.shared.light()
                    showCamera = true
                }

                AnalysisActionButton(
                    id: "home.history",
                    icon: "clock.arrow.circlepath",
                    title: "History",
                    subtitle: "Past results",
                    color: .blue
                ) {
                    HapticManager.shared.tabSelection()
                    selectedTab = 1  // Navigate to History tab
                }
            }

            HStack(spacing: 12) {
                AnalysisActionButton(
                    id: "home.chat",
                    icon: "sparkles",
                    title: "AI Chat",
                    subtitle: "Ask questions",
                    color: .purple
                ) {
                    HapticManager.shared.tabSelection()
                    learningHubTab = .chat  // Set to chat tab
                    selectedTab = 3  // Navigate to Learning Hub
                }

                AnalysisActionButton(
                    id: "home.learn",
                    icon: "book.fill",
                    title: "Learn",
                    subtitle: "Read articles",
                    color: .orange
                ) {
                    HapticManager.shared.tabSelection()
                    learningHubTab = .articles  // Set to articles tab
                    selectedTab = 3  // Navigate to Learning Hub
                }
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.adaptiveShadow, radius: 10, y: 4)
    }
}

struct AnalysisActionButton: View {
    let id: String?
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id ?? "")
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recent Scan")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        if let folderName = metric.folderName {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.fill")
                                    .font(.caption2)
                                Text(folderName)
                                    .font(.caption)
                            }
                            .foregroundColor(.yellow)
                        }
                    }

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
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.adaptiveShadow, radius: 10, y: 4)
        }
        // .buttonStyle(.plain)
        .accessibilityIdentifier("home.recent")
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
        .background(Color(.tertiarySystemGroupedBackground))
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
            .accessibilityIdentifier("home.takePhoto")
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.adaptiveShadow, radius: 10, y: 4)
    }
}


#Preview {
    ImprovedHomeView(
        selectedTab: .constant(0),
        learningHubTab: .constant(nil)
    )
    .modelContainer(for: [SkinMetric.self, UserProfile.self, DailyRoutine.self], inMemory: true)
}
