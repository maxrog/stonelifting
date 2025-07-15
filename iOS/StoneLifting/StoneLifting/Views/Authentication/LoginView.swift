//
//  LoginView.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/11/25.
//

import SwiftUI

// MARK: - Login View

/// User login screen with username/password form
/// Handles user authentication and navigation to main app
struct LoginView: View {

    // MARK: - Properties

    private let authService = AuthService.shared

    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false

    @FocusState private var focusedField: Field?

    /// Navigation action for registration
    private let onShowRegister: () -> Void
    /// Navigation action for forgotPassword
    private let onShowForgotPassword: () -> Void

    // MARK: - Initialization

    init(onShowRegister: @escaping () -> Void, onShowForgotPassword: @escaping () -> Void) {
        self.onShowRegister = onShowRegister
        self.onShowForgotPassword = onShowForgotPassword
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                formSection
                actionSection
                footerSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(Color(.systemBackground))
        .onSubmit {
            handleSubmit()
        }
        .alert("Login Error", isPresented: .constant(authService.authError != nil)) {
            Button("OK") {
                authService.clearError()
            }
        } message: {
            Text(authService.authError?.localizedDescription ?? "")
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App icon/logo placeholder
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("StoneLifting")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Track your stone lifting journey")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var formSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Username")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("Enter your username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .onSubmit {
                        focusedField = .password
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Group {
                        if showPassword {
                            TextField("Enter your password", text: $password)
                        } else {
                            SecureField("Enter your password", text: $password)
                        }
                    }
                    .focused($focusedField, equals: .password)
                    .onSubmit {
                        handleLogin()
                    }

                    Button(action: {
                        showPassword.toggle()
                    }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        VStack(spacing: 16) {
            Button(action: handleLogin) {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }

                    Text("Sign In")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isFormValid || authService.isLoading)
        }
    }

    @ViewBuilder
    private var footerSection: some View {
        VStack(spacing: 16) {
             Button("Forgot Password?") {
                 onShowForgotPassword()
             }
             .font(.subheadline)
             .foregroundColor(.blue)

             HStack {
                 Text("Don't have an account?")
                     .foregroundColor(.secondary)

                 Button("Sign Up") {
                     onShowRegister()
                 }
                 .fontWeight(.medium)
             }
             .font(.subheadline)
         }
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        !username.isEmpty && !password.isEmpty
    }

    // MARK: - Actions

    private func handleSubmit() {
        switch focusedField {
        case .username:
            focusedField = .password
        case .password:
            handleLogin()
        case .none:
            break
        }
    }

    private func handleLogin() {
        // Dismiss keyboard
        focusedField = nil

        Task {
            await authService.login(username: username, password: password)
        }
    }
}

// MARK: - Supporting Types

private enum Field {
    case username
    case password
}

// MARK: - Preview

#Preview {
    LoginView(onShowRegister: {}, onShowForgotPassword: {})
}
