//
//  LoginViewModel.swift
//  StoneLifting
//
//  Created by Max Rogers on 11/09/25.
//

import Foundation
import Observation

// MARK: - Login View Model

/// ViewModel for LoginView
/// Manages login state and business logic
@Observable
final class LoginViewModel {
    // MARK: - Properties

    private let authService = AuthService.shared

    // UI State
    var isLoading = false
    var authError: AuthError?

    // MARK: - Actions

    /// Login with username and password
    @MainActor
    func login(username: String, password: String) async -> Bool {
        isLoading = true
        authError = nil

        let success = await authService.login(username: username, password: password)

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
}
