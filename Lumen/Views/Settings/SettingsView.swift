//
//  SettingsView.swift
//  Lumen
//
//  AI Skincare Assistant - Settings & Privacy
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]
    @State private var scanRemindersEnabled = true
    @State private var showDeleteConfirmation = false
    @State private var userName = ""

    var userProfile: UserProfile? {
        userProfiles.first
    }

    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.yellow.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.title2)
                                    .foregroundStyle(.yellow)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Your Name", text: $userName)
                                .font(.headline)

                            Text("Lumen User")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Profile")
                }

                // Preferences Section
                Section {
                    Toggle(isOn: $scanRemindersEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Scan Reminders")
                                    .font(.body)
                                Text("Get notified to take regular scans")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .tint(.yellow)

                    NavigationLink(destination: NotificationSettingsView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.yellow)
                            Text("Reminder Schedule")
                        }
                    }
                } header: {
                    Text("Preferences")
                }

                // Privacy & Data Section
                Section {
                    NavigationLink(destination: PrivacyPolicyView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(.blue)
                            Text("Privacy Policy")
                        }
                    }

                    NavigationLink(destination: DataManagementView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "cylinder.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Data Management")
                                Text("View and manage your stored data")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                    Button(action: { showDeleteConfirmation = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "trash.fill")
                                .foregroundStyle(.red)
                            Text("Delete All Data")
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("Privacy & Data")
                } footer: {
                    Text("All your data is stored locally on your device. No information is shared with third parties.")
                        .font(.caption)
                }

                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }

                    NavigationLink(destination: AboutView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.yellow)
                            Text("About Lumen")
                        }
                    }

                    Link(destination: URL(string: "https://example.com/support")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundStyle(.orange)
                            Text("Help & Support")
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 80)
            }
            .navigationTitle("Settings")
            .onAppear {
                userName = userProfile?.name ?? "User"
                scanRemindersEnabled = userProfile?.scanRemindersEnabled ?? true
            }
            .onChange(of: userName) { _, newValue in
                userProfile?.name = newValue
            }
            .onChange(of: scanRemindersEnabled) { _, newValue in
                userProfile?.scanRemindersEnabled = newValue
            }
            .alert("Delete All Data", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("Are you sure you want to delete all your data? This action cannot be undone.")
            }
        }
    }

    private func deleteAllData() {
        // Delete all skin metrics
        let fetchDescriptor = FetchDescriptor<SkinMetric>()
        if let metrics = try? modelContext.fetch(fetchDescriptor) {
            metrics.forEach { modelContext.delete($0) }
        }

        // Delete all recommendations
        let recFetchDescriptor = FetchDescriptor<Recommendation>()
        if let recommendations = try? modelContext.fetch(recFetchDescriptor) {
            recommendations.forEach { modelContext.delete($0) }
        }

        try? modelContext.save()
    }
}

struct NotificationSettingsView: View {
    @State private var reminderTime = Date()
    @State private var reminderFrequency = "Weekly"

    let frequencies = ["Daily", "Every 3 Days", "Weekly", "Bi-Weekly", "Monthly"]

    var body: some View {
        List {
            Section {
                DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
            } header: {
                Text("Time")
            }

            Section {
                Picker("Frequency", selection: $reminderFrequency) {
                    ForEach(frequencies, id: \.self) { frequency in
                        Text(frequency).tag(frequency)
                    }
                }
                .pickerStyle(.inline)
            } header: {
                Text("Frequency")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 80)
        }
        .navigationTitle("Reminder Schedule")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataManagementView: View {
    @Query private var skinMetrics: [SkinMetric]

    var totalStorageSize: String {
        let totalBytes = skinMetrics.reduce(0) { result, metric in
            result + (metric.imageData?.count ?? 0)
        }
        return ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Total Scans")
                    Spacer()
                    Text("\(skinMetrics.count)")
                        .foregroundColor(.gray)
                }

                HStack {
                    Text("Storage Used")
                    Spacer()
                    Text(totalStorageSize)
                        .foregroundColor(.gray)
                }
            } header: {
                Text("Statistics")
            }

            Section {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Local Storage Only")
                            .font(.headline)
                        Text("All data is stored securely on your device")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 8)

                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No Cloud Sync")
                            .font(.headline)
                        Text("Your photos never leave your device")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Privacy")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 80)
        }
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Last updated: \(Date.now, format: .dateTime.month().day().year())")
                    .font(.caption)
                    .foregroundColor(.gray)

                Divider()

                PrivacySection(
                    title: "Data Collection",
                    content: "Lumen only collects and stores data locally on your device. We do not have access to your photos, analysis results, or any personal information."
                )

                PrivacySection(
                    title: "Photo Storage",
                    content: "All photos you take are stored locally on your device using iOS's secure storage mechanisms. Photos are never uploaded to any server or cloud service."
                )

                PrivacySection(
                    title: "AI Analysis",
                    content: "Skin analysis is performed on-device using local processing. No image data is sent to external servers for analysis."
                )

                PrivacySection(
                    title: "No Third-Party Sharing",
                    content: "We do not share, sell, or transfer your data to any third parties. Your information remains private and under your control."
                )

                PrivacySection(
                    title: "Data Deletion",
                    content: "You can delete all your data at any time from the Settings menu. Once deleted, data cannot be recovered."
                )
            }
            .padding(20)
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacySection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Logo
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.yellow)
                    .padding(.top, 40)

                VStack(spacing: 8) {
                    Text("Lumen")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("AI Skincare Assistant")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Text("Version 1.0.0")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("About")
                        .font(.headline)

                    Text("Lumen is your personal AI-powered skincare assistant. We help you understand your skin better through advanced image analysis and provide personalized recommendations to improve your skin health.")
                        .font(.body)
                        .foregroundColor(.secondary)

                    Text("Our mission is to make professional-grade skin analysis accessible to everyone, while respecting your privacy and keeping your data secure on your device.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)

                Divider()
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    Text("Made with  for healthy skin")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text("© 2025 Lumen. All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 100)

                Spacer()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserProfile.self, SkinMetric.self], inMemory: true)
}
