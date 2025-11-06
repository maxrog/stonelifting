//
//  AuthService.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/10/25.
//

import Foundation
import Observation

// MARK: - Authentication Service

/// Service responsible for user authentication and session management
/// Handles login, registration, logout, and token persistence
@Observable
final class AuthService {

    // MARK: - Properties

    static let shared = AuthService()
    private let logger = AppLogger()

    private let apiService = APIService.shared
    private(set) var currentUser: User?
    private(set) var isAuthenticated = false
    private(set) var isLoading = false
    private(set) var authError: AuthError?

    // MARK: - Initialization

    private init() {
        // Check if user is already authenticated on app launch
        checkAuthenticationStatus()
    }

    // MARK: - Authentication Methods

    /// Register a new user account
    /// - Parameters:
    ///   - username: Desired username
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: Success status
    @MainActor
    func register(username: String, email: String, password: String) async -> Bool {
        isLoading = true
        authError = nil

        do {
            let request = CreateUserRequest(username: username,
                                            email: email,
                                            password: password)

            try await registerUser(request: request)

            // Auto-login after successful registration
            let loginSuccess = await login(username: username, password: password)

            isLoading = false
            return loginSuccess

        } catch {
            await handleAuthError(error)
            isLoading = false
            return false
        }
    }

    private func registerUser(request: CreateUserRequest) async throws {
        guard let url = URL(string: APIConfig.baseURL + APIConfig.Endpoints.register) else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(APIConfig.Headers.applicationJSON, forHTTPHeaderField: APIConfig.Headers.contentType)
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (_, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            logger.error("Error registering user", error: APIError.badRequest)
            throw APIError.badRequest
        }
        logger.info("Successfully registered user")
    }

    /// Login with username and password
    /// - Parameters:
    ///   - username: User's username
    ///   - password: User's password
    /// - Returns: Success status
    @MainActor
    func login(username: String, password: String) async -> Bool {
        isLoading = true
        authError = nil

        do {
            let request = LoginRequest(username: username, password: password)

            let response: AuthResponse = try await apiService.post(endpoint: APIConfig.Endpoints.login,
                                                                   body: request,
                                                                   responseType: AuthResponse.self)

            apiService.setAuthToken(response.token)
            currentUser = response.user
            isAuthenticated = true

            isLoading = false
            logger.info("Successfully logged in user with id: \(response.user.id), username: \(response.user.username)")
            return true

        } catch {
            await handleAuthError(error)
            isLoading = false
            logger.error("Error logging in user: \(username)", error: error)
            return false
        }
    }

    /// Logout current user
    /// Clears stored token and user data
    @MainActor
    func logout() {
        logger.info("Logging out user with id: \(String(describing: currentUser?.id)), username: \(currentUser?.username ?? "")")
        apiService.clearAuthToken()
        currentUser = nil
        isAuthenticated = false
        authError = nil
    }

