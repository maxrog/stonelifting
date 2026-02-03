//
//  GoogleSignInService.swift
//  StoneLifting
//
//  Created by Max Rogers on 1/26/26.
//

import Foundation
import Observation
import GoogleSignIn

// MARK: - Google Sign In Service

/// Service responsible for handling Google Sign In
/// Uses the GoogleSignIn SDK to authenticate users with Google
/// Configuration: Client ID is read from Info.plist (GIDClientID key)
@Observable
final class GoogleSignInService {
    // MARK: - Properties

    static let shared = GoogleSignInService()
    private let logger = AppLogger()

    // MARK: - Initialization

    private init() {
        logger.info("GoogleSignInService initialized")
        configureGoogleSignIn()
    }

    // MARK: - Configuration

    /// Configure Google Sign In with client ID from Info.plist
    /// Reads GIDClientID from Info.plist as recommended by Google
    private func configureGoogleSignIn() {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            logger.error("GIDClientID not found in Info.plist. Add your Google Client ID to Info.plist")
            return
        }

        let configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = configuration

        logger.info("Google Sign In configured with client ID from Info.plist")
    }

    // MARK: - Sign In Methods

    /// Initiate Google Sign In flow
    /// - Returns: Tuple of (idToken, accessToken)
    @MainActor
    func signIn() async throws -> (idToken: String, accessToken: String?) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            logger.error("Failed to get root view controller for Google Sign In")
            throw GoogleSignInError.noViewController
        }

        logger.info("Starting Google Sign In flow...")

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                logger.error("Google Sign In: Failed to get ID token")
                throw GoogleSignInError.noIDToken
            }

            let accessToken = result.user.accessToken.tokenString

            logger.info("Google Sign In: Successfully got tokens")
            return (idToken: idToken, accessToken: accessToken)

        } catch {
            logger.error("Google Sign In: Error", error: error)
            throw error
        }
    }

    /// Sign out of Google
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        logger.info("Google Sign In: User signed out")
    }

    /// Restore previous Google sign-in if available
    /// Call this at app launch to avoid requiring users to sign in repeatedly
    /// Recommended by Google: https://developers.google.com/identity/sign-in/ios/sign-in
    @MainActor
    func restorePreviousSignIn() async -> (idToken: String, accessToken: String?)? {
        await withCheckedContinuation { continuation in
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                if let error = error {
                    self.logger.info("Google Sign In: No previous sign in to restore (\(error.localizedDescription))")
                    continuation.resume(returning: nil)
                    return
                }

                guard let user = user,
                      let idToken = user.idToken?.tokenString else {
                    self.logger.info("Google Sign In: No previous sign in to restore")
                    continuation.resume(returning: nil)
                    return
                }

                let accessToken = user.accessToken.tokenString
                self.logger.info("Google Sign In: Restored previous sign in")
                continuation.resume(returning: (idToken: idToken, accessToken: accessToken))
            }
        }
    }

    /// Handle URL callback from Google Sign In
    /// Call this in .onOpenURL modifier or application(_:open:options:)
    /// Required for OAuth redirect flow
    func handleURL(_ url: URL) -> Bool {
        let handled = GIDSignIn.sharedInstance.handle(url)
        if handled {
            logger.info("Google Sign In: Handled OAuth redirect URL")
        }
        return handled
    }
}

// MARK: - Errors

enum GoogleSignInError: Error, LocalizedError {
    case noViewController
    case noIDToken
    case signInFailed

    var errorDescription: String? {
        switch self {
        case .noViewController:
            return "Could not present Google Sign In"
        case .noIDToken:
            return "Failed to get Google ID token"
        case .signInFailed:
            return "Google Sign In failed"
        }
    }
}
