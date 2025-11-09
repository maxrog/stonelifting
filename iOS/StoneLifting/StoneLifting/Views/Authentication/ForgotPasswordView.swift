//
//  ForgotPasswordView.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/11/25.
//

import SwiftUI

/// Forgot password screen for requesting password reset
/// Allows users to enter email and receive reset instructions
struct ForgotPasswordView: View {
    // MARK: - Properties

    private let authService = AuthService.shared

    @State private var email = ""
    @State private var isLoading = false
    @State private var message = ""
    @State private var showSuccess = false

    @FocusState private var isEmailFocused: Bool

    /// Navigation action to return to login
    private let onReturnToLogin: () -> Void

    // MARK: - Initialization

    init(onReturnToLogin: @escaping () -> Void) {
        self.onReturnToLogin = onReturnToLogin
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                headerSection

                if showSuccess {
                    successSection
                } else {
                    formSection
                }

                footerSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(Color(.systemBackground))
        .onSubmit {
            if !showSuccess {
                sendResetEmail()
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.rotation")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("Forgot Password?")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Enter your email address and we'll send you instructions to reset your password")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private var formSection: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email Address")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("Enter your email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .focused($isEmailFocused)
                    .onSubmit {
                        sendResetEmail()
                    }

                if !email.isEmpty {
                    ValidationFeedbackView(result: authService.validateEmail(email))
                }
            }

            Button(action: sendResetEmail) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }

                    Text("Send Reset Instructions")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isFormValid || isLoading)

            if !message.isEmpty && !showSuccess {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private var successSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            VStack(spacing: 12) {
                Text("Check Your Email")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Didn't receive an email? Check your spam folder or try again.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }

            Button("Send Again") {
                showSuccess = false
                message = ""
                sendResetEmail()
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var footerSection: some View {
        VStack(spacing: 16) {
            Button("Back to Sign In") {
                onReturnToLogin()
            }
            .fontWeight(.medium)
        }
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        authService.validateEmail(email).isValid
    }

    // MARK: - Actions

    private func sendResetEmail() {
        isEmailFocused = false
        isLoading = true
        message = ""

        Task {
            let result = await authService.sendPasswordReset(email: email)

            await MainActor.run {
                isLoading = false
                message = result.message
                showSuccess = result.success
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ForgotPasswordView(onReturnToLogin: {})
}
