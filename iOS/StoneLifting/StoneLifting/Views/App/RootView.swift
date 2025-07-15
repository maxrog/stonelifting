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
                LoadingView()
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
            // Add small delay for smooth loading transition
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Attempt to refresh user data if token exists
            if authService.isAuthenticated {
                await authService.refreshCurrentUser()
            }

            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Loading View

/// Loading screen shown during app initialization
struct LoadingView: View {

    /// Animation state for the loading indicator
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)

            Text("StoneLifting")
                .font(.title)
                .fontWeight(.bold)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Main App View Placeholder

/// Placeholder for main app view
struct MainAppView: View {

    private let authService = AuthService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Welcome to StoneLifting! 🪨")
                    .font(.title)
                    .fontWeight(.bold)

                if let user = authService.currentUser {
                    Text("Hello, \(user.username)!")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    if let createdAt = user.createdAt {
                        Text("Account created: \(createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button("Logout") {
                    authService.logout()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 20)
            }
            .padding()
            .navigationTitle("StoneLifting")
        }
    }
}

// MARK: - Preview

#Preview {
    RootView()
}
