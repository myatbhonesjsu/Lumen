//
//  SkinConcern.swift
//  Lumen
//
//  Skin concerns and goals for personalization
//

import Foundation

enum SkinConcern: String, CaseIterable, Codable {
    case acne = "Acne & Breakouts"
    case dryness = "Dryness"
    case oiliness = "Excess Oil"
    case aging = "Fine Lines & Wrinkles"
    case darkSpots = "Dark Spots"
    case sensitivity = "Sensitivity"
    case redness = "Redness"
    case pores = "Large Pores"

    var icon: String {
        switch self {
        case .acne: return "circle.hexagongrid.fill"
        case .dryness: return "drop.fill"
        case .oiliness: return "drop.triangle.fill"
        case .aging: return "clock.fill"
        case .darkSpots: return "circle.grid.cross.fill"
        case .sensitivity: return "exclamationmark.triangle.fill"
        case .redness: return "flame.fill"
        case .pores: return "circle.grid.2x2.fill"
        }
    }

    var color: String {
        switch self {
        case .acne: return "red"
        case .dryness: return "blue"
        case .oiliness: return "yellow"
        case .aging: return "purple"
        case .darkSpots: return "brown"
        case .sensitivity: return "orange"
        case .redness: return "pink"
        case .pores: return "gray"
        }
    }
}

enum SkincareGoal: String, CaseIterable, Codable {
    case clearerSkin = "Clearer Skin"
    case hydration = "Better Hydration"
    case antiAging = "Anti-Aging"
    case evenTone = "Even Skin Tone"
    case reduceOil = "Control Oil"
    case calmSkin = "Calm Sensitivity"

    var icon: String {
        switch self {
        case .clearerSkin: return "sparkles"
        case .hydration: return "drop.fill"
        case .antiAging: return "hourglass"
        case .evenTone: return "circle.hexagonpath.fill"
        case .reduceOil: return "sun.max.fill"
        case .calmSkin: return "leaf.fill"
        }
    }
}
