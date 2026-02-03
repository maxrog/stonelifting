//
//  Constants.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/10/25.
//

import Foundation

// MARK: - API Configuration

/// Configuration constants for the StoneLifting app
enum APIConfig {
    /// Environment selection
    enum Environment {
        case local
        case development
        case production
    }

    /// Current environment
    /// - local: Your Mac running at localhost:8080
    /// - development: Railway dev environment for testing
    /// - production: Railway production environment for real users
    static let currentEnvironment: Environment = .development

    /// Base URL for the StoneLifting API
    /// Automatically switches based on currentEnvironment
    static let baseURL: String = {
        switch currentEnvironment {
        case .local:
            return "http://localhost:8080"
        case .development:
            return "https://stonelifting-dev.up.railway.app"
        case .production:
            return "https://stonelifting-production.up.railway.app"
        }
    }()

    /// API endpoints
    enum Endpoints {
        // OAuth authentication
        static let appleSignIn = "/auth/apple"
        static let googleSignIn = "/auth/google"

        // User endpoints
        static let me = "/me"
        static let stats = "/stats"

        // Stone endpoints
        static let stones = "/stones"
        static let publicStones = "/stones/public"
        static let nearbyStones = "/stones/nearby"
        static let moderateText = "/stones/moderate-text"

        // Health check
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
enum AppConfig {
    /// Maximum file size for image uploads (in bytes)
    static let maxImageSize = 10 * 1024 * 1024 // 10MB

    /// Supported image formats
    static let supportedImageTypes = ["jpg", "jpeg", "png", "heic"]

    /// Default search radius for nearby stones (in kilometers)
    static let defaultSearchRadius: Double = 10.0
}

// MARK: User Defaults

enum UserDefaultsKeys {
    static let hasCompletedOnboarding = "com.marfodub.StoneLifting.has_completed_onboarding"

    static let preferredWeightUnit = "com.marfodub.StoneLifting.preferred_weight_unit"
    static let preferredDistanceUnit = "com.marfodub.StoneLifting.preferred_distance_unit"

    static let enableLocationServices = "com.marfodub.StoneLifting.enable_location_services"
    static let enableNotifications = "com.marfodub.StoneLifting.enable_notifications"

    static let lastKnownLatitude = "com.marfodub.StoneLifting.last_known_latitude"
    static let lastKnownLongitude = "com.marfodub.StoneLifting.last_known_longitude"

    static let reportedStones = "com.marfodub.StoneLifting.reported_stones"
    static let deviceIdentifier = "com.marfodub.StoneLifting.device_identifier"
}
