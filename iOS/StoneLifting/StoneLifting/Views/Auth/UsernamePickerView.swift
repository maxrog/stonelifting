//
//  UsernamePickerView.swift
//  StoneAtlas
//
//  Created by Max Rogers on 7/10/25.
//

import SwiftUI

struct UsernamePickerView: View {

    @State private var viewModel = UsernamePickerViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isUsernameFocused: Bool

    let onComplete: () -> Void

    // MARK: - Body

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Choose Username")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Skip") {
                            onComplete()
                        }
                    }
                }
        }
        .onAppear {
            isUsernameFocused = true
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 24) {
            instructionsSection

            usernameField

            if let error = viewModel.validationError {
                errorMessage(error)
            }

            Spacer()

            submitButton
        }
        .padding()
    }

    @ViewBuilder
    private var instructionsSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Pick a unique username")
                .font(.title2)
                .fontWeight(.semibold)

            Text("3-20 characters, letters and numbers only")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    @ViewBuilder
    private var usernameField: some View {
        HStack(spacing: 12) {
            TextField("Username", text: $viewModel.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isUsernameFocused)
                .onChange(of: viewModel.username) { _, _ in
                    viewModel.validateUsername()
                }
                .onSubmit {
                    submitUsername()
                }

            statusIndicator
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if viewModel.isCheckingAvailability {
            ProgressView()
                .controlSize(.small)
        } else if viewModel.isValid {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .imageScale(.large)
        }
    }

    @ViewBuilder
    private func errorMessage(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var submitButton: some View {
        Button {
            submitUsername()
        } label: {
            HStack {
                if viewModel.isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Continue")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.canSubmit ? Color.blue : Color.gray)
            .foregroundStyle(.white)
            .cornerRadius(12)
        }
        .disabled(!viewModel.canSubmit)
    }

    // MARK: - Actions

    private func submitUsername() {
        guard viewModel.canSubmit else { return }

        isUsernameFocused = false

        Task {
            let success = await viewModel.submit()
            if success {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                onComplete()
            } else {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
    }
}

#Preview {
    UsernamePickerView {
        print("Completed")
    }
}
