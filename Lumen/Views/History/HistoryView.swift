//
//  HistoryView.swift
//  Lumen
//
//  AI Skincare Assistant - Skin History Timeline
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SkinMetric.timestamp, order: .reverse) private var skinMetrics: [SkinMetric]
    @State private var selectedMetric: SkinMetric?
    @State private var showDetail = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if skinMetrics.isEmpty {
                    EmptyHistoryView()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Overview Card
                            OverviewCard(metrics: skinMetrics)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)

                            // Timeline
                            VStack(alignment: .leading, spacing: 16) {
                                Text("History")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 20)

                                LazyVStack(spacing: 16) {
                                    ForEach(skinMetrics) { metric in
                                        HistoryCard(metric: metric)
                                            .onTapGesture {
                                                selectedMetric = metric
                                                showDetail = true
                                            }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }

                            Spacer(minLength: 100)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .sheet(isPresented: $showDetail) {
                if let metric = selectedMetric {
                    ImprovedAnalysisDetailView(metric: metric)
                }
            }
        }
    }
}

struct OverviewCard: View {
    let metrics: [SkinMetric]

    var averageHealth: Double {
        guard !metrics.isEmpty else { return 0 }
        return metrics.map { $0.overallHealth }.reduce(0, +) / Double(metrics.count)
    }

    var trend: String {
        guard metrics.count >= 2 else { return "neutral" }
        let latest = metrics[0].overallHealth
        let previous = metrics[1].overallHealth
        if latest > previous + 5 {
            return "improving"
        } else if latest < previous - 5 {
            return "declining"
        }
        return "stable"
    }

    var trendColor: Color {
        switch trend {
        case "improving": return .green
        case "declining": return .red
        default: return .gray
        }
    }

    var trendIcon: String {
        switch trend {
        case "improving": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Average Health")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Text("\(Int(averageHealth))%")
                        .font(.system(size: 36, weight: .bold))

                    HStack(spacing: 6) {
                        Image(systemName: trendIcon)
                            .font(.caption)
                        Text(trend.capitalized)
                            .font(.caption)
                    }
                    .foregroundColor(trendColor)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: averageHealth / 100)
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                }
            }

            HStack(spacing: 20) {
                StatItem(title: "Total Scans", value: "\(metrics.count)")
                Divider()
                    .frame(height: 40)
                StatItem(title: "This Month", value: "\(scansThisMonth)")
                Divider()
                    .frame(height: 40)
                StatItem(title: "Avg Age", value: "\(averageSkinAge)")
            }
        }
        .padding(24)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.adaptiveShadow, radius: 10, y: 4)
    }

    var scansThisMonth: Int {
        let calendar = Calendar.current
        let thisMonth = calendar.component(.month, from: Date())
        return metrics.filter { calendar.component(.month, from: $0.timestamp) == thisMonth }.count
    }

    var averageSkinAge: Int {
        guard !metrics.isEmpty else { return 0 }
        return metrics.map { $0.skinAge }.reduce(0, +) / metrics.count
    }
}

struct StatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HistoryCard: View {
    let metric: SkinMetric

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            if let imageData = metric.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }

            // Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(formatDate(metric.timestamp))
                        .font(.headline)
                    Spacer()
                    Text("\(Int(metric.overallHealth))%")
                        .font(.headline)
                        .foregroundColor(.yellow)
                }

                HStack(spacing: 16) {
                    Label("\(metric.skinAge)", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Label("Skin Age", systemImage: "face.smiling")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // Mini metrics
                HStack(spacing: 12) {
                    MiniMetric(label: "Acne", value: Int(metric.acneLevel))
                    MiniMetric(label: "Dry", value: Int(metric.drynessLevel))
                    MiniMetric(label: "Moist", value: Int(metric.moistureLevel))
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.adaptiveShadow, radius: 5, y: 2)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

struct MiniMetric: View {
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(value > 50 ? Color.red : Color.green)
                .frame(width: 6, height: 6)
            Text("\(label) \(value)%")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(.gray)

            Text("No History Yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Your skin analysis history will appear here")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: SkinMetric.self, inMemory: true)
}
