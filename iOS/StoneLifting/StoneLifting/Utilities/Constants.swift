//
//  Constants.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/10/25.
//

import Foundation

// MARK: - API Configuration

/// Configuration constants for the StoneLifting app
struct APIConfig {
    /// Base URL for the StoneLifting API
    static let baseURL = "http://localhost:8080"
    
    /// API endpoints
    enum Endpoints {
        static let register = "/auth/register"
        static let login = "/auth/login"
        static let me = "/me"
        static let stats = "/stats"
        static let stones = "/stones"
        static let publicStones = "/stones/public"
        static let nearbyStones = "/stones/nearby"
        static let health = "/health"
    }
    
    /// HTTP headers
    enum Headers {
        static let contentType = "Content-Type"
        static let authorization = "Authorization"
        static let applicationJSON = "application/json"
    }
}

// MARK: - App Configuration

/// General app configuration constants
struct AppConfig {
    /// Maximum file size for image uploads (in bytes)
    static let maxImageSize = 10 * 1024 * 1024 // 10MB
    
    /// Supported image formats
    static let supportedImageTypes = ["jpg", "jpeg", "png", "heic"]
    
    /// Default search radius for nearby stones (in kilometers)
    static let defaultSearchRadius: Double = 10.0
    
    /// Maximum difficulty rating
    static let maxDifficultyRating = 5
}