    /// Refresh current user data from server
    /// Useful for getting updated user information
    @MainActor
    func refreshCurrentUser() async -> Bool {
        guard isAuthenticated else { return false }

        do {
            let user: User = try await apiService.get(endpoint: APIConfig.Endpoints.me,
                                                      requiresAuth: true,
                                                      type: User.self)

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

        return try await apiService.get(endpoint: APIConfig.Endpoints.stats,
                                        requiresAuth: true,
                                        type: UserStatsResponse.self)
    }

    // MARK: - Password Reset

    /// Send password reset email
    /// - Parameter email: Email address to send reset link to
    /// - Returns: Success status and message
    @MainActor
    func sendPasswordReset(email: String) async -> (success: Bool, message: String) {
        // Validate email format first
        let emailValidation = validateEmail(email)
        guard emailValidation.isValid else {
            return (false, emailValidation.errorMessage ?? "Invalid email format")
        }

        do {
            let request = ForgotPasswordRequest(email: email)

            let response: MessageResponse = try await apiService.post(endpoint: APIConfig.Endpoints.forgotPassword,
                                                                      body: request,
                                                                      responseType: MessageResponse.self)
            logger.info("Sent password reset to \(email), response: \(response.message)")
            return (true, response.message)

        } catch {
            let errorMessage = (error as? APIError)?.localizedDescription ?? "Failed to send reset email"
            logger.error("Failed to send password reset to \(email)", error: error)
            return (false, errorMessage)
        }
    }

    /// Reset password with token
    /// - Parameters:
    ///   - email: Email address of the account
    ///   - token: Reset token from email
    ///   - newPassword: New password to set
    /// - Returns: Success status and message
    @MainActor
    func resetPassword(email: String, token: String, newPassword: String) async -> (success: Bool, message: String) {
        // Validate new password
        let passwordValidation = validatePassword(newPassword)
        guard passwordValidation.isValid else {
            return (false, passwordValidation.errorMessage ?? "Invalid password")
        }

        do {
            let request = ResetPasswordRequest(email: email,
                                               token: token,
                                               newPassword: newPassword)

            let response: MessageResponse = try await apiService.post(endpoint: APIConfig.Endpoints.resetPassword,
                                                                      body: request,
                                                                      responseType: MessageResponse.self)
            logger.info("Reset password for email \(email), response: \(response.message)")
            return (true, response.message)

        } catch {
            let errorMessage = (error as? APIError)?.localizedDescription ?? "Failed to reset password"
            logger.error("Failed to reset password for \(email)", error: error)
            return (false, errorMessage)
        }
    }

    // MARK: - Availability Checking

    /// Check if username is available
    /// - Parameter username: Username to check
    /// - Returns: True if available, false if taken
    func checkUsernameAvailability(_ username: String) async -> Bool {
        guard validateUsername(username).isValid else {
            logger.info("Checking username availability but invalid username \(username)")
            return false
        }

        do {
            let response: AvailabilityResponse = try await apiService.get(endpoint: "\(APIConfig.Endpoints.checkUsername)/\(username)",
                                                                          requiresAuth: false,
                                                                          type: AvailabilityResponse.self)
            logger.info("Checking username availability for \(username), available: \(response.available)")
            return response.available
        } catch {
            logger.error("Error checking username availability, return true to avoid blocking", error: error)
            return true
        }
    }

    /// Check if email is available
    /// - Parameter email: Email to check
    /// - Returns: True if available, false if taken
    func checkEmailAvailability(_ email: String) async -> Bool {
        guard validateEmail(email).isValid else {
            logger.info("Checking email availability but invalid email \(email)")
            return false
        }

        do {
            let response: AvailabilityResponse = try await apiService.get(endpoint: "\(APIConfig.Endpoints.checkEmail)/\(email)",
                                                                          requiresAuth: false,
                                                                          type: AvailabilityResponse.self)
            logger.info("Checking email availability for \(email), available: \(response.available)")
            return response.available
        } catch {
            logger.error("Error checking email availability, return true to avoid blocking", error: error)
            return true
        }
    }

    // MARK: - Error Handling

    func clearError() {
        authError = nil
    }

    // MARK: - Validation

    /// Validate username format
    /// - Parameter username: Username to validate
    /// - Returns: Validation result
    func validateUsername(_ username: String) -> ValidationResult {
        logger.info("Validating username \(username)...")

        if username.isEmpty {
            let result = ValidationResult.invalid("Username cannot be empty")
            logger.error("Username: \(username) invalid, error: \(result.errorMessage ?? "")")
            return result
        }

        if username.count < 3 {
            let result = ValidationResult.invalid("Username must be at least 3 characters")
            logger.error("Username: \(username) invalid, error: \(result.errorMessage ?? "")")
            return result
        }

        if username.count > 20 {
            let result = ValidationResult.invalid("Username cannot exceed 20 characters")
            logger.error("Username: \(username) invalid, error: \(result.errorMessage ?? "")")
            return result
        }

        // Check for valid characters (alphanumeric and underscore)
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if username.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            let result = ValidationResult.invalid("Username can only contain letters, numbers, and underscores")
            logger.error("Username: \(username) invalid, error: \(result.errorMessage ?? "")")
            return result
        }

        logger.info("Username: \(username) valid")
        return .valid
    }

    /// Validate email format
    /// - Parameter email: Email to validate
    /// - Returns: Validation result
    func validateEmail(_ email: String) -> ValidationResult {
        logger.info("Validating email \(email)...")
        if email.isEmpty {
            let result = ValidationResult.invalid("Email cannot be empty")
            logger.error("Email: \(email) invalid, error: \(result.errorMessage ?? "")")
            return result
        }

        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        if !emailPredicate.evaluate(with: email) {
            let result = ValidationResult.invalid("Please enter a valid email address")
            logger.error("Email: \(email) invalid, error: \(result.errorMessage ?? "")")
            return result
        }

        logger.info("Email: \(email) valid")
        return .valid
    }

    /// Validate password strength
    /// - Parameter password: Password to validate
    /// - Returns: Validation result
    func validatePassword(_ password: String) -> ValidationResult {
        logger.info("Validating password...")
        if password.isEmpty {
            let result = ValidationResult.invalid("Password cannot be empty")
            logger.error("Password invalid, error: \(result.errorMessage ?? "")")
            return result
        }

        if password.count < 8 {
            let result = ValidationResult.invalid("Password must be at least 8 characters")
            logger.error("Password invalid, error: \(result.errorMessage ?? "")")
            return result
        }

        if password.count > 128 {
            let result = ValidationResult.invalid("Password cannot exceed 128 characters")
            logger.error("Password invalid, error: \(result.errorMessage ?? "")")
            return result
        }

        // Check for at least one letter and one number
        let hasLetter = password.rangeOfCharacter(from: .letters) != nil
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil

        if !hasLetter || !hasNumber {
            let result = ValidationResult.invalid("Password must contain at least one letter and one number")
            logger.error("Password invalid, error: \(result.errorMessage ?? "")")
            return result
        }

        logger.info("Password valid")
        return .valid
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
private struct EmptyResponse: Codable {
}

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
            return "Please log in to continue"
        case .invalidCredentials:
            return "Invalid username or password"
        case .sessionExpired:
            return "Your session has expired. Please log in again"
        case .registrationFailed:
            return "Registration failed. Username or email may already be taken"
        case .networkError:
            return "Network error. Please check your connection and try again"
        case .unknownError(let message):
            return message
        }
    }
}

/// Validation result for form inputs
enum ValidationResult {
    case valid
    case invalid(String)

    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }

    var errorMessage: String? {
        if case .invalid(let message) = self {
            return message
        }
        return nil
    }
}
