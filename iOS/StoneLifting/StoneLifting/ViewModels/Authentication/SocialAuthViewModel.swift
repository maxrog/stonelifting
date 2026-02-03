//
//  SocialAuthViewModel.swift
//  StoneLifting
//
//  Created by Max Rogers on 1/26/26.
//

import Foundation
import Observation
import AuthenticationServices
import CryptoKit

// MARK: - Social Auth View Model

/// ViewModel for SocialAuthView
/// Manages Apple and Google sign-in logic
@Observable
final class SocialAuthViewModel {
    // MARK: - Properties

    private let authService = AuthService.shared
    private let logger = AppLogger()

    // UI State
    var isGoogleLoading = false
    var authError: AuthError?

    // Apple Sign In Security
    private var currentNonce: String?
    private var currentState: String?

    // MARK: - Apple Sign In

    /// Configure Apple sign-in request with security best practices
    /// Generates nonce and state parameters to prevent replay attacks
    func handleAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        // Generate cryptographically secure nonce
        let nonce = generateNonce()
        currentNonce = nonce
        request.nonce = sha256(nonce)

        // Generate state for request verification
        let state = generateRandomString()
        currentState = state
        request.state = state

        // Request scopes
        request.requestedScopes = [.fullName, .email]

        logger.info("Apple Sign In: Request configured with nonce and state")
    }

    /// Generate cryptographically secure random string for nonce
    private func generateNonce(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            logger.error("Apple Sign In: Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    /// Generate random string for state parameter
    private func generateRandomString(length: Int = 32) -> String {
        generateNonce(length: length)
    }

    /// SHA256 hash the nonce as required by Apple
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }

    /// Handle Apple sign-in completion
    @MainActor
    func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            await processAppleAuthorization(authorization)
        case .failure(let error):
            handleAppleSignInError(error)
        }
    }

    @MainActor
    private func processAppleAuthorization(_ authorization: ASAuthorization) async {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            logger.error("Apple Sign In: Failed to get Apple ID credential")
            authError = .unknownError("Failed to get Apple ID credential")
            return
        }

        // Store Apple user ID for credential state checking
        AppleSignInService.shared.storeUserID(appleIDCredential.user)

        // Verify state parameter to prevent CSRF attacks
        guard let state = appleIDCredential.state, state == currentState else {
            logger.error("Apple Sign In: State verification failed")
            authError = .unknownError("Invalid state parameter")
            return
        }

        guard let identityToken = appleIDCredential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            logger.error("Apple Sign In: Failed to decode identity token")
            authError = .unknownError("Failed to decode identity token")
            return
        }

        guard let authorizationCode = appleIDCredential.authorizationCode,
              let authorizationCodeString = String(data: authorizationCode, encoding: .utf8) else {
            logger.error("Apple Sign In: Failed to decode authorization code")
            authError = .unknownError("Failed to decode authorization code")
            return
        }

        guard let nonce = currentNonce else {
            logger.error("Apple Sign In: Nonce not found")
            authError = .unknownError("Invalid nonce")
            return
        }

        logger.info("Apple Sign In: State verified, got credentials, calling backend...")

        let success = await authService.loginWithApple(
            identityToken: identityTokenString,
            authorizationCode: authorizationCodeString,
            fullName: appleIDCredential.fullName,
            email: appleIDCredential.email,
            nonce: nonce
        )

        if !success {
            authError = authService.authError
            logger.error("Apple Sign In: Failed", error: authService.authError)
        } else {
            logger.info("Apple Sign In: Success")
        }

        // Clear nonce and state after use
        currentNonce = nil
        currentState = nil
    }

    private func handleAppleSignInError(_ error: Error) {
        let nsError = error as NSError

        // Don't show error for user cancellation
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            logger.info("Apple Sign In: User canceled")
            return
        }

        logger.error("Apple Sign In: Error", error: error)
        authError = .unknownError("Apple Sign In failed: \(error.localizedDescription)")
    }

    // MARK: - Google Sign In

    /// Handle Google sign-in
    @MainActor
    func handleGoogleSignIn() async {
        isGoogleLoading = true
        authError = nil

        logger.info("Google Sign In: Starting...")

        let success = await authService.loginWithGoogle()

        if !success {
            authError = authService.authError
            logger.error("Google Sign In: Failed", error: authService.authError)
        } else {
            logger.info("Google Sign In: Success")
        }

        isGoogleLoading = false
    }

    // MARK: - Error Handling

    /// Clear any error
    func clearError() {
        authError = nil
        authService.clearError()
    }
}
