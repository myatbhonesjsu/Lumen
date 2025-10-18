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

    init(
        id: UUID = UUID(),
        name: String = "User",
        hasCompletedOnboarding: Bool = false,
        scanRemindersEnabled: Bool = true,
        privacySettingsAccepted: Bool = false,
        lastScanDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.scanRemindersEnabled = scanRemindersEnabled
        self.privacySettingsAccepted = privacySettingsAccepted
        self.lastScanDate = lastScanDate
    }
}
