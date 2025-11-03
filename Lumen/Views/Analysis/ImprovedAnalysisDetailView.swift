//
//  ImprovedAnalysisDetailView.swift
//  Lumen
//
//  Simplified analysis results focused on actionable insights
//

import SwiftUI

struct ImprovedAnalysisDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let metric: SkinMetric
    @State private var selectedTab = 0

    var topPriorities: [(title: String, description: String, icon: String, color: Color)] {
        var priorities: [(String, String, String, Color)] = []

        if metric.drynessLevel > 45 {
            priorities.append((
                "Hydration",
                "Your skin needs moisture. Use a hydrating serum twice daily.",
                "drop.fill",
                .blue
            ))
        }

        if metric.acneLevel > 35 {
            priorities.append((
                "Clear Skin",
                "Maintain consistent cleansing routine and avoid touching face.",
                "sparkles",
                .orange
            ))
        }

        if metric.pigmentationLevel > 25 {
            priorities.append((
                "Even Tone",
                "Daily SPF 50+ is essential. Consider vitamin C serum.",
                "sun.max.fill",
                .yellow
            ))
        }

        return Array(priorities.prefix(3))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Hero Section
                        HeroSection(metric: metric)

                        // Tabs
                        TabSelector(selectedTab: $selectedTab)
                            .padding(.horizontal, 20)

                        if selectedTab == 0 {
                            // Overview Tab
                            VStack(spacing: 16) {
                                ScoreCard(metric: metric)
                                    .padding(.horizontal, 20)

                                TopPrioritiesSection(priorities: topPriorities)
                                    .padding(.horizontal, 20)

                                DoTodaySection(metric: metric)
                                    .padding(.horizontal, 20)
                            }
                        } else {
                            // Details Tab
                            VStack(spacing: 16) {
                                AllMetricsSection(metric: metric)
                                    .padding(.horizontal, 20)

                                AIInsightsSection(metric: metric)
                                    .padding(.horizontal, 20)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                }
                .background(Color.appBackground)

                // Close Button
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        )
                }
                .padding(20)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Hero Section

struct HeroSection: View {
    let metric: SkinMetric

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background Image
            if let imageData = metric.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 300)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 300)
            }

            // Gradient Overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)

            // Content
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                        Text("Analysis Complete")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Text("Skin Age: \(metric.skinAge)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(formatDate(metric.timestamp))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // Health Score
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 6)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: metric.overallHealth / 100)
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(Int(metric.overallHealth))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("%")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(20)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Tab Selector

struct TabSelector: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            TabButton(title: "Overview", isSelected: selectedTab == 0) {
                withAnimation(.spring()) {
                    selectedTab = 0
                }
            }

            TabButton(title: "Details", isSelected: selectedTab == 1) {
                withAnimation(.spring()) {
                    selectedTab = 1
                }
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.yellow : Color.clear)
                .cornerRadius(12)
        }
    }
}

// MARK: - Score Card

struct ScoreCard: View {
    let metric: SkinMetric

    var healthStatus: (emoji: String, title: String, color: Color) {
        switch metric.overallHealth {
        case 80...:
            return ("😊", "Excellent", .green)
        case 60..<80:
            return ("🙂", "Good", .yellow)
        case 40..<60:
            return ("😐", "Fair", .orange)
        default:
            return ("☹️", "Needs Attention", .red)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(healthStatus.emoji)
                .font(.system(size: 60))

            Text(healthStatus.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(healthStatus.color)

            Text("Your skin health is \(healthStatus.title.lowercased())")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.adaptiveShadow, radius: 10, y: 4)
    }
}

// MARK: - Top Priorities Section

struct TopPrioritiesSection: View {
    let priorities: [(title: String, description: String, icon: String, color: Color)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top 3 Priorities")
                .font(.headline)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                ForEach(Array(priorities.enumerated()), id: \.offset) { index, priority in
                    PriorityCard(
                        number: index + 1,
                        title: priority.title,
                        description: priority.description,
                        icon: priority.icon,
                        color: priority.color
                    )
                }
            }
        }
    }
}

struct PriorityCard: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)

                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(color)
                    Text("\(number)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Do Today Section

struct DoTodaySection: View {
    let metric: SkinMetric

    var actions: [(title: String, icon: String)] {
        var result: [(String, String)] = [
            ("Apply SPF 30+ sunscreen", "sun.max.fill"),
            ("Drink 8 glasses of water", "drop.fill")
        ]

        if metric.drynessLevel > 40 {
            result.append(("Use hydrating serum", "sparkles"))
        }

        if metric.acneLevel > 30 {
            result.append(("Gentle cleansing routine", "facemask.fill"))
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Do This Today")
                .font(.headline)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                ForEach(actions, id: \.title) { action in
                    HStack(spacing: 12) {
                        Image(systemName: "circle")
                            .font(.body)
                            .foregroundColor(.yellow)

                        Image(systemName: action.icon)
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Text(action.title)
                            .font(.body)

                        Spacer()
                    }
                    .padding(12)
                    .background(Color.yellow.opacity(0.05))
                    .cornerRadius(10)
                }
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.adaptiveShadow, radius: 10, y: 4)
    }
}

// MARK: - All Metrics Section

struct AllMetricsSection: View {
    let metric: SkinMetric

    var metrics: [(label: String, value: Int, icon: String, isGood: Bool)] {
        [
            ("Acne", Int(metric.acneLevel), "circle.hexagongrid.fill", metric.acneLevel < 30),
            ("Dryness", Int(metric.drynessLevel), "drop.fill", metric.drynessLevel < 40),
            ("Moisture", Int(metric.moistureLevel), "drop.triangle.fill", metric.moistureLevel > 60),
            ("Pigmentation", Int(metric.pigmentationLevel), "circle.grid.cross.fill", metric.pigmentationLevel < 25)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Metrics")
                .font(.headline)
                .fontWeight(.bold)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(metrics, id: \.label) { metric in
                    MetricBadge(
                        label: metric.label,
                        value: metric.value,
                        icon: metric.icon,
                        isGood: metric.isGood
                    )
                }
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.adaptiveShadow, radius: 10, y: 4)
    }
}

struct MetricBadge: View {
    let label: String
    let value: Int
    let icon: String
    let isGood: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isGood ? .green : .orange)

            Text("\(value)%")
                .font(.title3)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Circle()
                    .fill(isGood ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(isGood ? "Good" : "Watch")
                    .font(.caption2)
                    .foregroundColor(isGood ? .green : .orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - AI Insights Section

struct AIInsightsSection: View {
    let metric: SkinMetric

    var insights: [(icon: String, text: String, color: Color)] {
        [
            ("drop.fill", "Your skin shows signs of dehydration. Increase water intake and use a humidifier.", .blue),
            ("sun.max.fill", "Daily SPF protection is crucial to prevent premature aging.", .yellow),
            ("sparkles", "Consistent routine is key. Results improve with regular care.", .green)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Insights")
                .font(.headline)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                ForEach(insights, id: \.text) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: insight.icon)
                            .font(.title3)
                            .foregroundColor(insight.color)
                            .frame(width: 32)

                        Text(insight.text)
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                    .padding(16)
                    .background(insight.color.opacity(0.05))
                    .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.adaptiveShadow, radius: 10, y: 4)
    }
}

#Preview {
    ImprovedAnalysisDetailView(
        metric: SkinMetric(
            skinAge: 32,
            overallHealth: 68,
            acneLevel: 35,
            drynessLevel: 52,
            moistureLevel: 25,
            pigmentationLevel: 28
        )
    )
}
