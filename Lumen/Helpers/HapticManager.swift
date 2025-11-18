//
//  HapticManager.swift
//  Lumen
//
//  Haptic Feedback Manager for improved user experience
//

import UIKit

/// Manager for haptic feedback throughout the app
class HapticManager {

    static let shared = HapticManager()

    private init() {}

    // MARK: - Haptic Feedback Types

    /// Light impact feedback (e.g., for selections, switches)
    func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Medium impact feedback (e.g., for buttons, confirmations)
    func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Heavy impact feedback (e.g., for important actions, errors)
    func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Success notification (e.g., for completed tasks)
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Warning notification (e.g., for warnings, alerts)
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Error notification (e.g., for errors, failures)
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    /// Selection feedback (e.g., for picker wheels, sliders)
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // MARK: - Context-Specific Feedback

    /// Haptic for photo capture
    func photoCapture() {
        heavy()
    }

    /// Haptic for tab selection
    func tabSelection() {
        light()
    }

    /// Haptic for analysis complete
    func analysisComplete() {
        success()
    }

    /// Haptic for checklist item toggle
    func checklistToggle() {
        medium()
    }

    /// Haptic for button press
    func buttonPress() {
        light()
    }
}

// MARK: - SwiftUI Helper

import SwiftUI

extension View {
    /// Add haptic feedback to a view
    func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                let generator = UIImpactFeedbackGenerator(style: style)
                generator.impactOccurred()
            }
        )
    }
}
