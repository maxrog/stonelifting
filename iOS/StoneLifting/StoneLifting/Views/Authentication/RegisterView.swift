//
//  RegisterView.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/11/25.
//

import SwiftUI

// MARK: - Register View

/// User registration screen with form validation
/// Handles new user account creation with comprehensive validation
struct RegisterView: View {
    // MARK: - Properties

    @State private var viewModel = RegisterViewModel()

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false

    /// Availability checking states
    @State private var isCheckingUsername = false
    @State private var isCheckingEmail = false
    @State private var usernameAvailable: Bool?
    @State private var emailAvailable: Bool?

    /// Debounce tasks for availability checking
    @State private var usernameCheckTask: Task<Void, Never>?
    @State private var emailCheckTask: Task<Void, Never>?

    @FocusState private var focusedField: Field?

    /// Navigation action for login
    private let onShowLogin: () -> Void

    // MARK: - Initialization

    init(onShowLogin: @escaping () -> Void) {
        self.onShowLogin = onShowLogin
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
        .alert("Registration Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("Join StoneLifting")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Create your account to start tracking stones")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var formSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Username")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        TextField("Choose a username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .username)
                            .onSubmit {
                                focusedField = .email
                            }
                            .onChange(of: username) { _, newValue in
                                checkUsernameAvailability(newValue)
                            }

                        if isCheckingUsername {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.8)
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                    if !username.isEmpty {
                        ValidationFeedbackView(
                            result: viewModel.validateUsername(username),
                            availabilityResult: usernameAvailable,
                            isChecking: isCheckingUsername,
                            itemType: "Username"
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        TextField("Enter your email", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .focused($focusedField, equals: .email)
                            .onSubmit {
                                focusedField = .password
                            }
                            .onChange(of: email) { _, newValue in
                                checkEmailAvailability(newValue)
                            }

                        if isCheckingEmail {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.8)
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                    if !email.isEmpty {
                        ValidationFeedbackView(
                            result: viewModel.validateEmail(email),
                            availabilityResult: emailAvailable,
                            isChecking: isCheckingEmail,
                            itemType: "Email"
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Group {
                        if showPassword {
                            TextField("Create a password", text: $password)
                        } else {
                            SecureField("Create a password", text: $password)
                        }
                    }
                    .focused($focusedField, equals: .password)
                    .onSubmit {
                        focusedField = .confirmPassword
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

                if !password.isEmpty {
                    ValidationFeedbackView(result: viewModel.validatePassword(password))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Confirm Password")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Group {
                        if showConfirmPassword {
                            TextField("Confirm your password", text: $confirmPassword)
                        } else {
                            SecureField("Confirm your password", text: $confirmPassword)
                        }
                    }
                    .focused($focusedField, equals: .confirmPassword)
                    .onSubmit {
                        handleRegistration()
                    }

                    Button(action: {
                        showConfirmPassword.toggle()
                    }) {
                        Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                if !confirmPassword.isEmpty {
                    ValidationFeedbackView(result: passwordMatchValidation)
                }
            }
        }
    }

    /// Action section with registration button
    @ViewBuilder
    private var actionSection: some View {
        VStack(spacing: 16) {
            Button(action: handleRegistration) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }

                    Text("Create Account")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isFormValid || viewModel.isLoading)

            Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// Footer section with login link
    @ViewBuilder
    private var footerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Already have an account?")
                    .foregroundColor(.secondary)

                Button("Sign In") {
                    onShowLogin()
                }
                .fontWeight(.medium)
            }
            .font(.subheadline)
        }
    }

    // MARK: - Availability Checking

    /// Check username availability with debouncing
    private func checkUsernameAvailability(_ username: String) {
        // Cancel previous task
        usernameCheckTask?.cancel()

        // Reset state
        usernameAvailable = nil

        // Don't check if empty or invalid
        guard !username.isEmpty, viewModel.validateUsername(username).isValid else {
            isCheckingUsername = false
            return
        }

        // Start checking
        isCheckingUsername = true

        // Debounce the check
        usernameCheckTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay

            guard !Task.isCancelled else { return }

            let available = await viewModel.checkUsernameAvailability(username)

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.usernameAvailable = available
                self.isCheckingUsername = false
            }
        }
    }

    /// Check email availability with debouncing
    private func checkEmailAvailability(_ email: String) {
        // Cancel previous task
        emailCheckTask?.cancel()

        // Reset state
        emailAvailable = nil

        // Don't check if empty or invalid
        guard !email.isEmpty, viewModel.validateEmail(email).isValid else {
            isCheckingEmail = false
            return
        }

        // Start checking
        isCheckingEmail = true

        // Debounce the check
        emailCheckTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay

            guard !Task.isCancelled else { return }

            let available = await viewModel.checkEmailAvailability(email)

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.emailAvailable = available
                self.isCheckingEmail = false
            }
        }
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        viewModel.validateUsername(username).isValid &&
            viewModel.validateEmail(email).isValid &&
            viewModel.validatePassword(password).isValid &&
            passwordMatchValidation.isValid &&
            usernameAvailable == true &&
            emailAvailable == true &&
            !isCheckingUsername &&
            !isCheckingEmail
    }

    private var passwordMatchValidation: ValidationResult {
        if confirmPassword.isEmpty {
            return .valid
        }

        if password != confirmPassword {
            return .invalid("Passwords do not match")
        }

        return .valid
    }

    // MARK: - Actions

    /// Handle form submission
    private func handleSubmit() {
        switch focusedField {
        case .username:
            focusedField = .email
        case .email:
            focusedField = .password
        case .password:
            focusedField = .confirmPassword
        case .confirmPassword:
            handleRegistration()
        case .none:
            break
        }
    }

    /// Handle registration action
    private func handleRegistration() {
        // Dismiss keyboard
        focusedField = nil

        // Perform registration
        Task {
            await viewModel.register(username: username, email: email, password: password)
        }
    }
}

// MARK: - Validation Feedback View

/// Displays validation feedback for form fields with availability checking
struct ValidationFeedbackView: View {
    let result: ValidationResult
    let availabilityResult: Bool?
    let isChecking: Bool
    let itemType: String

    // For fields without availability checking
    init(result: ValidationResult) {
        self.result = result
        availabilityResult = nil
        isChecking = false
        itemType = ""
    }

    // For fields with availability checking
    init(result: ValidationResult, availabilityResult: Bool?, isChecking: Bool, itemType: String) {
        self.result = result
        self.availabilityResult = availabilityResult
        self.isChecking = isChecking
        self.itemType = itemType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Validation feedback
            HStack(spacing: 6) {
                Image(systemName: result.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.isValid ? .green : .red)
                    .font(.caption)

                Text(result.isValid ? "Valid format" : result.errorMessage ?? "Invalid")
                    .font(.caption)
                    .foregroundColor(result.isValid ? .green : .red)
            }

            // Availability feedback
            if result.isValid && !itemType.isEmpty {
                HStack(spacing: 6) {
                    if isChecking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.6)
                        Text("Checking availability...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let available = availabilityResult {
                        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(available ? .green : .red)
                            .font(.caption)

                        Text(available ? "\(itemType) is available" : "\(itemType) is already taken")
                            .font(.caption)
                            .foregroundColor(available ? .green : .red)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: result.isValid)
        .animation(.easeInOut(duration: 0.2), value: availabilityResult)
    }
}

// MARK: - Supporting Types

private enum Field {
    case username
    case email
    case password
    case confirmPassword
}

// MARK: - Preview

#Preview {
    RegisterView(onShowLogin: {})
}
