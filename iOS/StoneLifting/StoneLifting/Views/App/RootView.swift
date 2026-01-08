//
//  RootView.swift
//  StoneLifting
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
            } else if authService.isAuthenticated {
                // User is logged in - show main app
                MainAppView()
            } else {
                // User is not logged in - show authentication
                AuthenticationView()
            }
        }
        .onAppear {
            checkInitialAuthState()
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
    }

    // MARK: - Actions

    /// Check authentication state on app launch
    private func checkInitialAuthState() {
        Task {
            // Small delay for smooth loading transition
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Attempt to refresh user data if token exists
            if authService.isAuthenticated {
                _ = await authService.refreshCurrentUser()
            }

            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Main App View

struct MainAppView: View {
    var body: some View {
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
}

// MARK: - Preview

#Preview {
    RootView()
}
