//
//  UsernamePickerViewModel.swift
//  StoneAtlas
//
//  Created by Max Rogers on 7/10/25.
//

import Foundation
import Observation

@Observable
@MainActor
final class UsernamePickerViewModel {

    private let logger = AppLogger()
    private let authService = AuthService.shared
    private let apiService = APIService.shared

    var username: String = ""
    var validationError: String?
    var isCheckingAvailability = false
    var isSubmitting = false

    private var checkTask: Task<Void, Never>?

    var isValid: Bool {
        validationError == nil && !username.isEmpty && username.count >= 3
    }

    var canSubmit: Bool {
        isValid && !isCheckingAvailability && !isSubmitting
    }


    func validateUsername() {
        // Cancel any pending availability check
        checkTask?.cancel()

        // Reset state
        validationError = nil
        isCheckingAvailability = false

        guard !username.isEmpty else {
            return
        }

        // Check length
        if username.count < 3 {
            validationError = "Username must be at least 3 characters"
            return
        }

        if username.count > 20 {
            validationError = "Username must be 20 characters or less"
            return
        }

        // Check characters (alphanumeric only)
        let alphanumericSet = CharacterSet.alphanumerics
        if username.unicodeScalars.contains(where: { !alphanumericSet.contains($0) }) {
            validationError = "Username can only contain letters and numbers"
            return
        }

        // Check availability with debouncing
        checkAvailability()
    }

    func submit() async -> Bool {
        guard canSubmit else {
            logger.warning("Attempted to submit invalid username")
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }

        logger.info("Submitting username: \(username)")

        let success = await authService.updateUsername(username)

        if success {
            logger.info("Username updated successfully")
        } else {
            logger.error("Failed to update username")
            if let error = authService.authError {
                validationError = error.localizedDescription
            } else {
                validationError = "Failed to update username. Please try again."
            }
        }

        return success
    }

    // MARK: - Private Methods

    private func checkAvailability() {
        checkTask?.cancel()

        checkTask = Task {
            // Debounce: wait 500ms before checking
            try? await Task.sleep(nanoseconds: 500_000_000)

            guard !Task.isCancelled else { return }

            isCheckingAvailability = true
            defer { isCheckingAvailability = false }

            do {
                let response: AvailabilityResponse = try await apiService.get(
                    endpoint: "/auth/check-username/\(username.lowercased())",
                    requiresAuth: false,
                    type: AvailabilityResponse.self
                )

                guard !Task.isCancelled else { return }

                if !response.available {
                    validationError = "Username '\(username)' is already taken"
                    logger.debug("Username '\(username)' is not available")
                } else {
                    logger.debug("Username '\(username)' is available")
                }
            } catch {
                guard !Task.isCancelled else { return }
                logger.error("Error checking username availability", error: error)
                validationError = "Could not check availability. Please try again."
            }
        }
    }
}
