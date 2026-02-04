//
//  AppleSignInService.swift
//  StoneLifting
//
//  Created by Max Rogers on 1/31/26.
//

import Foundation
import Observation
import AuthenticationServices
import CryptoKit

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

    /// Silently refresh Apple Sign In credentials
    /// Gets fresh identity token without showing UI (if credential is still authorized)
    /// Used for refreshing JWT tokens when they expire
    /// - Returns: Fresh identity token, nonce, and authorization code, or nil if refresh fails
    @MainActor
    func silentRefresh() async -> (identityToken: String, nonce: String, authorizationCode: String)? {
        guard let userID = getStoredUserID() else {
            logger.info("Apple Sign In: No stored user ID for silent refresh")
            return nil
        }

        logger.info("Apple Sign In: Attempting silent credential refresh")

        // Check credential state first
        let credentialState = await checkCredentialState()
        guard credentialState == .authorized else {
            logger.warning("Apple Sign In: Credential not authorized, cannot refresh silently")
            return nil
        }

        // Create request for existing credentials (no UI)
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()

        // Empty scopes = just refresh existing credentials without user interaction
        request.requestedScopes = []

        // Generate nonce for security
        let nonce = generateNonce()
        request.nonce = sha256(nonce)

        // Perform silent authorization
        return await withCheckedContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = SilentRefreshDelegate(
                nonce: nonce,
                onComplete: { result in
                    continuation.resume(returning: result)
                }
            )

            controller.delegate = delegate
            controller.performRequests()

            // Keep delegate alive during async operation
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    /// Sign out from Apple Sign In
    /// Clears stored user ID
    func signOut() {
        clearStoredUserID()
        logger.info("Apple Sign In: User signed out")
    }

    // MARK: - Private Helpers

    /// Generate a cryptographically secure random nonce
    private func generateNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    /// Hash nonce with SHA256
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Silent Refresh Delegate

/// Delegate for handling silent Apple Sign In refresh
/// Separated to avoid retain cycles and handle completion properly
private class SilentRefreshDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let nonce: String
    private let onComplete: ((identityToken: String, nonce: String, authorizationCode: String)?) -> Void
    private let logger = AppLogger()

    init(nonce: String, onComplete: @escaping ((identityToken: String, nonce: String, authorizationCode: String)?) -> Void) {
        self.nonce = nonce
        self.onComplete = onComplete
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8),
              let authCode = appleIDCredential.authorizationCode,
              let authCodeString = String(data: authCode, encoding: .utf8) else {
            logger.error("Apple Sign In: Silent refresh failed - missing credentials")
            onComplete(nil)
            return
        }

        logger.info("Apple Sign In: Silent refresh succeeded")
        onComplete((identityToken: tokenString, nonce: nonce, authorizationCode: authCodeString))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        logger.error("Apple Sign In: Silent refresh failed", error: error)
        onComplete(nil)
    }
}
