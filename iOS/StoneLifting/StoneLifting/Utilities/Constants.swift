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
        static let forgotPassword = "/auth/forgot-password"
        static let resetPassword = "/auth/reset-password"
        static let checkUsername = "/auth/check-username"
        static let checkEmail = "/auth/check-email"
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

}

// MARK: User Defaults

struct UserDefaultsKeys {
    static let jwtToken = "com.marfodub.StoneLifting.jwtToken"

    static let hasCompletedOnboarding = "com.marfodub.StoneLifting.has_completed_onboarding"

    static let preferredWeightUnit = "com.marfodub.StoneLifting.preferred_weight_unit"
    static let preferredDistanceUnit = "com.marfodub.StoneLifting.preferred_distance_unit"

    static let enableLocationServices = "com.marfodub.StoneLifting.enable_location_services"
    static let enableNotifications = "com.marfodub.StoneLifting.enable_notifications"

    static let lastKnownLatitude = "com.marfodub.StoneLifting.last_known_latitude"
    static let lastKnownLongitude = "com.marfodub.StoneLifting.last_known_longitude"
}
