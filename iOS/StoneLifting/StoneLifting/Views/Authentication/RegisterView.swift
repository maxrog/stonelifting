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
        .alert("Registration Error", isPresented: .constant(viewModel.authError != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.authError?.localizedDescription ?? "")
        }
        .onAppear {
            // Auto-focus on username field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .username
            }
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
                            .accessibilityLabel("Username")
                            .accessibilityHint("Enter a unique username for your account")

                        if isCheckingUsername {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.8)
                        } else if !username.isEmpty && viewModel.validateUsername(username).isValid && usernameAvailable == true {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.body)
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
                            .accessibilityLabel("Email")
                            .accessibilityHint("Enter your email address")

                        if isCheckingEmail {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.8)
                        } else if !email.isEmpty && viewModel.validateEmail(email).isValid && emailAvailable == true {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.body)
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
                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                if !password.isEmpty {
                    PasswordStrengthView(password: password)
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
                    .accessibilityLabel(showConfirmPassword ? "Hide password confirmation" : "Show password confirmation")
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
            .accessibilityLabel("Create Account")
            .accessibilityHint(isFormValid ? "Double tap to create your account" : "Complete all fields with valid information to enable")

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
            let success = await viewModel.register(username: username, email: email, password: password)

            if success {
                // Haptic feedback on success
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
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
            // only show errors
            if !result.isValid {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)

                    Text(result.errorMessage ?? "Invalid")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            // only show errors or checking status
            if result.isValid && !itemType.isEmpty {
                HStack(spacing: 6) {
                    if isChecking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.6)
                        Text("Checking availability...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let available = availabilityResult, !available {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)

                        Text("\(itemType) is already taken")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: result.isValid)
        .animation(.easeInOut(duration: 0.2), value: availabilityResult)
    }
}

// MARK: - Password Strength View

/// Displays password strength with visual bar and requirements checklist
struct PasswordStrengthView: View {
    let password: String

    private var strength: PasswordStrength {
        calculateStrength(password)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Strength bar
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    Rectangle()
                        .fill(index < strength.bars ? strength.color : Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                }
            }

            // Strength label
            HStack(spacing: 6) {
                Text(strength.label)
                    .font(.caption)
                    .foregroundColor(strength.color)
                    .fontWeight(.medium)
            }

            // Requirements checklist
            VStack(alignment: .leading, spacing: 4) {
                RequirementRow(met: password.count >= 8, text: "At least 8 characters")
                RequirementRow(met: password.rangeOfCharacter(from: .letters) != nil, text: "Contains a letter")
                RequirementRow(met: password.rangeOfCharacter(from: .decimalDigits) != nil, text: "Contains a number")
            }
            .padding(.top, 4)
        }
        .animation(.easeInOut(duration: 0.2), value: strength)
    }

    private func calculateStrength(_ password: String) -> PasswordStrength {
        var score = 0

        // Length check
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }

        // Character variety
        if password.rangeOfCharacter(from: .letters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil {
            score += 1
        }

        // Map score to strength
        switch score {
        case 0...2: return .weak
        case 3...4: return .fair
        case 5: return .good
        default: return .strong
        }
    }
}

/// Individual requirement row
private struct RequirementRow: View {
    let met: Bool
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(met ? .green : .gray)

            Text(text)
                .font(.caption)
                .foregroundColor(met ? .primary : .secondary)
        }
    }
}

/// Password strength levels
private enum PasswordStrength {
    case weak, fair, good, strong

    var label: String {
        switch self {
        case .weak: return "Weak"
        case .fair: return "Fair"
        case .good: return "Good"
        case .strong: return "Strong"
        }
    }

    var color: Color {
        switch self {
        case .weak: return .red
        case .fair: return .orange
        case .good: return .blue
        case .strong: return .green
        }
    }

    var bars: Int {
        switch self {
        case .weak: return 1
        case .fair: return 2
        case .good: return 3
        case .strong: return 4
        }
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
