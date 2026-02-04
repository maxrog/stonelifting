//
//  AuthService.swift
//  StoneAtlas
//
//  Created by Max Rogers on 7/10/25.
//

import Foundation
import Observation

// MARK: - Authentication Service

/// Service responsible for user authentication and session management
/// Handles login, registration, logout, token persistence, password reset
@Observable
final class AuthService {
    // MARK: - Properties

    static let shared = AuthService()
    private let logger = AppLogger()

    private let apiService = APIService.shared
    private(set) var currentUser: User?
    private(set) var isAuthenticated = false
    private(set) var authError: AuthError?

    private let authProviderKey = "com.marfodub.StoneAtlas.authProvider"

    private enum AuthProvider: String {
        case apple
        case google
    }

    // MARK: - Initialization

    private init() {
        // Check if user is already authenticated on app launch
        checkAuthenticationStatus()
    }

    // MARK: - OAuth Authentication Methods

    /// Login with Apple Sign In
    /// - Parameters:
    ///   - identityToken: Apple identity token (JWT)
    ///   - authorizationCode: Apple authorization code
    ///   - fullName: User's full name (optional, only provided on first sign in)
    ///   - email: User's email (optional, only provided on first sign in or if user chose to share)
    ///   - nonce: Unhashed nonce for server-side verification (prevents replay attacks)
    /// - Returns: Success status
    @MainActor
    func loginWithApple(
        identityToken: String,
        authorizationCode: String,
        fullName: PersonNameComponents?,
        email: String?,
        nonce: String
    ) async -> Bool {
        authError = nil

        do {
            let request = AppleSignInRequest(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                fullName: fullName,
                email: email,
                nonce: nonce
            )

            let response: AuthResponse = try await apiService.post(
                endpoint: APIConfig.Endpoints.appleSignIn,
                body: request,
                responseType: AuthResponse.self
            )

            apiService.setAuthToken(response.token, refreshToken: response.refreshToken)
            currentUser = response.user
            isAuthenticated = true

            UserDefaults.standard.set(AuthProvider.apple.rawValue, forKey: authProviderKey)

            logger.info("Successfully logged in with Apple - user id: \(response.user.id), username: \(response.user.username)")

            Task {
                logger.info("Fetching stones after Apple login")
                async let userFetch = StoneService.shared.fetchUserStones(shouldCache: true)
                async let publicFetch = StoneService.shared.fetchPublicStones(shouldCache: true)
                _ = await (userFetch, publicFetch)
            }

            return true

        } catch {
            await handleAuthError(error)
            logger.error("Error logging in with Apple", error: error)
            return false
        }
    }

    /// Login with Google Sign In
    /// - Returns: Success status
    @MainActor
    func loginWithGoogle() async -> Bool {
        authError = nil

        do {
            // Get Google credentials using GoogleSignInService
            let (idToken, accessToken) = try await GoogleSignInService.shared.signIn()
            return await loginWithGoogleTokens(idToken: idToken, accessToken: accessToken)

        } catch {
            await handleAuthError(error)
            logger.error("Error logging in with Google", error: error)
            return false
        }
    }

    /// Login with Google tokens
    /// Used for silent token refresh or restoring previous sessions
    /// - Parameters:
    ///   - idToken: Google ID token
    ///   - accessToken: Google access token
    /// - Returns: Success status
    @MainActor
    func loginWithGoogleTokens(idToken: String, accessToken: String?) async -> Bool {
        authError = nil

        do {
            let request = GoogleSignInRequest(
                idToken: idToken,
                accessToken: accessToken
            )

            let response: AuthResponse = try await apiService.post(
                endpoint: APIConfig.Endpoints.googleSignIn,
                body: request,
                responseType: AuthResponse.self
            )

            apiService.setAuthToken(response.token, refreshToken: response.refreshToken)
            currentUser = response.user
            isAuthenticated = true

            UserDefaults.standard.set(AuthProvider.google.rawValue, forKey: authProviderKey)

            logger.info("Successfully logged in with Google - user id: \(response.user.id), username: \(response.user.username)")

            Task {
                logger.info("Fetching stones after Google login")
                async let userFetch = StoneService.shared.fetchUserStones(shouldCache: true)
                async let publicFetch = StoneService.shared.fetchPublicStones(shouldCache: true)
                _ = await (userFetch, publicFetch)
            }

            return true

        } catch {
            await handleAuthError(error)
            logger.error("Error logging in with Google tokens", error: error)
            return false
        }
    }

