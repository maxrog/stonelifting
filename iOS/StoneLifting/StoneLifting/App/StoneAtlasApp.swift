//
//  StoneAtlasApp.swift
//  StoneAtlas
//
//  Created by Max Rogers on 7/10/25.
//

import SwiftUI
import SwiftData

// See ROADMAP.md for feature planning and TODOs

@main
struct StoneAtlasApp: App {
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

        // Token refresh and OAuth session restoration
        Task { @MainActor in
            if AuthService.shared.isAuthenticated {
                // User has JWT token - check if it needs refresh
                let refreshed = await AuthService.shared.refreshTokenIfNeeded()
                if !refreshed {
                    // Token expired and couldn't refresh - will be handled by 401 response
                    // User will be prompted to sign in again when they make an API request
                }
            } else {
                // No JWT token - try to restore OAuth session silently
                if let (idToken, accessToken) = await GoogleSignInService.shared.restorePreviousSignIn() {
                    _ = await AuthService.shared.loginWithGoogleTokens(idToken: idToken, accessToken: accessToken)
                }
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
