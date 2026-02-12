//
//  RootView.swift
//  StoneAtlas
//
//  Created by Max Rogers on 7/11/25.
//

import SwiftUI

// MARK: - Root View

/// Root view that manages the app's main navigation flow
/// Decides whether to show authentication or main app based on auth state
struct RootView: View {
    // MARK: - Properties

    private let authService = AuthService.shared

    @State private var isLoading = true
    @State private var needsOnboarding = false

    // MARK: - Body

    var body: some View {
        Group {
            if isLoading {
                // Loading screen while checking authentication
                LoadingView(
                    message: "StoneLifting",
                    style: .splash,
                    icon: "figure.strengthtraining.traditional"
                )
            } else if !authService.isAuthenticated {
                // User is not logged in - show authentication
                AuthenticationView()
            } else if needsOnboarding {
                // User is logged in but needs onboarding
                OnboardingView {
                    needsOnboarding = false
                }
            } else {
                // User is logged in and onboarded - show main app
                MainAppView()
            }
        }
        .onAppear {
            checkInitialAuthState()
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                checkOnboardingStatus()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: needsOnboarding)
    }

    // MARK: - Actions

    /// Check if user needs to complete onboarding
    private func checkOnboardingStatus() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding)
        needsOnboarding = !hasCompletedOnboarding
    }

    /// Check authentication state on app launch
    private func checkInitialAuthState() {
        Task {
            // Small delay for smooth loading transition
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Attempt to refresh user data if token exists
            if authService.isAuthenticated {
                _ = await authService.refreshCurrentUser()

                // Check onboarding status
                await MainActor.run {
                    checkOnboardingStatus()
                }

                // Fetch and cache stones once on app launch
                let stoneService = StoneService.shared

                // Fetch concurrently
                async let userFetch = stoneService.fetchUserStones(shouldCache: false)
                async let publicFetch = stoneService.fetchPublicStones(shouldCache: false)
                let (userSuccess, publicSuccess) = await (userFetch, publicFetch)

                if userSuccess && publicSuccess {
                    try? await StoneCacheService.shared.cacheStonesInBatch([
                        (stoneService.userStones, .userStones),
                        (stoneService.publicStones, .publicStones)
                    ])
                } else if userSuccess {
                    try? await StoneCacheService.shared.cacheStones(stoneService.userStones, category: .userStones)
                } else if publicSuccess {
                    try? await StoneCacheService.shared.cacheStones(stoneService.publicStones, category: .publicStones)
                }
            }

            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Main App View

struct MainAppView: View {
    private let networkMonitor = NetworkMonitor.shared
    private let cacheService = StoneCacheService.shared
    private let stoneService = StoneService.shared

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            if !networkMonitor.isConnected {
                offlineBanner
            }

            TabView {
                StoneListView()
                    .tabItem {
                        Image(systemName: "figure.strengthtraining.traditional")
                        Text("Stones")
                    }

                MapView()
                    .tabItem {
                        Image(systemName: "map")
                        Text("Map")
                    }

                // Profile tab
                ProfileView()
                    .tabItem {
                        Image(systemName: "person.circle")
                        Text("Profile")
                    }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
        }
    }

    // MARK: - Actions

    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        // Detect background → foreground transition
        if oldPhase == .background && newPhase == .active {
            Task {
                _ = await stoneService.refreshIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)

            Text("Offline Mode")
                .font(.caption)
                .fontWeight(.medium)

            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.orange)
    }
}

// MARK: - Preview

#Preview {
    RootView()
}
