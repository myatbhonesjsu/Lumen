//
//  DailyAIInsightsCard.swift
//  Lumen
//
//  Comprehensive multi-agent AI insights with full analysis details
//

import SwiftUI
import CoreLocation
import Combine
import SwiftData

struct DailyAIInsightsCard: View {
    @StateObject private var locationManager = LocationManager()
    @State private var insight: DailyInsight?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedProductIds: Set<String> = []
    @State private var showProductSubmitSheet = false
    @Binding var learningHubTab: EnhancedLearningHubView.LearningTab?
    @Binding var selectedTab: Int
    @Query(sort: \SkinMetric.timestamp, order: .reverse) private var skinMetrics: [SkinMetric]
    @State private var showCamera = false
    
    var latestMetric: SkinMetric? {
        skinMetrics.first
    }
    
    init(learningHubTab: Binding<EnhancedLearningHubView.LearningTab?> = .constant(nil),
         selectedTab: Binding<Int> = .constant(0)) {
        self._learningHubTab = learningHubTab
        self._selectedTab = selectedTab
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with loading indicator
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.title3)
                            .foregroundColor(.yellow)
                        Text("AI-Powered Insights")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    
                    if let insight = insight {
                        Text(insight.isToday ? "Updated today" : "Updated \(formatDate(insight.generatedAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if isLoading {
                        Text("Generating insights...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Multi-agent analysis")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Content
            if let insight = insight, let metric = latestMetric {
                // Show comprehensive multi-agent insights with analysis data
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Preview Image of Latest Scan - PROMINENT
                        if let imageData = metric.imageData, let uiImage = UIImage(data: imageData) {
                            ScanPreviewSection(
                                image: uiImage,
                                metric: metric
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        }

                        // Latest Analysis Summary
                        AnalysisSummarySection(metric: metric)
                            .padding(.horizontal, 20)

                        // Multi-Agent Insights
                        MultiAgentInsightsSection(
                            insight: insight,
                            metric: metric,
                            showCamera: $showCamera
                        )
                        .padding(.horizontal, 20)

                        // Product Recommendations
                        if let products = insight.recommendedProducts, !products.isEmpty {
                            ProductRecommendationsSection(
                                products: products,
                                selectedProductIds: $selectedProductIds,
                                showProductSubmitSheet: $showProductSubmitSheet
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 20)
                }
            } else if insight != nil {
                // Has insight but no analysis yet
                FirstScanPromptSection(showCamera: $showCamera)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
            } else if isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Analyzing your skin data with AI...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if let error = errorMessage {
                // Error state
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                // Empty state - prompt for first scan
                FirstScanPromptSection(showCamera: $showCamera)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.adaptiveShadow, radius: 10, y: 4)
        .onAppear {
            // Auto-load on appear
            autoRefreshInsight()
        }
        .sheet(isPresented: $showProductSubmitSheet) {
            ProductSubmitSheet(
                selectedProductIds: Array(selectedProductIds),
                insightId: insight?.id ?? "",
                onSubmit: {
                    submitProductApplications()
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AnalysisSaved"))) { _ in
            // Auto-refresh after analysis is saved
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                print("🔄 Auto-refreshing insight after analysis saved")
                autoRefreshInsight()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Auto-refresh when app comes to foreground
            print("🔄 Auto-refreshing insight on app foreground")
            autoRefreshInsight()
        }
        .sheet(isPresented: $showCamera) {
            CameraView()
        }
    }
    
    // MARK: - Auto-Refresh Logic
    
    private func autoRefreshInsight() {
        // ALWAYS generate fresh insight - never load cached/latest
        // This ensures dynamic responses every time
        print("🔄 Auto-refreshing: Generating FRESH insight (not loading cached)")
        
        if locationManager.location != nil {
            generateNewInsight(forceFresh: true)
        } else {
            // Request location and wait a bit, then generate
            locationManager.requestLocation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.locationManager.location != nil {
                    self.generateNewInsight(forceFresh: true)
                } else {
                    // If still no location after waiting, show error
                    self.errorMessage = "Location access required for personalized insights"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func generateNewInsight(forceFresh: Bool = false) {
        guard let location = locationManager.location else {
            errorMessage = "Location access required for personalized insights"
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Add cache-busting timestamp to ensure fresh generation
        let cacheBuster = Date().timeIntervalSince1970
        print("🔄 Generating NEW insight at \(cacheBuster) - forceFresh=\(forceFresh)")
        
        DailyInsightsService.shared.generateDailyInsight(location: location) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let newInsight):
                    print("✅ Received fresh insight: \(newInsight.id)")
                    self.insight = newInsight
                    self.errorMessage = nil
                case .failure(let error):
                    print("❌ Failed to generate insight: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func toggleProductSelection(productId: String) {
        if selectedProductIds.contains(productId) {
            selectedProductIds.remove(productId)
        } else {
            selectedProductIds.insert(productId)
            HapticManager.shared.selection()
        }
    }
    
    private func submitProductApplications() {
        guard !selectedProductIds.isEmpty, let insightId = insight?.id else { return }
        
        DailyInsightsService.shared.submitProductApplications(
            productIds: Array(selectedProductIds),
            insightId: insightId
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    showProductSubmitSheet = false
                    selectedProductIds.removeAll()
                    HapticManager.shared.success()
                    // Auto-refresh to show updated state
                    autoRefreshInsight()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Scan Preview Section

struct ScanPreviewSection: View {
    let image: UIImage
    let metric: SkinMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "photo.fill")
                    .font(.subheadline)
                    .foregroundColor(.yellow)
                Text("Your Latest Scan")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(formatDate(metric.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Large preview image
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    // Overlay with quick stats
                    VStack {
                        Spacer()
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                Text("\(Int(metric.overallHealth))% Health")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                Text("Age \(metric.skinAge)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        }
                        .padding(12)
                    }
                )
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.1), Color.yellow.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Analysis Summary Section

struct AnalysisSummarySection: View {
    let metric: SkinMetric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                Text("Latest Analysis")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(formatDate(metric.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Key Metrics Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricCard(
                    title: "Overall Health",
                    value: "\(Int(metric.overallHealth))%",
                    color: metric.overallHealth > 65 ? .green : metric.overallHealth > 40 ? .orange : .red,
                    icon: "heart.fill"
                )
                
                MetricCard(
                    title: "Skin Age",
                    value: "\(metric.skinAge)",
                    color: .blue,
                    icon: "calendar"
                )
                
                MetricCard(
                    title: "Acne Level",
                    value: "\(Int(metric.acneLevel))%",
                    color: metric.acneLevel < 30 ? .green : metric.acneLevel < 50 ? .orange : .red,
                    icon: "exclamationmark.triangle.fill"
                )
                
                MetricCard(
                    title: "Dryness",
                    value: "\(Int(metric.drynessLevel))%",
                    color: metric.drynessLevel < 40 ? .green : metric.drynessLevel < 60 ? .orange : .red,
                    icon: "drop.fill"
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

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
        .cornerRadius(8)
    }
}

// MARK: - Multi-Agent Insights Section

struct MultiAgentInsightsSection: View {
    let insight: DailyInsight
    let metric: SkinMetric
    @Binding var showCamera: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Personalized Daily Tip
            InsightCard(
                icon: "sparkles",
                iconColor: .yellow,
                title: "Personalized Recommendation",
                content: insight.dailyTip
            )
            
            // Progress Prediction with Analysis Data
            if let prediction = insight.progressPrediction {
                InsightCard(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .green,
                    title: "Progress Outlook",
                    content: prediction
                )
            }
            
            // Environmental Recommendations
            if let envRec = insight.environmentalRecommendation {
                InsightCard(
                    icon: "sun.max.fill",
                    iconColor: .orange,
                    title: "Environmental Alert",
                    content: envRec
                )
            }
        }
    }
}

struct InsightCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [iconColor.opacity(0.1), iconColor.opacity(0.05)],
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

// MARK: - Product Recommendations Section

struct ProductRecommendationsSection: View {
    let products: [DailyInsight.RecommendedProduct]
    @Binding var selectedProductIds: Set<String>
    @Binding var showProductSubmitSheet: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundColor(.purple)
                Text("Recommended Products")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Text("Have you applied any of the following products?")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(products.prefix(2)) { product in
                ProductRecommendationRow(
                    product: product,
                    isSelected: selectedProductIds.contains(product.id),
                    onToggle: {
                        if selectedProductIds.contains(product.id) {
                            selectedProductIds.remove(product.id)
                        } else {
                            selectedProductIds.insert(product.id)
                            HapticManager.shared.selection()
                        }
                    }
                )
            }
            
            if !selectedProductIds.isEmpty {
                Button(action: {
                    showProductSubmitSheet = true
                }) {
                    HStack {
                        Text("Submit Applications")
                            .fontWeight(.semibold)
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - First Scan Prompt Section

struct FirstScanPromptSection: View {
    @Binding var showCamera: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow.opacity(0.7))
            
            Text("Take Your First Scan")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Get personalized AI insights based on your unique skin analysis")
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

// MARK: - Product Recommendation Row

struct ProductRecommendationRow: View {
    let product: DailyInsight.RecommendedProduct
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .purple : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(product.brand)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let description = product.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if let priceRange = product.priceRange {
                    Text(priceRange)
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.purple.opacity(0.1) : Color.cardBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Product Submit Sheet

struct ProductSubmitSheet: View {
    let selectedProductIds: [String]
    let insightId: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Confirm Product Applications")
                    .font(.headline)
                    .padding(.top)
                
                Text("You've selected \(selectedProductIds.count) product\(selectedProductIds.count == 1 ? "" : "s") to mark as applied.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    onSubmit()
                    dismiss()
                }) {
                    Text("Submit")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Product Applications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        requestLocation()
    }
    
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            self?.location = locations.first
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

#Preview {
    DailyAIInsightsCard()
        .padding()
}
