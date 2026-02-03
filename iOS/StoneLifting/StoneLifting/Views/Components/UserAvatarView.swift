//
//  UserAvatarView.swift
//  StoneLifting
//
//  Created by Max Rogers on 1/7/26.
//

import SwiftUI

// MARK: - User Avatar View

/// Reusable user avatar component
/// Displays a circular avatar with the user's initial(s) and gradient background
/// Supports different sizes and customizable colors
struct UserAvatarView: View {
    // MARK: - Size Preset

    enum Size {
        case small
        case medium
        case large

        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 40
            case .large: return 60
            }
        }

        var fontSize: Font {
            switch self {
            case .small: return .caption
            case .medium: return .headline
            case .large: return .title2
            }
        }
    }

    // MARK: - Properties

    let username: String
    let size: Size
    let gradientColors: [Color]

    // MARK: - Initialization

    /// Initialize with username and default settings
    /// - Parameter username: The user's username
    init(username: String) {
        self.username = username
        self.size = .medium
        self.gradientColors = [.blue, .cyan]
    }

    /// Initialize with custom size
    /// - Parameters:
    ///   - username: The user's username
    ///   - size: Avatar size preset
    init(username: String, size: Size) {
        self.username = username
        self.size = size
        self.gradientColors = [.blue, .cyan]
    }

    /// Initialize with full customization
    /// - Parameters:
    ///   - username: The user's username
    ///   - size: Avatar size preset
    ///   - gradientColors: Custom gradient colors
    init(username: String, size: Size, gradientColors: [Color]) {
        self.username = username
        self.size = size
        self.gradientColors = gradientColors
    }

    // MARK: - Body

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size.dimension, height: size.dimension)
            .overlay(
                Text(userInitials)
                    .font(size.fontSize)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            )
    }

    // MARK: - Computed Properties

    /// Get user initials (up to 2 characters)
    private var userInitials: String {
        let words = username.split(separator: " ")

        if words.count >= 2 {
            // First and last name initials
            let firstInitial = words.first?.prefix(1) ?? ""
            let lastInitial = words.last?.prefix(1) ?? ""
            return "\(firstInitial)\(lastInitial)".uppercased()
        } else {
            // Single name - first 1-2 letters
            return String(username.prefix(2)).uppercased()
        }
    }
}

// MARK: - User Avatar with Name

struct UserAvatarWithName: View {
    let username: String
    let subtitle: String?
    let size: UserAvatarView.Size

    init(username: String, subtitle: String? = nil, size: UserAvatarView.Size = .medium) {
        self.username = username
        self.subtitle = subtitle
        self.size = size
    }

    var body: some View {
        VStack(spacing: 8) {
            UserAvatarView(username: username, size: size)

            VStack(spacing: 2) {
                Text(username)
                    .font(size == .large ? .headline : .subheadline)
                    .fontWeight(.medium)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Sizes") {
    VStack(spacing: 24) {
        HStack(spacing: 24) {
            VStack {
                UserAvatarView(username: "John Doe", size: .small)
                Text("Small")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack {
                UserAvatarView(username: "John Doe", size: .medium)
                Text("Medium")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack {
                UserAvatarView(username: "John Doe", size: .large)
                Text("Large")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }

        Divider()

        Text("Single Name")
            .font(.headline)

        HStack(spacing: 24) {
            UserAvatarView(username: "Alex", size: .medium)
            UserAvatarView(username: "Sam", size: .medium)
            UserAvatarView(username: "Jordan", size: .medium)
        }
    }
    .padding()
}

#Preview("Custom Colors") {
    HStack(spacing: 16) {
        UserAvatarView(
            username: "Alice",
            size: .large,
            gradientColors: [.purple, .pink]
        )

        UserAvatarView(
            username: "Bob",
            size: .large,
            gradientColors: [.orange, .red]
        )

        UserAvatarView(
            username: "Charlie",
            size: .large,
            gradientColors: [.green, .mint]
        )
    }
    .padding()
}

#Preview("With Name") {
    VStack(spacing: 32) {
        UserAvatarWithName(
            username: "John Doe",
            subtitle: "Stone Lifter",
            size: .large
        )

        Divider()

        HStack(spacing: 32) {
            UserAvatarWithName(username: "Alice")
            UserAvatarWithName(username: "Bob")
            UserAvatarWithName(username: "Charlie")
        }
    }
    .padding()
}
