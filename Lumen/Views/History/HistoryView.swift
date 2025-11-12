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
    @State private var selectedMetricID: UUID?
    @State private var showDetail = false
    @State private var groupByFolder = true
    @State private var refreshID = UUID()

    private var selectedMetric: SkinMetric? {
        guard let id = selectedMetricID else { return nil }
        return skinMetrics.first(where: { $0.id == id })
    }
    
    private var groupedMetrics: [String: [SkinMetric]] {
        guard !skinMetrics.isEmpty else {
            return [:]
        }
        return Dictionary(grouping: skinMetrics) { metric in
            metric.folderName ?? "Unsorted"
        }
    }
    
    private var sortedFolders: [String] {
        guard !groupedMetrics.isEmpty else {
            return []
        }
        return groupedMetrics.keys.sorted { folder1, folder2 in
            guard let metrics1 = groupedMetrics[folder1],
                  let metrics2 = groupedMetrics[folder2],
                  let date1 = metrics1.first?.timestamp,
                  let date2 = metrics2.first?.timestamp else {
                return false
            }
            return date1 > date2
        }
    }

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
                                .id(refreshID)

                            // Timeline
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("History")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    Spacer()
                                    
                                    Button(action: { groupByFolder.toggle() }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: groupByFolder ? "folder.fill" : "list.bullet")
                                            Text(groupByFolder ? "Folders" : "List")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.yellow.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(.horizontal, 20)

                                if groupByFolder {
                                    // Folder-based view
                                    LazyVStack(spacing: 16) {
                                        ForEach(sortedFolders, id: \.self) { folderName in
                                            FolderSection(
                                                folderName: folderName,
                                                metrics: groupedMetrics[folderName] ?? [],
                                                onSelectMetric: { metric in
                                                    selectedMetricID = metric.id
                                                    showDetail = true
                                                },
                                                onDeleteMetric: { metric in
                                                    deleteMetric(metric)
                                                },
                                                onDeleteFolder: {
                                                    deleteFolder(folderName)
                                                }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                } else {
                                    // List view with swipe to delete
                                    LazyVStack(spacing: 16) {
                                        ForEach(skinMetrics) { metric in
                                            HistoryCard(metric: metric)
                                                .onTapGesture {
                                                    selectedMetricID = metric.id
                                                    showDetail = true
                                                }
                                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                    Button(role: .destructive) {
                                                        deleteMetric(metric)
                                                    } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }

                            Spacer(minLength: 100)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .sheet(isPresented: $showDetail) {
                if let id = selectedMetricID,
                   let metric = skinMetrics.first(where: { $0.id == id }) {
                    ModernAnalysisDetailView(metric: metric)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Analysis not found")
                            .font(.headline)
                        Button("Close") {
                            showDetail = false
                        }
                        .padding()
                        .background(Color.yellow)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .onAppear {
                // Force refresh when view appears
                refreshID = UUID()
            }
            .onChange(of: skinMetrics.count) { oldCount, newCount in
                // Force refresh when count changes
                if oldCount != newCount {
                    refreshID = UUID()
                }
            }
        }
    }
    
    private func deleteMetric(_ metric: SkinMetric) {
        modelContext.delete(metric)
        do {
            try modelContext.save()
            // Force UI refresh after deletion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                refreshID = UUID()
            }
        } catch {
            print("Error deleting metric: \(error)")
        }
    }
    
    private func deleteFolder(_ folderName: String) {
        // Handle "Unsorted" specially - these have nil folderName
        let metricsToDelete: [SkinMetric]
        if folderName == "Unsorted" {
            metricsToDelete = skinMetrics.filter { $0.folderName == nil }
        } else {
            metricsToDelete = skinMetrics.filter { $0.folderName == folderName }
        }

        for metric in metricsToDelete {
            modelContext.delete(metric)
        }

        do {
            try modelContext.save()
            // Force UI refresh after deletion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                refreshID = UUID()
            }
        } catch {
            print("Error deleting folder: \(error)")
        }
    }
}

// MARK: - Folder Section

struct FolderSection: View {
    let folderName: String
    let metrics: [SkinMetric]
    let onSelectMetric: (SkinMetric) -> Void
    let onDeleteMetric: (SkinMetric) -> Void
    let onDeleteFolder: () -> Void
    
    @State private var isExpanded = true
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Folder Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .foregroundColor(.yellow)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(folderName)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text("\(metrics.count) analyses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { showDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color.cardBackground)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            // Folder Contents
            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(metrics) { metric in
                        HistoryCard(metric: metric)
                            .onTapGesture {
                                onSelectMetric(metric)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDeleteMetric(metric)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.leading, 20)
            }
        }
        .alert("Delete Folder", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                onDeleteFolder()
            }
        } message: {
            Text("Delete all \(metrics.count) analyses in \"\(folderName)\"? This cannot be undone.")
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
                        .lineLimit(1)
                    Spacer()
                    Text("\(Int(metric.overallHealth))%")
                        .font(.headline)
                        .foregroundColor(.yellow)
                }

                HStack(spacing: 16) {
                    Label("\(metric.skinAge)", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)

                    Label("Skin Age", systemImage: "face.smiling")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
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
