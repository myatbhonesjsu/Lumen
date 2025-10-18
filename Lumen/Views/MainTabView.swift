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
                HomeView()
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
                selectedTab = 0
            }

            TabBarButton(
                icon: "calendar",
                title: "Plan",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }

            // Center Camera Button
            Button(action: { showCamera = true }) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 60, height: 60)

                    Image(systemName: "camera.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            .offset(y: -20)
            .frame(maxWidth: .infinity)

            TabBarButton(
                icon: "book.fill",
                title: "Learn",
                isSelected: selectedTab == 3
            ) {
                selectedTab = 3
            }

            TabBarButton(
                icon: "gearshape.fill",
                title: "Settings",
                isSelected: selectedTab == 4
            ) {
                selectedTab = 4
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            Color.white
                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
                .ignoresSafeArea()
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
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .yellow : .gray)

                Text(title)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .yellow : .gray)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    MainTabView()
}
