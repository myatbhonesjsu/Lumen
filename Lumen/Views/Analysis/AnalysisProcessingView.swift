//
//  AnalysisProcessingView.swift
//  Lumen
//
//  AI Skincare Assistant - AI Analysis Processing
//

import SwiftUI
import SwiftData

struct AnalysisProcessingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let image: UIImage
    @State private var isAnalyzing = true
    @State private var progress: Double = 0
    @State private var showResults = false
    @State private var analysisComplete = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.appBackground,
                    Color.brandYellowBackground(opacity: 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Image Preview with better styling
                ZStack {
                    // Subtle glow effect
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.yellow.opacity(0.1))
                        .frame(width: 290, height: 360)
                        .blur(radius: 20)

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 280, height: 350)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                }

                VStack(spacing: 16) {
                    if isAnalyzing {
                        // Progress Indicator
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                .frame(width: 60, height: 60)

                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(Color.yellow, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 0.3), value: progress)

                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundStyle(.yellow)
                        }

                        Text("Analyzing your skin with AI...")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("Mock Analysis Mode")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    } else if let error = errorMessage {
                        // Error State
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)

                        Text("Analysis Error")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button(action: {
                            // Retry analysis
                            errorMessage = nil
                            isAnalyzing = true
                            progress = 0
                            startAnalysis()
                        }) {
                            Text("Retry")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.yellow)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                    } else {
                        // Success State
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)

                        Text("Analysis Complete!")
                            .font(.title2)
                            .fontWeight(.bold)

                        Button(action: {
                            showResults = true
                        }) {
                            Text("View Results")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.yellow)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                    }
                }

                Spacer()

                if isAnalyzing {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            startAnalysis()
        }
        .fullScreenCover(isPresented: $showResults) {
            if let metric = createMetricFromAnalysis() {
                AnalysisDetailView(metric: metric)
            }
        }
    }

    private func startAnalysis() {
        // Start progress animation
        startProgressAnimation()

        // Using mock analysis for demonstration
        print("ℹ️ Running mock skin analysis")
        useMockAnalysis()
    }

    private func startProgressAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if self.progress < 0.95 && self.isAnalyzing {
                self.progress += 0.01
            } else if !self.isAnalyzing {
                timer.invalidate()
                self.progress = 1.0
            }
        }
    }

    private func completeAnalysis() {
        progress = 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            HapticManager.shared.analysisComplete()
            withAnimation {
                isAnalyzing = false
                analysisComplete = true
                saveAnalysis()
            }
        }
    }

    private func handleAnalysisError(_ error: Error) {
        progress = 0
        isAnalyzing = false
        errorMessage = error.localizedDescription

        // Retry with mock analysis on error
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("⚠️ Retrying with mock analysis")
            self.useMockAnalysis()
        }
    }

    private func useMockAnalysis() {
        // Mock analysis for demonstration
        isAnalyzing = true
        errorMessage = nil
        progress = 0

        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if self.progress < 1.0 {
                self.progress += 0.02
            } else {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        self.isAnalyzing = false
                        self.analysisComplete = true
                        self.saveMockAnalysis()
                    }
                }
            }
        }
    }

    private func saveAnalysis() {
        saveMockAnalysis()
    }

    private func saveMockAnalysis() {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        let metric = SkinMetric(
            skinAge: Int.random(in: 25...40),
            overallHealth: Double.random(in: 45...78),
            acneLevel: Double.random(in: 20...40),
            drynessLevel: Double.random(in: 40...65),
            moistureLevel: Double.random(in: 10...20),
            pigmentationLevel: Double.random(in: 15...35),
            imageData: imageData,
            analysisNotes: "Mock analysis for demonstration purposes"
        )

        modelContext.insert(metric)
    }

    private func createMetricFromAnalysis() -> SkinMetric? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }

        return SkinMetric(
            skinAge: Int.random(in: 25...40),
            overallHealth: Double.random(in: 45...78),
            acneLevel: Double.random(in: 20...40),
            drynessLevel: Double.random(in: 40...65),
            moistureLevel: Double.random(in: 10...20),
            pigmentationLevel: Double.random(in: 15...35),
            imageData: imageData,
            analysisNotes: "Your skin shows moderate dryness and some minor acne. Consider using a gentle moisturizer and maintaining a consistent skincare routine."
        )
    }
}

#Preview {
    AnalysisProcessingView(image: UIImage(systemName: "person.fill")!)
}
