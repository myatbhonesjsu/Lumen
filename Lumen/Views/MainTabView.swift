//
//  MainTabView.swift
//  Lumen
//
//  AI Skincare Assistant - Main Tab Navigation
//

import SwiftUI

private struct TabBarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MainTabView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @State private var selectedTab = 0
    @State private var showCamera = false
    @State private var tabBarHeight: CGFloat = 0
    @State private var learningHubTab: EnhancedLearningHubView.LearningTab? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                TabView(selection: $selectedTab) {
                    ImprovedHomeView(
                        selectedTab: $selectedTab,
                        learningHubTab: $learningHubTab
                    )
                    .tag(0)
                    HistoryView()
                        .tag(1)
                    Color.clear
                        .tag(2)
                    EnhancedLearningHubView(
                        selectedMainTab: $selectedTab,
                        tabBarHeight: tabBarHeight,
                        requestedTab: $learningHubTab
                    )
                    .tag(3)
                    SettingsView()
                        .tag(4)
                }
                .onChange(of: selectedTab) { oldValue, newValue in
                    // Reset learning hub tab when navigating away
                    if oldValue == 3 && newValue != 3 {
                        learningHubTab = nil
                    }
                }
                .toolbar(selectedTab == 3 ? .hidden : .visible, for: .tabBar)
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CustomTabBar(
                    selectedTab: $selectedTab,
                    showCamera: $showCamera,
                    includeCamera: selectedTab != 3
                )
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: TabBarHeightPreferenceKey.self, value: proxy.size.height)
                    }
                )
            }
            .sheet(isPresented: $showCamera) {
                CameraView()
            }
            .onPreferenceChange(TabBarHeightPreferenceKey.self) { height in
                tabBarHeight = height
            }
            .preferredColorScheme(appearanceMode.colorScheme)
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showCamera: Bool
    var includeCamera: Bool

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

            if includeCamera {
                // Center Camera Button
                Button(action: {
                    HapticManager.shared.medium()
                    showCamera = true
                }) {
                    ZStack {
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
            }

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
