//
//  HomeView.swift
//  Lumen
//
//  AI Skincare Assistant - Home Dashboard
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SkinMetric.timestamp, order: .reverse) private var skinMetrics: [SkinMetric]
    @Query private var userProfiles: [UserProfile]
    @State private var showCamera = false
    @State private var showAnalysis = false

    var latestMetric: SkinMetric? {
        skinMetrics.first
    }

    var userName: String {
        userProfiles.first?.name ?? "User"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HeaderSection(userName: userName, latestMetric: latestMetric)

                    // Skin Health Card
                    if let metric = latestMetric {
                        SkinHealthCard(metric: metric, showAnalysis: $showAnalysis)
                    } else {
                        EmptyStateCard(showCamera: $showCamera)
                    }

                    // Daily Routine Card
                    DailyRoutineCard()

                    // For You Section
                    ForYouSection()

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showCamera) {
                CameraView()
            }
            .sheet(isPresented: $showAnalysis) {
                if let metric = latestMetric {
                    AnalysisDetailView(metric: metric)
                }
            }
        }
    }
}

struct HeaderSection: View {
    let userName: String
    let latestMetric: SkinMetric?

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                if let metric = latestMetric, let imageData = metric.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let metric = latestMetric {
                        Text("\(Int(metric.overallHealth))%")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text("Skin Health")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            HStack(spacing: 16) {
                Button(action: {}) {
                    Image(systemName: "bell.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                }

                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.top, 8)
    }
}

struct SkinHealthCard: View {
    let metric: SkinMetric
    @Binding var showAnalysis: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hello \(userName)")
                        .font(.title2)
                    Text("Your skin journey start here!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Skin Health")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Text("\(Int(metric.overallHealth))%")
                        .font(.system(size: 48, weight: .bold))

                    Text("Last scan: \(formatRelativeDate(metric.timestamp))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: metric.overallHealth / 100)
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "face.smiling.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.yellow)
                }
            }

            Button(action: { showAnalysis = true }) {
                HStack {
                    Text("Read more")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.gray)
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }

    private var userName: String {
        "User" // Could be fetched from UserProfile
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 {
            return "today"
        } else if days == 1 {
            return "yesterday"
        } else {
            return "\(days) days ago"
        }
    }
}

struct EmptyStateCard: View {
    @Binding var showCamera: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)

            VStack(spacing: 8) {
                Text("Start Your Journey")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Take your first skin analysis photo")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Button(action: { showCamera = true }) {
                Text("Take Photo")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.yellow)
                    .cornerRadius(12)
            }
        }
        .padding(32)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

struct DailyRoutineCard: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                    .frame(width: 44, height: 44)
                    .background(Color.yellow.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(Date.now, format: .dateTime.day().month())
                    Text("Daily Routine")
                        .font(.headline)
                }

                Spacer()

                NavigationLink(destination: LearningHubView()) {
                    HStack {
                        Text("Read more")
                            .font(.subheadline)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.gray)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

struct ForYouSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("For You")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                NavigationLink(destination: RecommendationsView()) {
                    HStack {
                        Text("Read more")
                            .font(.subheadline)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.gray)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForYouCard(
                        title: "Men's Hoodie",
                        price: "$253",
                        imageName: "tshirt.fill"
                    )

                    ForYouCard(
                        title: "Women's Hoodie",
                        price: "$233",
                        imageName: "tshirt.fill"
                    )
                }
            }
        }
    }
}

struct ForYouCard: View {
    let title: String
    let price: String
    let imageName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 140, height: 140)

                Image(systemName: imageName)
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(price)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 140)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [SkinMetric.self, UserProfile.self], inMemory: true)
}
