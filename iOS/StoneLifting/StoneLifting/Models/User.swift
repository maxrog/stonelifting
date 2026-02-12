//
//  User.swift
//  StoneAtlas
//
//  Created by Max Rogers on 7/10/25.
//

import Foundation

// MARK: - User Models

/// Represents a user in the StoneLifting app
/// Matches the User model from the Vapor backend
struct User: Codable, Identifiable {
    let id: UUID
    let username: String
    let email: String
    let createdAt: Date?
}

// MARK: - OAuth Authentication Request Models

/// Request payload for Apple Sign In
struct AppleSignInRequest: Codable {
    let identityToken: String
    let authorizationCode: String
    let fullName: PersonNameComponents?
    let email: String?
    let nonce: String
}

/// Request payload for Google Sign In
struct GoogleSignInRequest: Codable {
    let idToken: String
    let accessToken: String?
}

/// Response from successful authentication
/// Contains user data and JWT token for subsequent requests
struct AuthResponse: Codable {
    let user: User
    let token: String
    let refreshToken: String
}

/// Request payload for token refresh
struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

/// Request payload for updating username
struct UpdateUsernameRequest: Codable {
    let username: String
}

/// Generic message response
struct MessageResponse: Codable {
    let message: String
}

// MARK: - Stone Response Models

/// Response containing user's stone lifting statistics
struct UserStatsResponse: Codable {
    /// User's basic information
    let id: UUID?
    let username: String
    let email: String
    let createdAt: Date?

    /// Array of all stones logged by this user
    let stones: [Stone]
}
