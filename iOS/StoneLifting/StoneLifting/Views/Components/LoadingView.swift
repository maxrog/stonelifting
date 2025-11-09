//
//  LoadingView.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/30/25.
//

import SwiftUI

// MARK: - Loading View

/// A reusable loading view component
/// Displays a spinner with customizable message and optional subtitle
struct LoadingView: View {
    // MARK: - Properties

    let message: String
    let subtitle: String?

    // MARK: - Initialization

    /// Initialize with a message and optional subtitle
    /// - Parameters:
    ///   - message: The main loading message to display
    ///   - subtitle: Optional additional context or instructions
    init(
        message: String,
        subtitle: String? = nil
    ) {
        self.message = message
        self.subtitle = subtitle
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black
                .opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 20) {
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
