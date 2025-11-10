//
//  DailyRoutine.swift
//  Lumen
//
//  Daily skincare routine tracking
//

import Foundation
import SwiftData

@Model
final class DailyRoutine {
    var id: UUID
    var date: Date
    var morningSteps: [String] // Array of completed step IDs
    var eveningSteps: [String] // Array of completed step IDs

    init(date: Date = Date(), morningSteps: [String] = [], eveningSteps: [String] = []) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.morningSteps = morningSteps
        self.eveningSteps = eveningSteps
    }

    var morningCompletion: Int {
        let total = RoutineStep.morningSteps.count
        return total > 0 ? Int((Double(morningSteps.count) / Double(total)) * 100) : 0
    }

    var eveningCompletion: Int {
        let total = RoutineStep.eveningSteps.count
        return total > 0 ? Int((Double(eveningSteps.count) / Double(total)) * 100) : 0
    }

    var totalCompletion: Int {
        let totalSteps = RoutineStep.morningSteps.count + RoutineStep.eveningSteps.count
        let completedSteps = morningSteps.count + eveningSteps.count
        return totalSteps > 0 ? Int((Double(completedSteps) / Double(totalSteps)) * 100) : 0
    }
}

struct RoutineStep: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let time: TimeOfDay

    enum TimeOfDay {
        case morning, evening, both
    }

    static let morningSteps: [RoutineStep] = [
        RoutineStep(id: "am_cleanser", title: "Cleanser", icon: "drop.fill", time: .morning),
        RoutineStep(id: "am_toner", title: "Toner", icon: "sparkles", time: .morning),
        RoutineStep(id: "am_serum", title: "Serum", icon: "eyedropper.full", time: .morning),
        RoutineStep(id: "am_moisturizer", title: "Moisturizer", icon: "cloud.fill", time: .morning),
        RoutineStep(id: "am_sunscreen", title: "Sunscreen", icon: "sun.max.fill", time: .morning)
    ]

    static let eveningSteps: [RoutineStep] = [
        RoutineStep(id: "pm_makeup_remover", title: "Makeup Remover", icon: "wand.and.stars", time: .evening),
        RoutineStep(id: "pm_cleanser", title: "Cleanser", icon: "drop.fill", time: .evening),
        RoutineStep(id: "pm_toner", title: "Toner", icon: "sparkles", time: .evening),
        RoutineStep(id: "pm_serum", title: "Serum", icon: "eyedropper.full", time: .evening),
        RoutineStep(id: "pm_treatment", title: "Treatment", icon: "cross.case.fill", time: .evening),
        RoutineStep(id: "pm_moisturizer", title: "Moisturizer", icon: "cloud.fill", time: .evening)
    ]
}
