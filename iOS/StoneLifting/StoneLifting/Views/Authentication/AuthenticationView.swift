//
//  AuthenticationView.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/11/25.
//

import SwiftUI

// MARK: - Authentication View

/// Main authentication coordinator view
/// Manages the flow between login and registration screens
struct AuthenticationView: View {
    // MARK: - Properties

    @State private var currentScreen: AuthScreen = .login

    /// Animation namespace for smooth transitions
    @Namespace private var animation

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                Group {
                    switch currentScreen {
                    case .login:
                        LoginView(onShowRegister: showRegister, onShowForgotPassword: showForgotPassword)
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    case .register:
                        RegisterView(onShowLogin: showLogin)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .forgotPassword:
                        ForgotPasswordView(onReturnToLogin: showLogin)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: currentScreen)
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.blue.opacity(0.1),
                Color.purple.opacity(0.1),
                Color.clear
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Actions

    private func showRegister() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentScreen = .register
        }
    }

    private func showLogin() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentScreen = .login
        }
    }

    private func showForgotPassword() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentScreen = .forgotPassword
        }
    }
}

// MARK: - Supporting Types

private enum AuthScreen {
    case login
    case register
    case forgotPassword
}

// MARK: - Preview

#Preview {
    AuthenticationView()
}
