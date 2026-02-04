//
//  AuthenticationView.swift
//  StoneAtlas
//
//  Created by Max Rogers on 7/11/25.
//

import SwiftUI

// MARK: - Authentication View

/// Main authentication view (OAuth-only)
/// Displays social sign-in options (Apple + Google)
struct AuthenticationView: View {
    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                SocialAuthView()
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
}

// MARK: - Preview

#Preview {
    AuthenticationView()
}
