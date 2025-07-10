//
//  Stone.swift
//  StoneLifting
//
//  Created by Max Rogers on 7/10/25.
//

import Foundation

// MARK: - Stone Models

/// Represents a stone lifting record
/// Matches the Stone model from the Vapor backend
struct Stone: Codable, Identifiable {
    /// Unique identifier for the stone record
    let id: UUID?
    
    /// Actual weight of the stone in pounds/kilograms
    let weight: Double
    
    /// AI-estimated weight (optional, for comparison)
    let estimatedWeight: Double?
    
    /// User's description of the stone or lift
    let description: String?
    
    /// URL to the stone's image
    let imageUrl: String?
    
    /// Geographic latitude of the stone's location
    let latitude: Double?
    
    /// Geographic longitude of the stone's location
    let longitude: Double?
    
    /// Human-readable location name (e.g., "Central Park")
    let locationName: String?
    
    /// Whether this stone is visible to other users
    let isPublic: Bool
    
    /// Subjective difficulty rating (1-5 scale)
    let difficultyRating: Int?
    
    /// When this stone record was created
    let createdAt: Date?
    
    /// Information about the user who logged this stone
    let user: User
}

// MARK: - Stone Request Models

/// Request payload for creating a new stone record
struct CreateStoneRequest: Codable {
    /// Weight of the stone being logged
    let weight: Double
    
    /// AI-estimated weight for comparison
    let estimatedWeight: Double?
    
    /// Name of the stone
    let name: String?
    
    /// Description of the stone or lift experience
    let description: String?
    
    /// URL to uploaded image
    let imageUrl: String?
    
    /// Latitude coordinate
    let latitude: Double?
    
    /// Longitude coordinate
    let longitude: Double?
    
    /// Human-readable location name
    let locationName: String?
    
    /// Whether to make this stone visible to other users
    let isPublic: Bool
    
    /// Difficulty rating (1-5)
    let difficultyRating: Int?
}

// MARK: - Stone Computed Properties

extension Stone {
    /// Returns true if this stone has location data
    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }
    
    /// Returns a formatted weight string with units
    var formattedWeight: String {
        String(format: "%.1f lbs", weight)
    }
    
    /// Returns the difference between actual and estimated weight
    var estimationAccuracy: Double? {
        guard let estimated = estimatedWeight else { return nil }
        return abs(weight - estimated)
    }
}
