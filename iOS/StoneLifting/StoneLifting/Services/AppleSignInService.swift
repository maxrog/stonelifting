//
//  AppleSignInService.swift
//  StoneLifting
//
//  Created by Max Rogers on 1/31/26.
//

import Foundation
import Observation
import AuthenticationServices

// MARK: - Apple Sign In Service

/// Service responsible for handling Apple Sign In
/// Manages credential state checking and user ID persistence
@Observable
final class AppleSignInService {
    // MARK: - Properties

    static let shared = AppleSignInService()
    private let logger = AppLogger()
    private let userDefaults = UserDefaults.standard

    // Key for storing Apple user ID
    private let appleUserIDKey = "com.marfodub.StoneAtlas.apple_user_id"

    // MARK: - Initialization

    private init() {
        logger.info("AppleSignInService initialized")
    }

    // MARK: - Credential State Management

    /// Check the credential state for the stored Apple user ID
    /// Call this at app launch to verify the user's Apple ID credential is still valid
    /// - Returns: Credential state (authorized, revoked, notFound, or nil if no stored user ID)
    @MainActor
    func checkCredentialState() async -> ASAuthorizationAppleIDProvider.CredentialState? {
        guard let userID = getStoredUserID() else {
            logger.info("Apple Sign In: No stored user ID to check")
            return nil
        }

        logger.info("Apple Sign In: Checking credential state for user ID")

        return await withCheckedContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: userID) { state, error in
                if let error = error {
                    self.logger.error("Apple Sign In: Error checking credential state", error: error)
                    continuation.resume(returning: nil)
                    return
                }

                switch state {
                case .authorized:
                    self.logger.info("Apple Sign In: Credential state is authorized")
                case .revoked:
                    self.logger.warning("Apple Sign In: Credential state is revoked")
                    // Clear stored user ID since credential is revoked
                    self.clearStoredUserID()
                case .notFound:
                    self.logger.info("Apple Sign In: Credential state is not found")
                    // Clear stored user ID since credential doesn't exist
                    self.clearStoredUserID()
                case .transferred:
                    self.logger.info("Apple Sign In: Credential state is transferred")
                @unknown default:
                    self.logger.warning("Apple Sign In: Unknown credential state")
                }

                continuation.resume(returning: state)
            }
        }
    }

    /// Store Apple user ID after successful sign in
    /// Used for checking credential state on app launch
    func storeUserID(_ userID: String) {
        userDefaults.set(userID, forKey: appleUserIDKey)
        logger.info("Apple Sign In: Stored user ID for credential state checking")
    }

    /// Get stored Apple user ID
    func getStoredUserID() -> String? {
        userDefaults.string(forKey: appleUserIDKey)
    }

    /// Clear stored Apple user ID
    /// Called when credential is revoked or not found
    func clearStoredUserID() {
        userDefaults.removeObject(forKey: appleUserIDKey)
        logger.info("Apple Sign In: Cleared stored user ID")
    }

    /// Sign out from Apple Sign In
    /// Clears stored user ID
    func signOut() {
        clearStoredUserID()
        logger.info("Apple Sign In: User signed out")
    }
}