    /// Logout current user
    /// Clears stored token, user data, and all cached stones
    @MainActor
    func logout() {
        logger.info("Logging out user with id: \(String(describing: currentUser?.id)), username: \(currentUser?.username ?? "")")

        // Clear authentication data
        apiService.clearAuthToken()
        currentUser = nil
        isAuthenticated = false
        authError = nil
        UserDefaults.standard.removeObject(forKey: authProviderKey)

        // Clear all stone-related data
        Task {
            // Clear persistent cache
            try? await StoneCacheService.shared.clearAllCache()
            logger.info("Cleared all stone caches on logout")

            await MainActor.run {
                StoneService.shared.clearAllStones()
                logger.info("Cleared in-memory stones on logout")
            }
        }
    }

    /// Refresh current user data from server
    /// Useful for getting updated user information
    @MainActor
    func refreshCurrentUser() async -> Bool {
        guard isAuthenticated else { return false }

        do {
            let user: User = try await apiService.get(
                endpoint: APIConfig.Endpoints.me,
                requiresAuth: true,
                type: User.self
            )

            logger.info("")
            currentUser = user
            logger.info("Refreshed user with id: \(String(describing: currentUser?.id)), username: \(currentUser?.username ?? "")")
            return true

        } catch {
            await handleAuthError(error)
            logger.error("Error refreshing user with id: \(String(describing: currentUser?.id)), username: \(currentUser?.username ?? "")", error: error)
            return false
        }
    }

    /// Get current user's statistics including stones
    /// - Returns: User statistics with stone data
    func getUserStats() async throws -> UserStatsResponse {
        guard isAuthenticated else {
            throw AuthError.notAuthenticated
        }

        return try await apiService.get(
            endpoint: APIConfig.Endpoints.stats,
            requiresAuth: true,
            type: UserStatsResponse.self
        )
    }

    // MARK: - Error Handling

    func clearError() {
        authError = nil
    }
}

// MARK: - Private Methods

private extension AuthService {
    /// Check if user is already authenticated on app launch
    func checkAuthenticationStatus() {
        let authenticated = apiService.isAuthenticated
        logger.info("Checking user authentication status: \(authenticated)")
        if authenticated {
            isAuthenticated = true
            // Optionally refresh user data
            Task {
                logger.info("Refreshing current user")
                await refreshCurrentUser()
            }
        }
    }

    /// Handle authentication errors
    /// - Parameter error: The error to handle
    @MainActor
    func handleAuthError(_ error: Error) {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                // Token expired or invalid - logout user
                logout()
                authError = .sessionExpired
            case .badRequest:
                authError = .invalidCredentials
            case .networkError:
                authError = .networkError
            default:
                authError = .unknownError(apiError.localizedDescription)
            }
        } else {
            authError = .unknownError(error.localizedDescription)
        }
    }
}

// MARK: - Supporting Types

/// Empty response for endpoints that don't return data
private struct EmptyResponse: Codable {}

/// Availability response for username / email
struct AvailabilityResponse: Codable {
    let available: Bool
}

/// Authentication error types
enum AuthError: Error, LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case sessionExpired
    case registrationFailed
    case networkError
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to be logged in to do that. Please sign in to continue."
        case .invalidCredentials:
            return "The username or password you entered is incorrect. Please double-check and try again."
        case .sessionExpired:
            return "Your session has expired for security reasons. Please sign in again to continue."
        case .registrationFailed:
            return "We couldn't create your account. That username or email might already be in use. Try a different one."
        case .networkError:
            return "We're having trouble connecting to the internet. Please check your connection and try again."
        case let .unknownError(message):
            return message
        }
    }
}
