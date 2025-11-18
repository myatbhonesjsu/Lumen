//
//  ProgressTrackingService.swift
//  Lumen
//
//  Scientific progress tracking based on skin metrics over time
//

import Foundation
import SwiftData

struct ProgressTrackingService {
    
    // MARK: - Skin Age Progress
    
    /// Calculate skin age trend over time (scientific approach)
    static func calculateSkinAgeTrend(metrics: [SkinMetric]) -> SkinAgeTrend {
        guard metrics.count >= 2 else {
            return SkinAgeTrend(trend: .insufficient, change: 0, message: "Need more data")
        }
        
        let sorted = metrics.sorted { $0.timestamp < $1.timestamp }
        guard let oldest = sorted.first, let newest = sorted.last else {
            return SkinAgeTrend(trend: .insufficient, change: 0, message: "Invalid data")
        }
        
        let ageChange = newest.skinAge - oldest.skinAge
        let daysBetween = max(0, Calendar.current.dateComponents([.day], from: oldest.timestamp, to: newest.timestamp).day ?? 0)
        
        guard daysBetween > 0 else {
            return SkinAgeTrend(trend: .stable, change: ageChange, message: "Same day")
        }
        
        // Calculate rate of change (years per month)
        let monthsBetween = Double(daysBetween) / 30.0
        guard monthsBetween > 0 else {
            return SkinAgeTrend(trend: .stable, change: ageChange, message: "Recent analysis")
        }
        
        let ratePerMonth = Double(ageChange) / monthsBetween
        
        let trend: TrendDirection
        let message: String
        
        if ratePerMonth < -0.5 {
            trend = .improving
            message = "Improving! Skin age decreased by \(abs(ageChange)) years"
        } else if ratePerMonth > 0.5 {
            trend = .declining
            message = "Needs attention. Skin age increased by \(ageChange) years"
        } else {
            trend = .stable
            message = "Stable. Maintaining current skin age"
        }
        
        return SkinAgeTrend(trend: trend, change: ageChange, message: message)
    }
    
    // MARK: - Overall Health Progress
    
    /// Calculate overall health improvement percentage
    static func calculateHealthProgress(metrics: [SkinMetric]) -> HealthProgress {
        guard metrics.count >= 2 else {
            return HealthProgress(percentChange: 0, isImproving: false, message: "Need more data")
        }
        
        let sorted = metrics.sorted { $0.timestamp < $1.timestamp }
        guard let oldest = sorted.first, let newest = sorted.last else {
            return HealthProgress(percentChange: 0, isImproving: false, message: "Invalid data")
        }
        
        let change = newest.overallHealth - oldest.overallHealth
        let oldHealth = max(oldest.overallHealth, 1.0) // Prevent division by zero
        let percentChange = (change / oldHealth) * 100
        
        let message: String
        if change > 5 {
            message = "Great progress! Health improved by \(Int(change))%"
        } else if change < -5 {
            message = "Health declined by \(Int(abs(change)))%. Review your routine"
        } else {
            message = "Health stable at \(Int(newest.overallHealth))%"
        }
        
        return HealthProgress(
            percentChange: percentChange,
            isImproving: change > 0,
            message: message
        )
    }
    
    // MARK: - Metric-Specific Progress
    
    /// Track progress for specific concerns (acne, dryness, etc.)
    static func calculateMetricProgress(
        metrics: [SkinMetric],
        keyPath: KeyPath<SkinMetric, Double>
    ) -> MetricProgress {
        guard metrics.count >= 2 else {
            return MetricProgress(change: 0, isImproving: false)
        }
        
        let sorted = metrics.sorted { $0.timestamp < $1.timestamp }
        let oldest = sorted.first!
        let newest = sorted.last!
        
        let oldValue = oldest[keyPath: keyPath]
        let newValue = newest[keyPath: keyPath]
        let change = newValue - oldValue
        
        // For concerns, lower is better
        return MetricProgress(change: change, isImproving: change < 0)
    }
    
    // MARK: - Folder Statistics
    
    /// Get statistics for a specific folder
    static func getFolderStats(metrics: [SkinMetric], folderName: String) -> FolderStats {
        let folderMetrics = metrics.filter { $0.folderName == folderName }
        
        guard !folderMetrics.isEmpty else {
            return FolderStats(count: 0, avgHealth: 0, avgSkinAge: 0, latestDate: nil)
        }
        
        let avgHealth = folderMetrics.map { $0.overallHealth }.reduce(0, +) / Double(folderMetrics.count)
        let avgSkinAge = folderMetrics.map { Double($0.skinAge) }.reduce(0, +) / Double(folderMetrics.count)
        let latestDate = folderMetrics.map { $0.timestamp }.max()
        
        return FolderStats(
            count: folderMetrics.count,
            avgHealth: avgHealth,
            avgSkinAge: Int(avgSkinAge),
            latestDate: latestDate
        )
    }
    
    // MARK: - Scientific Skin Age Calculation
    
    /// Calculate biological skin age based on multiple factors
    static func calculateScientificSkinAge(
        chronologicalAge: Int,
        acneLevel: Double,
        drynessLevel: Double,
        pigmentationLevel: Double,
        darkCircleLevel: Double
    ) -> Int {
        var skinAge = Double(chronologicalAge)
        
        // Each concern adds aging factors (based on dermatological research)
        // Acne: +0-3 years depending on severity
        skinAge += (acneLevel / 100.0) * 3.0
        
        // Dryness: +0-5 years (dry skin ages faster)
        skinAge += (drynessLevel / 100.0) * 5.0
        
        // Pigmentation: +0-4 years (sun damage indicator)
        skinAge += (pigmentationLevel / 100.0) * 4.0
        
        // Dark circles: +0-2 years (lifestyle/stress indicator)
        skinAge += (darkCircleLevel / 100.0) * 2.0
        
        return Int(skinAge.rounded())
    }
}

// MARK: - Progress Models

struct SkinAgeTrend {
    let trend: TrendDirection
    let change: Int
    let message: String
}

struct HealthProgress {
    let percentChange: Double
    let isImproving: Bool
    let message: String
}

struct MetricProgress {
    let change: Double
    let isImproving: Bool
}

struct FolderStats {
    let count: Int
    let avgHealth: Double
    let avgSkinAge: Int
    let latestDate: Date?
}

enum TrendDirection {
    case improving
    case stable
    case declining
    case insufficient
}

