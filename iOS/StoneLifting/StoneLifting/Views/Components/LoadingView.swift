//
//  LoadingView.swift
//  StoneAtlas
//
//  Created by Max Rogers on 7/30/25.
//

import SwiftUI

// MARK: - Loading View

/// A reusable loading view component
/// Supports both overlay and full-screen splash modes
/// Displays a spinner with customizable message, subtitle, and optional icon
struct LoadingView: View {
    // MARK: - Display Style

    enum Style {
        /// Overlay style - dims background, shows centered card
        case overlay
        /// Full-screen splash style - fills screen, optional animated icon
        case splash
    }

    // MARK: - Properties

    let message: String
    let subtitle: String?
    let style: Style
    let icon: String?

    @State private var isAnimating = false

    // MARK: - Initialization

    /// Initialize with a message and optional subtitle (overlay style)
    /// - Parameters:
    ///   - message: The main loading message to display
    ///   - subtitle: Optional additional context or instructions
    init(
        message: String,
        subtitle: String? = nil
    ) {
        self.message = message
        self.subtitle = subtitle
        self.style = .overlay
        self.icon = nil
    }

    /// Initialize with custom style and optional icon
    /// - Parameters:
    ///   - message: The main loading message to display
    ///   - subtitle: Optional additional context or instructions
    ///   - style: Display style (overlay or splash)
    ///   - icon: Optional SF Symbol icon name (animated in splash mode)
    init(
        message: String,
        subtitle: String? = nil,
        style: Style,
        icon: String? = nil
    ) {
        self.message = message
        self.subtitle = subtitle
        self.style = style
        self.icon = icon
    }

    // MARK: - Body

    var body: some View {
        switch style {
        case .overlay:
            overlayStyle
        case .splash:
            splashStyle
        }
    }

    // MARK: - Style Variants

    @ViewBuilder
    private var overlayStyle: some View {
        ZStack {
            Color.black
                .opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }

                ProgressView()
                    .progressViewStyle(
                        CircularProgressViewStyle(tint: .blue)
                    )
                    .scaleEffect(1.5)

                VStack(spacing: 8) {
                    Text(message)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .shadow(
                color: .black.opacity(0.2),
                radius: 20,
                x: 0,
                y: 10
            )
            .padding(.horizontal, 40)
        }
    }

    @ViewBuilder
    private var splashStyle: some View {
        VStack(spacing: 24) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            }

            VStack(spacing: 12) {
                Text(message)
                    .font(.title)
                    .fontWeight(.bold)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview("Default") {
    ZStack {
        ScrollView {
            ForEach(0..<10) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.3))
                    .frame(height: 100)
                    .padding()
            }
        }

        LoadingView(message: "Loading...")
    }
}

#Preview("With Subtitle") {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        LoadingView(
            message: "Uploading photo...",
            subtitle: "This may take a moment"
        )
    }
}

#Preview("Long Message") {
    LoadingView(
        message: "Processing your request",
        subtitle: "Please wait while we save your stone"
    )
}

#Preview("Splash Style") {
    LoadingView(
        message: "StoneLifting",
        style: .splash,
        icon: "figure.strengthtraining.traditional"
    )
}

#Preview("Splash With Subtitle") {
    LoadingView(
        message: "StoneLifting",
        subtitle: "Loading your stones...",
        style: .splash,
        icon: "figure.strengthtraining.traditional"
    )
}
