//
//  AgenticInsightsCard.swift
//  Lumen
//
//  Insights card showing Skin Analyst and Routine Coach agent responses
//

import SwiftUI
import SwiftData

struct AgenticInsightsCard: View {
    @Binding var selectedTab: Int
    @Query(sort: \SkinMetric.timestamp, order: .reverse) private var skinMetrics: [SkinMetric]
    @State private var skinAnalystResponse: String?
    @State private var routineCoachResponse: String?
    @State private var isLoadingSkinAnalyst = false
    @State private var isLoadingRoutineCoach = false
    @State private var skinAnalystError: String?
    @State private var routineCoachError: String?
    @State private var showCamera = false

    var latestMetric: SkinMetric? {
        skinMetrics.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.title3)
                            .foregroundColor(.yellow)
                        Text("Insights")
                            .font(.headline)
                            .fontWeight(.bold)
                    }

                    Text("Powered by OpenAI GPT-4o")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 20)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Analysis Based On section
                    if let metric = latestMetric {
                        AnalysisBasedOnSection(metric: metric)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }

                    // Insights section - Skin Analyst
                    InsightsSection(
                        title: "Insights",
                        icon: "chart.xyaxis.line",
                        iconColor: .green,
                        response: $skinAnalystResponse,
                        isLoading: $isLoadingSkinAnalyst,
                        error: $skinAnalystError,
                        agentType: .skinAnalyst
                    )
                    .padding(.horizontal, 20)

                    // Routine Coach section
                    InsightsSection(
                        title: "Routine Coach",
                        icon: "figure.run",
                        iconColor: .purple,
                        response: $routineCoachResponse,
                        isLoading: $isLoadingRoutineCoach,
                        error: $routineCoachError,
                        agentType: .routineCoach
                    )
                    .padding(.horizontal, 20)

                    // First scan prompt if no metrics
                    if latestMetric == nil {
                        FirstScanPromptView(showCamera: $showCamera)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.adaptiveShadow, radius: 10, y: 4)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AnalysisSaved"))) { _ in
            // Auto-update after analysis is saved
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                print("🔄 Analysis saved - fetching agent insights")
                fetchInsights()
            }
        }
        .onAppear {
            // Fetch insights if we have scans but no responses
            if latestMetric != nil && skinAnalystResponse == nil && routineCoachResponse == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    fetchInsights()
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView()
        }
    }

    // MARK: - Fetch Insights

    private func fetchInsights() {
        guard let latestMetric = latestMetric else { return }

        // Fetch Skin Analyst response
        isLoadingSkinAnalyst = true
        skinAnalystError = nil
        AgentChatService.shared.invokeAgent(
            agentType: .skinAnalyst,
            analysisId: latestMetric.id.uuidString
        ) { result in
            DispatchQueue.main.async {
                self.isLoadingSkinAnalyst = false
                switch result {
                case .success(let response):
                    self.skinAnalystResponse = response
                case .failure(let error):
                    self.skinAnalystError = error.localizedDescription
                    print("❌ Skin Analyst error: \(error.localizedDescription)")
                }
            }
        }

        // Fetch Routine Coach response
        isLoadingRoutineCoach = true
        routineCoachError = nil
        AgentChatService.shared.invokeAgent(
            agentType: .routineCoach,
            analysisId: latestMetric.id.uuidString
        ) { result in
            DispatchQueue.main.async {
                self.isLoadingRoutineCoach = false
                switch result {
                case .success(let response):
                    self.routineCoachResponse = response
                case .failure(let error):
                    self.routineCoachError = error.localizedDescription
                    print("❌ Routine Coach error: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Analysis Based On Section

struct AnalysisBasedOnSection: View {
    let metric: SkinMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.yellow)
                Text("Analysis Based On")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(formatDate(metric.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let imageData = metric.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                MetricBadge(icon: "heart.fill", text: "\(Int(metric.overallHealth))%")
                                Spacer()
                                MetricBadge(icon: "drop.fill", text: "\(Int(metric.moistureLevel))%")
                            }
                            .padding(12)
                        }
                    )
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Insights Section

struct InsightsSection: View {
    let title: String
    let icon: String
    let iconColor: Color
    @Binding var response: String?
    @Binding var isLoading: Bool
    @Binding var error: String?
    let agentType: AgentType

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with agent badge
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(iconColor)
                Spacer()
                Image(systemName: "sparkle")
                    .font(.caption2)
                    .foregroundColor(iconColor.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(iconColor.opacity(0.1))
            .cornerRadius(8)

            // Content
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing your skin...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            } else if let error = error {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Error loading insights")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
            } else if let response = response {
                Text(response)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
            } else {
                Text("No insights available. Take a scan to get personalized insights.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 16)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [iconColor.opacity(0.08), iconColor.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(iconColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Metric Badge

struct MetricBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}

// MARK: - First Scan Prompt View

struct FirstScanPromptView: View {
    @Binding var showCamera: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 50))
                .foregroundColor(.yellow.opacity(0.7))

            Text("Take Your First Scan")
                .font(.headline)
                .fontWeight(.bold)

            Text("Once you complete a scan, AI insights will be generated based on your results")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                HapticManager.shared.light()
                showCamera = true
            }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Start Your First Scan")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.yellow, Color.yellow.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

#Preview {
    AgenticInsightsCard(selectedTab: .constant(0))
        .padding()
}
