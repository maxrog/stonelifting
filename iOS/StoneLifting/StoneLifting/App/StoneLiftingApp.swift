//
//  StoneLiftingApp.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/10/25.
//

import SwiftUI
import SwiftData

// See ROADMAP.md for feature planning and TODOs

@main
struct StoneLiftingApp: App {
    private let networkMonitor = NetworkMonitor.shared
    private let offlineSyncService = OfflineSyncService.shared
    private let googleSignInService = GoogleSignInService.shared
    private let appleSignInService = AppleSignInService.shared
    private let authService = AuthService.shared

    let sharedContainer: ModelContainer = {
        do {
            let schema = Schema([PendingStone.self, CachedStone.self])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }()

    init() {
        StoneCacheService.shared.configure(with: sharedContainer)
        OfflineSyncService.shared.configure(with: sharedContainer)

        // Check Apple Sign In credential state at app launch
        Task { @MainActor in
            if let credentialState = await AppleSignInService.shared.checkCredentialState() {
                switch credentialState {
                case .authorized:
                    break
                case .revoked, .notFound:
                    AuthService.shared.logout()
                case .transferred:
                    break
                @unknown default:
                    break
                }
            }
        }

        // Restore previous Google Sign In session if available and user is not already authenticated
        Task { @MainActor in
            guard !AuthService.shared.isAuthenticated else {
                return
            }

            if let tokens = await GoogleSignInService.shared.restorePreviousSignIn() {
                // Silently authenticate with backend using restored tokens
                _ = await AuthService.shared.loginWithGoogle()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    // Handle Google Sign In OAuth redirects
                    _ = googleSignInService.handleURL(url)
                }
        }
        .modelContainer(sharedContainer)
    }
}
