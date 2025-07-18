//
//  User.swift
//  StoneLifting
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
}

// MARK: - Authentication Request Models

/// Request payload for creating a new user account
struct CreateUserRequest: Codable {
    let username: String // unique
    let email: String // unique
    let password: String // hashed on backend
}

/// Request payload for user login
struct LoginRequest: Codable {
    let username: String
    let password: String
}

/// Response from successful authentication
/// Contains user data and JWT token for subsequent requests
struct AuthResponse: Codable {
    let user: User
    let token: String
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
