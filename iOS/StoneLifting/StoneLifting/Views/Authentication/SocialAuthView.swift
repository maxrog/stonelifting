//
//  SocialAuthView.swift
//  StoneAtlas
//
//  Created by Max Rogers on 1/26/26.
//

import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

// MARK: - Social Auth View

/// OAuth-only authentication screen
/// Provides Apple Sign In and Google Sign In
struct SocialAuthView: View {
    // MARK: - Properties

    @State private var viewModel = SocialAuthViewModel()

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                headerSection
                socialButtonsSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(Color(.systemBackground))
        .onOpenURL { url in
            // Handle Google Sign In OAuth redirect
            GoogleSignInService.shared.handleURL(url)
        }
        .alert("Sign In Error", isPresented: .constant(viewModel.authError != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.authError?.localizedDescription ?? "")
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App icon/logo
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
        .padding(.top, 32)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var socialButtonsSection: some View {
        VStack(spacing: 12) {
            // Sign in with Apple
            SignInWithAppleButton(
                onRequest: { request in
                    viewModel.handleAppleSignInRequest(request)
                },
                onCompletion: { result in
                    Task {
                        await viewModel.handleAppleSignInCompletion(result)
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(12)

            // Sign in with Google - Using official GoogleSignInButton
            GoogleSignInButton(action: {
                Task {
                    await viewModel.handleGoogleSignIn()
                }
            })
            .frame(height: 50)
            .cornerRadius(12)
            .disabled(viewModel.isGoogleLoading)
        }
    }
}

// MARK: - Preview

#Preview {
    SocialAuthView()
}
