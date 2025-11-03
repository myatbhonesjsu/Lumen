//
//  MainTabView.swift
//  Lumen
//
//  AI Skincare Assistant - Main Tab Navigation
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showCamera = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                ImprovedHomeView()
                    .tag(0)

                HistoryView()
                    .tag(1)

                Color.clear
                    .tag(2)

                LearningHubView()
                    .tag(3)

                SettingsView()
                    .tag(4)
            }

            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab, showCamera: $showCamera)
        }
        .sheet(isPresented: $showCamera) {
            CameraView()
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showCamera: Bool

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "house.fill",
                title: "Home",
                isSelected: selectedTab == 0
            ) {
                HapticManager.shared.tabSelection()
                selectedTab = 0
            }

            TabBarButton(
                icon: "calendar",
                title: "History",
                isSelected: selectedTab == 1
            ) {
                HapticManager.shared.tabSelection()
                selectedTab = 1
            }

            // Center Camera Button
            Button(action: {
                HapticManager.shared.medium()
                showCamera = true
            }) {
                ZStack {
                    // Gradient background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow, Color.yellow.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: .yellow.opacity(0.4), radius: 10, y: 3)

                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .offset(y: -24)
            .frame(maxWidth: .infinity)

            TabBarButton(
                icon: "book.fill",
                title: "Learn",
                isSelected: selectedTab == 3
            ) {
                HapticManager.shared.tabSelection()
                selectedTab = 3
            }

            TabBarButton(
                icon: "gearshape.fill",
                title: "Settings",
                isSelected: selectedTab == 4
            ) {
                HapticManager.shared.tabSelection()
                selectedTab = 4
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            Rectangle()
                .fill(Color.cardBackground)
                .shadow(color: Color.adaptiveShadow, radius: 8, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .yellow : .gray.opacity(0.6))
                    .scaleEffect(isSelected ? 1.1 : 1.0)

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .yellow : .gray.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    MainTabView()
}
