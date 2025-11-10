//
//  UserProfile.swift
//  Lumen
//
//  AI Skincare Assistant - User Profile
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var hasCompletedOnboarding: Bool
    var scanRemindersEnabled: Bool
    var privacySettingsAccepted: Bool
    var lastScanDate: Date?
    var age: Int?
    var height: Double?
    var weight: Double?

    init(
        id: UUID = UUID(),
        name: String = "User",
        hasCompletedOnboarding: Bool = false,
        scanRemindersEnabled: Bool = true,
        privacySettingsAccepted: Bool = false,
        lastScanDate: Date? = nil,
        age: Int? = nil,
        height: Double? = nil,
        weight: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.scanRemindersEnabled = scanRemindersEnabled
        self.privacySettingsAccepted = privacySettingsAccepted
        self.lastScanDate = lastScanDate
        self.age = age
        self.height = height
        self.weight = weight
    }
}
