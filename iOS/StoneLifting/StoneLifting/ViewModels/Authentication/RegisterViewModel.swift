//
//  RegisterViewModel.swift
//  StoneLifting
//
//  Created by Max Rogers on 11/08/25.
//

import Foundation
import Observation

// MARK: - Register View Model

/// ViewModel for RegisterView
/// Manages registration state and business logic
@Observable
final class RegisterViewModel {
    // MARK: - Properties

    private let authService = AuthService.shared

    // UI State
    var isLoading = false
    var authError: AuthError?

    // MARK: - Actions

    /// Register a new user
    @MainActor
    func register(username: String, email: String, password: String) async -> Bool {
        isLoading = true
        authError = nil

        let success = await authService.register(username: username, email: email, password: password)

        if !success {
            authError = authService.authError
        }

        isLoading = false
        return success
    }

    /// Clear any error
    func clearError() {
        authError = nil
        authService.clearError()
    }

    // MARK: - Validation (delegates to AuthService)

    func validateUsername(_ username: String) -> ValidationResult {
        return authService.validateUsername(username)
    }

    func validateEmail(_ email: String) -> ValidationResult {
        return authService.validateEmail(email)
    }

    func validatePassword(_ password: String) -> ValidationResult {
        return authService.validatePassword(password)
    }

    // MARK: - Availability Checking (delegates to AuthService)

    func checkUsernameAvailability(_ username: String) async -> Bool {
        return await authService.checkUsernameAvailability(username)
    }

    func checkEmailAvailability(_ email: String) async -> Bool {
        return await authService.checkEmailAvailability(email)
    }
}
