//
//  ModernAnalysisDetailView.swift
//  Lumen
//
//  Modern, card-based analysis detail view with delete functionality
//

import SwiftUI
import SwiftData

struct ModernAnalysisDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let metric: SkinMetric
    
    @State private var showDeleteAlert = false
    @State private var showFolderSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Close Button
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                VStack(spacing: 16) {
                    // Header Card with Image
                    HeaderCard(metric: metric)

                    // Overall Health Score
                    HealthScoreCard(score: metric.overallHealth, skinAge: metric.skinAge)

                    // Skin Metrics Grid
                    MetricsGridCard(metric: metric)

                    // Folder Info
                    if let folderName = metric.folderName {
                        FolderInfoCard(folderName: folderName, timestamp: metric.timestamp)
                    }

                    // Action Buttons
                    ActionButtonsCard(
                        onSaveToFolder: { showFolderSheet = true },
                        onDelete: { showDeleteAlert = true }
                    )

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color(.systemGroupedBackground))
        .alert("Delete Analysis", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAnalysis()
            }
        } message: {
            Text("Are you sure you want to delete this analysis? This action cannot be undone.")
        }
        .sheet(isPresented: $showFolderSheet) {
            SaveToFolderSheet(metric: metric)
        }
    }
    
    private func deleteAnalysis() {
        modelContext.delete(metric)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error deleting analysis: \(error)")
            // Still dismiss even if save fails
            dismiss()
        }
    }
}

// MARK: - Header Card

struct HeaderCard: View {
    let metric: SkinMetric

    var body: some View {
        VStack(spacing: 0) {
            if let imageData = metric.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 240)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 240)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    )
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

// MARK: - Health Score Card

struct HealthScoreCard: View {
    let score: Double
    let skinAge: Int
    
    private var scoreColor: Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    private var scoreLabel: String {
        switch score {
        case 80...: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        default: return "Needs Care"
        }
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Score Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text("\(Int(score))")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(scoreColor)
                    Text("Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Skin Health")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(scoreLabel)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor)
                }
                
                Divider()
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Skin Age")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(skinAge) years")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

// MARK: - Metrics Grid Card

struct MetricsGridCard: View {
    let metric: SkinMetric
    
    private var metrics: [(label: String, value: Int, icon: String, color: Color)] {
        [
            ("Acne", Int(metric.acneLevel), "sparkles", metric.acneLevel < 30 ? .green : .orange),
            ("Dryness", Int(metric.drynessLevel), "drop.fill", metric.drynessLevel < 40 ? .green : .orange),
            ("Dark Circles", Int(metric.darkCircleLevel), "eye.fill", metric.darkCircleLevel < 30 ? .green : .orange),
            ("Pigmentation", Int(metric.pigmentationLevel), "sun.max.fill", metric.pigmentationLevel < 25 ? .green : .orange)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Skin Metrics")
                .font(.headline)
                .fontWeight(.bold)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(metrics, id: \.label) { item in
                    MetricCell(
                        label: item.label,
                        value: item.value,
                        icon: item.icon,
                        color: item.color
                    )
                }
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

struct MetricCell: View {
    let label: String
    let value: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(value)%")
                .font(.title3)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Folder Info Card

struct FolderInfoCard: View {
    let folderName: String
    let timestamp: Date
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Saved in")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(folderName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(formatDate(timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Action Buttons Card

struct ActionButtonsCard: View {
    let onSaveToFolder: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: onSaveToFolder) {
                HStack {
                    Image(systemName: "folder.badge.plus")
                        .font(.title3)
                    Text("Save to Folder")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(.yellow)
                .padding(16)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
            }
            
            Button(action: onDelete) {
                HStack {
                    Image(systemName: "trash.fill")
                        .font(.title3)
                    Text("Delete Analysis")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .foregroundColor(.red)
                .padding(16)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Save to Folder Sheet

struct SaveToFolderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let metric: SkinMetric
    
    @State private var folderName = ""
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "folder.fill.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                    .padding(.top, 40)
                
                VStack(spacing: 12) {
                    Text("Save Analysis")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Give this analysis a name to organize your results")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                TextField("Folder name (e.g., \"Morning Routine\")", text: $folderName)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                
                Button(action: saveToFolder) {
                    Text("Save")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(folderName.isEmpty ? Color.gray : Color.yellow)
                        .cornerRadius(12)
                }
                .disabled(folderName.isEmpty)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter a folder name")
            }
        }
    }
    
    private func saveToFolder() {
        let trimmed = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showError = true
            return
        }
        
        metric.folderName = trimmed
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    ModernAnalysisDetailView(metric: SkinMetric(
        skinAge: 28,
        overallHealth: 75,
        acneLevel: 25,
        drynessLevel: 35,
        pigmentationLevel: 15,
        darkcircleLevel: 20,
        imageData: nil
    ))
    .modelContainer(for: [SkinMetric.self], inMemory: true)
}

