//
//  SkinMetric.swift
//  Lumen
//
//  AI Skincare Assistant - Skin Health Metrics
//

import Foundation
import SwiftData

@Model
final class SkinMetric {
    var id: UUID
    var timestamp: Date
    var skinAge: Int
    var overallHealth: Double // 0-100%
    var acneLevel: Double // 0-100%
    var drynessLevel: Double // 0-100%
    var moistureLevel: Double // 0-100%
    var pigmentationLevel: Double // 0-100%
    var darkCircleLevel: Double // 0-100%
    var imageData: Data?
    var analysisNotes: String
    var folderName: String? // User-specified folder/collection name

    // Dual Independent Analysis (HuggingFace + Claude)
    var isClaudeValidated: Bool = false  // True if dual analysis was performed
    var claudeConfidence: Double? = nil  // Claude's independent confidence
    var agreesWithPrimary: Bool? = nil   // True if both models agree
    var validationSeverity: String? = nil // Severity from Claude analysis
    var validationInsights: String? = nil // Claude's clinical insights
    var confidenceBoost: Double? = nil   // Confidence boost from consensus

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        skinAge: Int,
        overallHealth: Double,
        acneLevel: Double = 0,
        drynessLevel: Double = 0,
        moistureLevel: Double = 0,
        pigmentationLevel: Double = 0,
        darkcircleLevel: Double = 0,
        imageData: Data? = nil,
        analysisNotes: String = "",
        folderName: String? = nil,
        isClaudeValidated: Bool = false,
        claudeConfidence: Double? = nil,
        agreesWithPrimary: Bool? = nil,
        validationSeverity: String? = nil,
        validationInsights: String? = nil,
        confidenceBoost: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.skinAge = skinAge
        self.overallHealth = overallHealth
        self.acneLevel = acneLevel
        self.drynessLevel = drynessLevel
        self.moistureLevel = moistureLevel
        self.pigmentationLevel = pigmentationLevel
        self.darkCircleLevel = darkcircleLevel
        self.imageData = imageData
        self.analysisNotes = analysisNotes
        self.folderName = folderName
        self.isClaudeValidated = isClaudeValidated
        self.claudeConfidence = claudeConfidence
        self.agreesWithPrimary = agreesWithPrimary
        self.validationSeverity = validationSeverity
        self.validationInsights = validationInsights
        self.confidenceBoost = confidenceBoost
    }
}
