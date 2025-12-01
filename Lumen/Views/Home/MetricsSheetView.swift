//
//  MetricsSheetView.swift
//  Lumen
//
//  Displays backend metrics in a sheet view
//

import SwiftUI
import Charts

struct MetricsSheetView: View {
    let metrics: AWSBackendService.Metrics
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Summary Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        MetricCard(
                            title: "Total Analyses",
                            value: "\(metrics.total_analyses)",
                            icon: "chart.bar.fill",
                            color: .blue
                        )
                        
                        MetricCard(
                            title: "Total Feedback",
                            value: "\(metrics.total_feedback)",
                            icon: "bubble.left.and.bubble.right.fill",
                            color: .green
                        )
                        
                        MetricCard(
                            title: "Thumbs Up",
                            value: "\(metrics.thumbs_up)",
                            icon: "hand.thumbsup.fill",
                            color: .mint
                        )
                        
                        MetricCard(
                            title: "Thumbs Down",
                            value: "\(metrics.thumbs_down)",
                            icon: "hand.thumbsdown.fill",
                            color: .red
                        )
                    }
                    .padding(.horizontal)
                    
                    // Timeseries Chart (if available)
                    if let timeseries = metrics.timeseries, !timeseries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Analysis Trend")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            Chart {
                                ForEach(timeseries.indices, id: \.self) { index in
                                    let point = timeseries[index]
                                    LineMark(
                                        x: .value("Time", index),
                                        y: .value("Count", point.value)
                                    )
                                    .foregroundStyle(.blue.gradient)
                                    
                                    AreaMark(
                                        x: .value("Time", index),
                                        y: .value("Count", point.value)
                                    )
                                    .foregroundStyle(.blue.opacity(0.1))
                                }
                            }
                            .frame(height: 200)
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Feedback Ratio
                    if metrics.total_feedback > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Feedback Sentiment")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            let positiveRatio = Double(metrics.thumbs_up) / Double(metrics.total_feedback)
                            let negativeRatio = Double(metrics.thumbs_down) / Double(metrics.total_feedback)
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Positive")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(positiveRatio * 100))%")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 8)
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.mint)
                                            .frame(width: geometry.size.width * positiveRatio, height: 8)
                                    }
                                }
                                .frame(height: 8)
                                
                                HStack {
                                    Text("Negative")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(negativeRatio * 100))%")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 8)
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.red)
                                            .frame(width: geometry.size.width * negativeRatio, height: 8)
                                    }
                                }
                                .frame(height: 8)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Metric Card Component

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    MetricsSheetView(metrics: AWSBackendService.Metrics(
        total_analyses: 1234,
        total_feedback: 567,
        thumbs_up: 432,
        thumbs_down: 135,
        timeseries: [
            AWSBackendService.TimePoint(timestamp: "2024-01-01", value: 10),
            AWSBackendService.TimePoint(timestamp: "2024-01-02", value: 15),
            AWSBackendService.TimePoint(timestamp: "2024-01-03", value: 12),
            AWSBackendService.TimePoint(timestamp: "2024-01-04", value: 20),
            AWSBackendService.TimePoint(timestamp: "2024-01-05", value: 18)
        ]
    ))
}
