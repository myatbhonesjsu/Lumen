//
//  AnalysisDetailView.swift
//  Lumen
//
//  AI Skincare Assistant - Detailed Analysis Results
//

import SwiftUI

struct AnalysisDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let metric: SkinMetric
    @State private var showRecommendations = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Image with Annotations
                    ZStack(alignment: .topTrailing) {
                        if let imageData = metric.imageData,
                           let uiImage = UIImage(data: imageData) {
                            ZStack {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 500)
                                    .clipped()

                                // Skin age overlay
                                VStack {
                                    Spacer()
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Skin Age: \(metric.skinAge)")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                            Text("Based on AI analysis")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.9))
                                        }
                                        Spacer()
                                    }
                                    .padding(20)
                                    .background(
                                        LinearGradient(
                                            colors: [.clear, .black.opacity(0.6)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                }

                                // Annotation points
                                AnnotationPoint(position: CGPoint(x: 0.7, y: 0.3), label: "Pigmentation")
                            }
                        }

                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding()
                    }

                    VStack(spacing: 20) {
                        // Metrics Grid
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                MetricCard(
                                    title: "Acne",
                                    value: Int(metric.acneLevel),
                                    color: metric.acneLevel > 50 ? .red : .green
                                )
                                MetricCard(
                                    title: "Dryness",
                                    value: Int(metric.drynessLevel),
                                    color: metric.drynessLevel > 50 ? .orange : .green
                                )
                                MetricCard(
                                    title: "Moisture",
                                    value: Int(metric.moistureLevel),
                                    color: metric.moistureLevel > 50 ? .green : .orange
                                )
                            }
                        }
                        .padding(.horizontal, 20)

                        // AI Insights
                        VStack(alignment: .leading, spacing: 16) {
                            Text("AI Insights")
                                .font(.title3)
                                .fontWeight(.bold)

                            VStack(alignment: .leading, spacing: 12) {
                                InsightRow(
                                    icon: "drop.fill",
                                    text: "Your skin shows signs of dryness. Stay hydrated and use a moisturizer.",
                                    color: .blue
                                )

                                InsightRow(
                                    icon: "sun.max.fill",
                                    text: "Consider using SPF 30+ sunscreen daily to prevent sun damage.",
                                    color: .yellow
                                )

                                InsightRow(
                                    icon: "face.smiling.fill",
                                    text: "Overall skin health is good. Maintain your current routine!",
                                    color: .green
                                )
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)

                        // View Recommendations Button
                        Button(action: { showRecommendations = true }) {
                            HStack {
                                Text("View Recommendation")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title3)
                            }
                            .foregroundColor(.black)
                            .padding()
                            .background(Color.yellow)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)

                        Spacer(minLength: 40)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showRecommendations) {
                RecommendationsView()
            }
        }
    }
}

struct AnnotationPoint: View {
    let position: CGPoint
    let label: String

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.yellow, lineWidth: 2)
                    )

                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
            }
            .position(
                x: geometry.size.width * position.x,
                y: geometry.size.height * position.y
            )
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 70, height: 70)

                Circle()
                    .trim(from: 0, to: Double(value) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))

                Text("\(value)%")
                    .font(.headline)
                    .fontWeight(.bold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct InsightRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

#Preview {
    AnalysisDetailView(
        metric: SkinMetric(
            skinAge: 36,
            overallHealth: 55,
            acneLevel: 30,
            drynessLevel: 55,
            moistureLevel: 15,
            pigmentationLevel: 25
        )
    )
}
