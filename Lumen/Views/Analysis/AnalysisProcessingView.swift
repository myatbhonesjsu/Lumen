//
//  AnalysisProcessingView.swift
//  Lumen
//
//  Simplified view showing AWS analysis results
//

import SwiftUI
import SwiftData
import Combine

struct AnalysisProcessingView: View {
    @Environment(\.modelContext) private var modelContext

    let image: UIImage
    @Binding var analysisResult: AnalysisResult?
    @Binding var analysisError: Error?
    @Binding var progressMessage: String

    let onDismiss: () -> Void

    @State private var savedMetric: SkinMetric?

    var topConditions: [(String, Double)] {
        guard let result = analysisResult else { return [] }

        // Filter out the primary condition and sort by confidence
        // Using 15% threshold for secondary conditions
        let otherConditions = result.allConditions
            .filter { $0.key != result.condition }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .filter { $0.value >= 0.15 }

        return Array(otherConditions)
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.appBackground, Color.brandYellowBackground(opacity: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header with dismiss button
                HStack {
                    Text("Skin Analysis")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                // Image preview
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                    .padding(.horizontal)

                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        if let error = analysisError {
                            errorView(error: error)
                        } else if let result = analysisResult {
                            resultsView(result: result)
                        } else {
                            loadingView()
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
        }
        .sheet(item: $savedMetric) { metric in
            FolderNamePromptSheet(metric: metric, onComplete: onDismiss)
        }
    }

    // MARK: - Loading View

    @ViewBuilder
    private func loadingView() -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                .scaleEffect(2.0)
                .frame(height: 60)

            VStack(spacing: 8) {
                Text("Analyzing with AI...")
                    .font(.title3)
                    .fontWeight(.semibold)

                if !progressMessage.isEmpty {
                    AnimatedDotsText(baseText: progressMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - Results View

    @ViewBuilder
    private func resultsView(result: AnalysisResult) -> some View {
        VStack(spacing: 24) {
            // Success icon
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: result)

            // Condition detected
            VStack(spacing: 8) {
                Text("Primary Condition")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text(result.condition.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("\(Int(result.confidence * 100))% Confidence")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // AI Summary
            if let summary = result.summary {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                        Text("AI Analysis")
                            .font(.headline)
                    }

                    Text(summary)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            // Recommended Actions for Primary Condition
            if !result.getSolutions(for: result.condition).isEmpty {
                let primarySolutions = result.getSolutions(for: result.condition)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recommended Actions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(Array(primarySolutions.prefix(4).enumerated()), id: \.offset) { index, solution in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1).")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.yellow)
                            
                            Text(solution)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 12)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Other detected conditions with solutions
            if !topConditions.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Other Concerns Detected")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(topConditions, id: \.0) { condition, confidence in
                        secondaryConditionCard(
                            name: condition,
                            confidence: confidence,
                            solutions: result.getSolutions(for: condition)
                        )
                    }
                }
                .padding(.vertical, 8)
            }

            // Product recommendations
            if !result.products.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recommended Products")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(Array(result.products.prefix(3).enumerated()), id: \.offset) { _, product in
                        productCard(product: product)
                    }
                }
            }

            // Save button
            Button(action: {
                saveAnalysis(result: result)
                // Don't call onDismiss() here - let folder prompt handle dismissal
            }) {
                Text("Save Analysis")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.yellow)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }

    // MARK: - Secondary Condition Card
    
    @ViewBuilder
    private func secondaryConditionCard(name: String, confidence: Double, solutions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Condition header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("\(Int(confidence * 100))% detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(.orange.opacity(0.7))
            }
            
            // Solutions
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(solutions.prefix(2).enumerated()), id: \.offset) { index, solution in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text(solution)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func productCard(product: AnalysisResult.Product) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.headline)
                        .lineLimit(2)

                    Text(product.brand)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", product.rating))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text(product.priceRange)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(product.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            if let url = URL(string: product.amazonUrl), url.scheme != nil {
                Button(action: {
                    UIApplication.shared.open(url)
                }) {
                    HStack {
                        Text("View on Amazon")
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                }
                #if DEBUG
                .onAppear {
                    print("[ProductCard] Valid URL: \(url.absoluteString)")
                }
                #endif
            } else {
                Text("URL unavailable: \(product.amazonUrl)")
                    .font(.caption2)
                    .foregroundColor(.red)
                #if DEBUG
                    .onAppear {
                        print("[ProductCard] Invalid URL: '\(product.amazonUrl)'")
                    }
                #endif
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func confidenceColor(for confidence: Double) -> Color {
        if confidence >= 0.7 {
            return .green
        } else if confidence >= 0.5 {
            return .yellow
        } else {
            return .orange
        }
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            VStack(spacing: 8) {
                Text("Analysis Failed")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onDismiss) {
                Text("Try Again")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Save Analysis

    private func saveAnalysis(result: AnalysisResult) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        let metric = SkinMetric(
            skinAge: 30, // Placeholder
            overallHealth: result.confidence * 100,
            acneLevel: result.condition.lowercased().contains("acne") ? 70.0 : 20.0,
            drynessLevel: result.condition.lowercased().contains("dry") ? 70.0 : 30.0,
            moistureLevel: result.confidence * 80,
            pigmentationLevel: result.condition.lowercased().contains("spot") ? 60.0 : 25.0,
            darkcircleLevel: result.condition.lowercased().contains("dark") || result.condition.lowercased().contains("eye") ? 60.0 : 20.0,
            imageData: imageData,
            analysisNotes: buildAnalysisNotes(result: result),
            folderName: nil // Will be set when user names it
        )

        modelContext.insert(metric)
        try? modelContext.save()

        // Using sheet(item:) ensures the metric is available when sheet renders
        savedMetric = metric
    }

    private func buildAnalysisNotes(result: AnalysisResult) -> String {
        var notes = "AWS Skin Analysis\n\n"
        notes += "Detected: \(result.condition)\n"
        notes += "Confidence: \(Int(result.confidence * 100))%\n\n"

        if !result.products.isEmpty {
            notes += "Recommended Products:\n"
            for product in result.products.prefix(5) {
                notes += "• \(product.name) by \(product.brand) (\(product.priceRange))\n"
            }
        }

        return notes
    }
}

// MARK: - Animated Dots Text

struct AnimatedDotsText: View {
    let baseText: String
    @State private var dotCount = 0

    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(baseText + String(repeating: ".", count: dotCount))
            .onReceive(timer) { _ in
                dotCount = (dotCount + 1) % 4
            }
    }
}
